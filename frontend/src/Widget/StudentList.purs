module Widget.StudentList
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.String.Common as String
import Domain.Volunteer (Seat, SeatPeriod(..), Volunteer, ageToGradeLabel, formatUpdatedAt, seatForPeriod, showSeat)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { volunteers :: Array Volunteer
  , isLoading :: Boolean
  , loadError :: Maybe String
  }

type State =
  { volunteers :: Array Volunteer
  , isLoading :: Boolean
  , loadError :: Maybe String
  , selectedSeatPeriod :: SeatPeriod
  , sortMode :: SortMode
  , editingVolunteerId :: Maybe Int
  , editingField :: Maybe EditField
  , draftName :: String
  , draftAge :: Int
  , draftSeat :: Maybe Seat
  , isSeatPickerOpen :: Boolean
  , pendingDelete :: Maybe Volunteer
  }

data SortMode
  = SortBySeat
  | SortByAge
  | SortByUpdatedAt

derive instance eqSortMode :: Eq SortMode

data EditField
  = EditingName
  | EditingAge
  | EditingSeat

data Action
  = Receive Input
  | Retry
  | AskDelete Volunteer
  | CancelDelete
  | ConfirmDelete
  | SelectSeatPeriod SeatPeriod
  | SelectSortMode SortMode
  | ToggleVolunteerEdit Int
  | BeginNameEdit Volunteer
  | BeginAgeEdit Volunteer
  | BeginSeatEdit Volunteer
  | SetDraftName String
  | SetDraftAge String
  | SelectDraftSeat Seat
  | ClearDraftSeat
  | OpenSeatPicker
  | CloseSeatPicker
  | CancelFieldEdit
  | SubmitName Int
  | SubmitAge Int
  | SubmitSeat Int

data Output
  = RetryRequested
  | DeleteRequested Int
  | UpdateNameRequested Int String
  | UpdateAgeRequested Int Int
  | UpdateSeatRequested Int SeatPeriod (Maybe Seat)

component :: forall query m. H.Component query Input Output m
component =
  H.mkComponent
    { initialState: \input ->
        { volunteers: input.volunteers
        , isLoading: input.isLoading
        , loadError: input.loadError
        , selectedSeatPeriod: Year114SecondSemester
        , sortMode: SortBySeat
        , editingVolunteerId: Nothing
        , editingField: Nothing
        , draftName: ""
        , draftAge: 7
        , draftSeat: Nothing
        , isSeatPickerOpen: false
        , pendingDelete: Nothing
        }
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { handleAction = handleAction
            , receive = Just <<< Receive
            }
    }

render :: forall m. State -> H.ComponentHTML Action Slots m
render state =
  HH.section
    [ HP.class_ (HH.ClassName "student-list-card") ]
    [ if state.isSeatPickerOpen then
        HH.div
          [ HP.class_ (HH.ClassName "table-seat-picker-backdrop")
          , HE.onClick \_ -> CloseSeatPicker
          ]
          []
      else
        HH.text ""
    , case state.pendingDelete of
        Nothing -> HH.text ""
        Just volunteer -> renderDeleteDialog volunteer
    , HH.div
        [ HP.class_ (HH.ClassName "list-heading") ]
        [ HH.div_
            [ HH.h2_ [ HH.text "學生清單" ]
            , HH.p_ [ HH.text "資料來源：GET /api/volunteers" ]
            ]
        , HH.span
            [ HP.class_ (HH.ClassName "student-count") ]
            [ HH.text (show (Array.length state.volunteers) <> " 位學生") ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "student-list-controls") ]
        [ HH.div
            [ HP.class_ (HH.ClassName "list-control-group") ]
            [ HH.span [ HP.class_ (HH.ClassName "list-control-title") ] [ HH.text "座位顯示" ]
            , HH.div
                [ HP.class_ (HH.ClassName "list-radio-options") ]
                [ seatPeriodRadio "114下" Year114SecondSemester state.selectedSeatPeriod
                , seatPeriodRadio "115暑假" Year115Summer state.selectedSeatPeriod
                ]
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "list-control-group") ]
            [ HH.span [ HP.class_ (HH.ClassName "list-control-title") ] [ HH.text "排序方式" ]
            , HH.div
                [ HP.class_ (HH.ClassName "list-radio-options") ]
                [ sortModeRadio "座位" SortBySeat state.sortMode
                , sortModeRadio "年齡" SortByAge state.sortMode
                , sortModeRadio "最後修改時間" SortByUpdatedAt state.sortMode
                ]
            ]
        ]
    , renderVolunteerList state
    ]

seatPeriodRadio
  :: forall m
   . String
  -> SeatPeriod
  -> SeatPeriod
  -> H.ComponentHTML Action Slots m
seatPeriodRadio label period selectedPeriod =
  HH.label_
    [ HH.input
        [ HP.type_ HP.InputRadio
        , HP.name "student-seat-period"
        , HP.checked (period == selectedPeriod)
        , HE.onChange \_ -> SelectSeatPeriod period
        ]
    , HH.text label
    ]

sortModeRadio
  :: forall m
   . String
  -> SortMode
  -> SortMode
  -> H.ComponentHTML Action Slots m
sortModeRadio label sortMode selectedSortMode =
  HH.label_
    [ HH.input
        [ HP.type_ HP.InputRadio
        , HP.name "student-list-sort-mode"
        , HP.checked (sortMode == selectedSortMode)
        , HE.onChange \_ -> SelectSortMode sortMode
        ]
    , HH.text label
    ]

renderVolunteerList :: forall m. State -> H.ComponentHTML Action Slots m
renderVolunteerList state
  | state.isLoading =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在載入學生資料…" ]
  | Just message <- state.loadError =
      HH.div
        [ HP.class_ (HH.ClassName "list-status list-error") ]
        [ HH.p_ [ HH.text message ]
        , HH.button
            [ HP.class_ (HH.ClassName "list-retry-button")
            , HE.onClick \_ -> Retry
            ]
            [ HH.text "重新請求" ]
        ]
  | Array.null state.volunteers =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有學生資料。" ]
  | otherwise =
      HH.div
        [ HP.classes
            ( [ HH.ClassName "student-table-scroll" ]
                <> if state.isSeatPickerOpen then
                    [ HH.ClassName "seat-picker-active" ]
                  else
                    []
            )
        ]
        [ HH.table
            [ HP.class_ (HH.ClassName "student-table") ]
            [ HH.thead_
                [ HH.tr_
                    [ HH.th_ [ HH.text "編號" ]
                    , HH.th_ [ HH.text "姓名" ]
                    , HH.th_ [ HH.text "年級" ]
                    , HH.th_ [ HH.text "座位" ]
                    , HH.th_ [ HH.text "操作" ]
                    , HH.th_ [ HH.text "修改時間" ]
                    ]
                ]
            , HH.tbody_
                (map (renderVolunteer state) (sortedVolunteers state))
            ]
        ]

sortedVolunteers :: State -> Array Volunteer
sortedVolunteers state =
  Array.sortBy (compareVolunteers state.sortMode state.selectedSeatPeriod) state.volunteers

compareVolunteers :: SortMode -> SeatPeriod -> Volunteer -> Volunteer -> Ordering
compareVolunteers sortMode period left right =
  case sortMode of
    SortBySeat ->
      withNameFallback
        (compareMaybeSeat (seatForPeriod period left) (seatForPeriod period right))
        left
        right
    SortByAge ->
      withNameFallback (compare left.age right.age) left right
    SortByUpdatedAt ->
      withNameFallback (compare right.updatedAt left.updatedAt) left right

withNameFallback :: Ordering -> Volunteer -> Volunteer -> Ordering
withNameFallback ordering left right = case ordering of
  EQ -> compare left.name right.name
  _ -> ordering

compareMaybeSeat :: Maybe { row :: Int, col :: Int } -> Maybe { row :: Int, col :: Int } -> Ordering
compareMaybeSeat left right = case left, right of
  Nothing, Nothing -> EQ
  Nothing, Just _ -> GT
  Just _, Nothing -> LT
  Just leftSeat, Just rightSeat -> case compare leftSeat.row rightSeat.row of
    EQ -> compare leftSeat.col rightSeat.col
    ordering -> ordering

renderVolunteer :: forall m. State -> Volunteer -> H.ComponentHTML Action Slots m
renderVolunteer state volunteer =
  let
    isEditing = state.editingVolunteerId == Just volunteer.id
    updatedAt = formatUpdatedAt volunteer.updatedAt
  in
  HH.tr_
    [ HH.td_ [ HH.text (show volunteer.id) ]
    , renderNameCell state isEditing volunteer
    , renderAgeCell state isEditing volunteer
    , renderSeatCell state isEditing volunteer
    , HH.td_
        [ HH.div
            [ HP.class_ (HH.ClassName "student-row-actions") ]
            [ HH.button
                [ HP.class_ (HH.ClassName "student-edit-button")
                , HE.onClick \_ -> ToggleVolunteerEdit volunteer.id
                ]
                [ HH.text if isEditing then "完成" else "修改" ]
            , HH.button
                [ HP.class_ (HH.ClassName "student-delete-button")
                , HE.onClick \_ -> AskDelete volunteer
                ]
                [ HH.text "刪除" ]
            ]
        ]
    , HH.td_
        [ HH.div
            [ HP.class_ (HH.ClassName "student-updated-at") ]
            [ HH.span_ [ HH.text updatedAt.date ]
            , HH.span_ [ HH.text updatedAt.time ]
            ]
        ]
    ]

renderNameCell :: forall m. State -> Boolean -> Volunteer -> H.ComponentHTML Action Slots m
renderNameCell state isEditing volunteer =
  HH.td_
    if isEditing && isEditingField EditingName state.editingField then
      [ HH.div
          [ HP.class_ (HH.ClassName "student-inline-editor") ]
          [ HH.input
              [ HP.class_ (HH.ClassName "student-inline-input")
              , HP.type_ HP.InputText
              , HP.value state.draftName
              , HE.onValueInput SetDraftName
              ]
          , renderEditActions "姓名" (SubmitName volunteer.id)
          ]
      ]
    else
      [ HH.div
          [ HP.class_ (HH.ClassName "student-editable-value") ]
          [ HH.strong_ [ HH.text volunteer.name ]
          , if isEditing then editIconButton "姓名" (BeginNameEdit volunteer)
            else HH.text ""
          ]
      ]

renderAgeCell :: forall m. State -> Boolean -> Volunteer -> H.ComponentHTML Action Slots m
renderAgeCell state isEditing volunteer =
  HH.td_
    if isEditing && isEditingField EditingAge state.editingField then
      [ HH.div
          [ HP.class_ (HH.ClassName "student-inline-editor") ]
          [ HH.select
              [ HP.class_ (HH.ClassName "student-inline-input")
              , HP.value (show state.draftAge)
              , HE.onValueChange SetDraftAge
              ]
              ( map
                  (\age ->
                    HH.option
                      [ HP.value (show age) ]
                      [ HH.text (ageToGradeLabel age) ]
                  )
                  (Array.range 5 15)
              )
          , renderEditActions "年級" (SubmitAge volunteer.id)
          ]
      ]
    else
      [ HH.div
          [ HP.class_ (HH.ClassName "student-editable-value") ]
          [ HH.text (ageToGradeLabel volunteer.age)
          , if isEditing then editIconButton "年級" (BeginAgeEdit volunteer)
            else HH.text ""
          ]
      ]

renderSeatCell :: forall m. State -> Boolean -> Volunteer -> H.ComponentHTML Action Slots m
renderSeatCell state isEditing volunteer =
  HH.td_
    if isEditing && isEditingField EditingSeat state.editingField then
      [ HH.div
          [ HP.class_ (HH.ClassName "student-seat-editor") ]
          [ HH.div
              [ HP.class_ (HH.ClassName "student-inline-editor") ]
              [ HH.button
                  [ HP.class_ (HH.ClassName "student-seat-picker-trigger")
                  , HE.onClick \_ -> OpenSeatPicker
                  ]
                  [ HH.text (showSeat state.draftSeat) ]
              , renderEditActions "座位" (SubmitSeat volunteer.id)
              ]
          , if state.isSeatPickerOpen then renderSeatPicker state.draftSeat
            else HH.text ""
          ]
      ]
    else
      [ HH.div
          [ HP.class_ (HH.ClassName "student-editable-value") ]
          [ HH.text (showSeat (seatForPeriod state.selectedSeatPeriod volunteer))
          , if isEditing then editIconButton "座位" (BeginSeatEdit volunteer)
            else HH.text ""
          ]
      ]

isEditingField :: EditField -> Maybe EditField -> Boolean
isEditingField expected = case _ of
  Just EditingName -> case expected of
    EditingName -> true
    _ -> false
  Just EditingAge -> case expected of
    EditingAge -> true
    _ -> false
  Just EditingSeat -> case expected of
    EditingSeat -> true
    _ -> false
  Nothing -> false

editIconButton :: forall m. String -> Action -> H.ComponentHTML Action Slots m
editIconButton field action =
  iconButton ("編輯" <> field) "✎" "student-field-edit-button" action

renderEditActions :: forall m. String -> Action -> H.ComponentHTML Action Slots m
renderEditActions field submitAction =
  HH.span
    [ HP.class_ (HH.ClassName "student-edit-actions") ]
    [ iconButton ("取消修改" <> field) "↻" "student-edit-cancel-button" CancelFieldEdit
    , iconButton ("送出修改" <> field) "✓" "student-edit-submit-button" submitAction
    ]

iconButton :: forall m. String -> String -> String -> Action -> H.ComponentHTML Action Slots m
iconButton label icon className action =
  HH.button
    [ HP.class_ (HH.ClassName className)
    , HP.attr (HH.AttrName "aria-label") label
    , HP.attr (HH.AttrName "title") label
    , HE.onClick \_ -> action
    ]
    [ HH.text icon ]

renderSeatPicker :: forall m. Maybe Seat -> H.ComponentHTML Action Slots m
renderSeatPicker selectedSeat =
  HH.div
    [ HP.class_ (HH.ClassName "table-seat-picker") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "seat-stage") ]
        [ HH.span [ HP.class_ (HH.ClassName "seat-stage-spacer") ] []
        , HH.span
            [ HP.class_ (HH.ClassName "seat-stage-button") ]
            [ HH.text "講台" ]
        , HH.button
            [ HP.class_ (HH.ClassName "seat-clear-button")
            , HE.onClick \_ -> ClearDraftSeat
            ]
            [ HH.text "清除" ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "seat-grid") ]
        ( map
            (\seat ->
              HH.button
                [ HP.classes
                    ( [ HH.ClassName "seat-button" ]
                        <> if selectedSeat == Just seat then
                            [ HH.ClassName "seat-button-selected" ]
                          else
                            []
                    )
                , HE.onClick \_ -> SelectDraftSeat seat
                ]
                [ HH.text (show seat.row <> "-" <> show seat.col) ]
            )
            seats
        )
    ]

seats :: Array Seat
seats = do
  row <- Array.range 1 5
  col <- Array.range 1 4
  pure { row, col }

renderDeleteDialog :: forall m. Volunteer -> H.ComponentHTML Action Slots m
renderDeleteDialog volunteer =
  HH.div_
    [ HH.div
        [ HP.class_ (HH.ClassName "delete-confirm-backdrop") ]
        []
    , HH.div
        [ HP.class_ (HH.ClassName "delete-confirm-dialog")
        , HP.attr (HH.AttrName "role") "dialog"
        , HP.attr (HH.AttrName "aria-modal") "true"
        , HP.attr (HH.AttrName "aria-labelledby") "delete-confirm-title"
        ]
        [ HH.h3
            [ HP.id "delete-confirm-title" ]
            [ HH.text "確認刪除學生" ]
        , HH.p_
            [ HH.text
                ( "確定要刪除「"
                    <> volunteer.name
                    <> "」（編號 "
                    <> show volunteer.id
                    <> "）嗎？"
                )
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "delete-confirm-actions") ]
            [ HH.button
                [ HP.class_ (HH.ClassName "delete-confirm-cancel")
                , HE.onClick \_ -> CancelDelete
                ]
                [ HH.text "取消" ]
            , HH.button
                [ HP.class_ (HH.ClassName "delete-confirm-submit")
                , HE.onClick \_ -> ConfirmDelete
                ]
                [ HH.text "確認刪除" ]
            ]
        ]
    ]

handleAction
  :: forall m
   . Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Receive input ->
    H.modify_
      _
        { volunteers = input.volunteers
        , isLoading = input.isLoading
        , loadError = input.loadError
        }
  Retry -> H.raise RetryRequested
  AskDelete volunteer ->
    H.modify_
      _
        { pendingDelete = Just volunteer
        , isSeatPickerOpen = false
        }
  CancelDelete -> H.modify_ _ { pendingDelete = Nothing }
  ConfirmDelete -> do
    state <- H.get
    case state.pendingDelete of
      Nothing -> pure unit
      Just volunteer -> do
        H.modify_ _ { pendingDelete = Nothing }
        H.raise (DeleteRequested volunteer.id)
  SelectSeatPeriod period ->
    H.modify_
      _
        { selectedSeatPeriod = period
        , editingField = Nothing
        , isSeatPickerOpen = false
        }
  SelectSortMode sortMode -> H.modify_ _ { sortMode = sortMode }
  ToggleVolunteerEdit id ->
    H.modify_ \state ->
      if state.editingVolunteerId == Just id then
        state { editingVolunteerId = Nothing, editingField = Nothing, isSeatPickerOpen = false }
      else
        state { editingVolunteerId = Just id, editingField = Nothing, isSeatPickerOpen = false }
  BeginNameEdit volunteer ->
    H.modify_
      _
        { editingVolunteerId = Just volunteer.id
        , editingField = Just EditingName
        , draftName = volunteer.name
        , isSeatPickerOpen = false
        }
  BeginAgeEdit volunteer ->
    H.modify_
      _
        { editingVolunteerId = Just volunteer.id
        , editingField = Just EditingAge
        , draftAge = volunteer.age
        , isSeatPickerOpen = false
        }
  BeginSeatEdit volunteer -> do
    state <- H.get
    H.modify_
      _
        { editingVolunteerId = Just volunteer.id
        , editingField = Just EditingSeat
        , draftSeat = seatForPeriod state.selectedSeatPeriod volunteer
        , isSeatPickerOpen = true
        }
  SetDraftName name -> H.modify_ _ { draftName = name }
  SetDraftAge value -> case Int.fromString value of
    Nothing -> pure unit
    Just age -> H.modify_ _ { draftAge = age }
  SelectDraftSeat seat -> H.modify_ _ { draftSeat = Just seat, isSeatPickerOpen = false }
  ClearDraftSeat -> H.modify_ _ { draftSeat = Nothing, isSeatPickerOpen = false }
  OpenSeatPicker -> H.modify_ _ { isSeatPickerOpen = true }
  CloseSeatPicker -> H.modify_ _ { isSeatPickerOpen = false }
  CancelFieldEdit -> H.modify_ _ { editingField = Nothing, isSeatPickerOpen = false }
  SubmitName id -> do
    state <- H.get
    let name = String.trim state.draftName
    H.raise (UpdateNameRequested id name)
    H.modify_ _ { editingField = Nothing, isSeatPickerOpen = false }
  SubmitAge id -> do
    state <- H.get
    H.raise (UpdateAgeRequested id state.draftAge)
    H.modify_ _ { editingField = Nothing, isSeatPickerOpen = false }
  SubmitSeat id -> do
    state <- H.get
    H.raise (UpdateSeatRequested id state.selectedSeatPeriod state.draftSeat)
    H.modify_ _ { editingField = Nothing, isSeatPickerOpen = false }
