module Widget.HourRecordList
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude
import Config.Api (apiUrl)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.String.Common as String
import Domain.Activity (Activity, activityTypeLabel)
import Domain.HourRecord (CopiedHourRecord, HourRecord)
import Domain.Volunteer (Volunteer, seatForPeriod, formatUpdatedAt)
import Domain.Seat (Seat, SeatPeriodType(..), seatPeriods, toApiValue, fromApiValue_)
import Domain.StageAction (StageAction)
import Effect (Effect)
import Effect.Class (class MonadEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import Web.Event.Event as Event
import Web.UIEvent.MouseEvent (MouseEvent)
import Web.UIEvent.MouseEvent as MouseEvent
import Widget.SeatTable.Selection (volunteerWithGrade)
import Widget.OutsideClick as OutsideClick
import Widget.HourRecord.ParticipantField (renderParticipantField)

type Slot id
  = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots
  = ()

type Input
  = { activities :: Array Activity
    , records :: Array HourRecord
    , volunteers :: Array Volunteer
    , draftFilterVolunteerIds :: Array Int
    , draftFilterActivityIds :: Array Int
    , totalRecords :: Int
    , isLoading :: Boolean
    , isLoadingMore :: Boolean
    , hasMore :: Boolean
    , loadError :: Maybe String
    }

type State
  = { activities :: Array Activity
    , records :: Array HourRecord
    , volunteers :: Array Volunteer
    , filterVolunteerIds :: Array Int
    , filterActivityIds :: Array Int
    , draftFilterVolunteerIds :: Array Int
    , draftFilterActivityIds :: Array Int
    , filterSeatPeriod :: SeatPeriodType
    , isVolunteerFilterOpen :: Boolean
    , isOtherStudentsOpen :: Boolean
    , isActivityFilterOpen :: Boolean
    , totalRecords :: Int
    , isLoading :: Boolean
    , isLoadingMore :: Boolean
    , hasMore :: Boolean
    , loadError :: Maybe String
    , selectedIds :: Array Int
    , selectionAnchor :: Maybe Int
    , isDeleteDialogOpen :: Boolean
    }

data Action
  = Initialize
  | Receive Input
  | ClickedOutsideSeatPicker
  | ClickedOutsideOtherStudents
  | ViewportChanged
  | SelectRecord Int MouseEvent
  | ToggleRecord Int Int MouseEvent
  | CopyRecord HourRecord MouseEvent
  | AskDeleteRecord Int MouseEvent
  | AskDelete
  | CancelDelete
  | ConfirmDelete
  | ToggleVolunteerFilter
  | ToggleFilterOtherStudents
  | ToggleFilterDraftStudents Int
  | ToggleActivityFilter
  | ToggleFilterDraftActivity Int
  | SelectFilterSeatPeriod String
  | ApplyVolunteerFilter
  | ClearVolunteerFilter
  | ApplyActivityFilter
  | ClearActivityFilter
  | Retry

data Output
  = DeleteRequested (Array Int)
  | CopyRequested CopiedHourRecord
  | LoadMoreRequested
  | RetryRequested
  | VolunteerFilterChanged (Array Int)
  | ActivityFilterChanged (Array Int)

foreign import subscribeWindowScroll ::
  (Unit -> Effect Unit) ->
  Effect (Effect Unit)

foreign import isLoadMoreSentinelVisible :: Effect Boolean

component :: forall query m. MonadEffect m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState:
        \input ->
          { activities: input.activities
          , records: input.records
          , volunteers: input.volunteers
          , filterVolunteerIds: []
          , filterActivityIds: []
          , draftFilterVolunteerIds: input.draftFilterVolunteerIds
          , draftFilterActivityIds: input.draftFilterActivityIds
          , filterSeatPeriod: Year114SecondSemester
          , isVolunteerFilterOpen: false
          , isActivityFilterOpen: false
          , isOtherStudentsOpen: false
          , totalRecords: input.totalRecords
          , isLoading: input.isLoading
          , isLoadingMore: input.isLoadingMore
          , hasMore: input.hasMore
          , loadError: input.loadError
          , selectedIds: []
          , selectionAnchor: Nothing
          , isDeleteDialogOpen: false
          }
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { initialize = Just Initialize
            , handleAction = handleAction
            , receive = Just <<< Receive
            }
    }

render :: forall m. State -> H.ComponentHTML Action Slots m
render state =
  HH.section
    [ HP.class_ (HH.ClassName "student-list-card hour-record-list-card") ]
    [ if state.isDeleteDialogOpen then
        renderDeleteDialog (Array.length state.selectedIds)
      else
        HH.text ""
    , HH.div
        [ HP.class_ (HH.ClassName "list-heading") ]
        [ HH.div_
            [ HH.h2_ [ HH.text "登錄歷史" ]
            , HH.p_ [ HH.text "點左側方框可多選；Ctrl 跳選；Shift 連續選取" ]
            , HH.div
                [ HP.class_ (HH.ClassName "filter-button") ]
                [ renderVolunteerFilter state
                , renderActivityFilter state
                ]
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "hour-record-list-actions") ]
            [ HH.span
                [ HP.class_ (HH.ClassName "student-count") ]
                [ HH.text
                    ( if Array.null state.selectedIds then
                        show (Array.length state.records)
                          <> " / "
                          <> show state.totalRecords
                          <> " 筆紀錄"
                      else
                        "已選 " <> show (Array.length state.selectedIds) <> " 筆"
                    )
                ]
            , HH.button
                [ HP.class_ (HH.ClassName "student-delete-button hour-record-batch-delete")
                , HP.disabled (Array.null state.selectedIds)
                , HE.onClick \_ -> AskDelete
                ]
                [ HH.text "刪除選取" ]
            , HH.a
                [ HP.class_ (HH.ClassName "hour-record-download-button")
                , HP.href (apiUrl "/api/hour-records/export")
                , HP.attr (HH.AttrName "download") ""
                ]
                [ HH.text "下載資料備份" ]
            ]
        ]
    , renderRecordList state
    , HH.div
        [ HP.class_ (HH.ClassName "hour-record-load-more")
        , HP.attr (HH.AttrName "data-hour-record-load-more") ""
        ]
        [ HH.text
            if state.isLoadingMore then
              "正在載入更多紀錄…"
            else if state.hasMore then
              "繼續往下捲動以載入更多"
            else if Array.null state.records then
              ""
            else
              "已載入全部紀錄"
        ]
    ]

renderRecordList :: forall m. State -> H.ComponentHTML Action Slots m
renderRecordList state
  | state.isLoading = HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在載入時數紀錄…" ]
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
  | Array.null state.records = HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有時數登錄紀錄。" ]
  | otherwise =
    HH.div
      [ HP.class_ (HH.ClassName "student-table-scroll") ]
      [ HH.table
          [ HP.classes [ HH.ClassName "student-table", HH.ClassName "hour-record-table" ] ]
          [ HH.thead_
              [ HH.tr_
                  [ HH.th_ [ HH.text "" ]
                  , HH.th_ [ HH.text "日期" ]
                  , HH.th_ [ HH.text "活動名" ]
                  , HH.th_ [ HH.text "類型" ]
                  , HH.th_ [ HH.text "學生" ]
                  , HH.th_ [ HH.text "時數" ]
                  , HH.th_ [ HH.text "備註" ]
                  , HH.th_ [ HH.text "登錄時間" ]
                  , HH.th_ [ HH.text "操作" ]
                  ]
              ]
          , HH.tbody_
              (Array.mapWithIndex (renderRecord state.selectedIds) state.records)
          ]
      ]

renderRecord :: forall m. Array Int -> Int -> HourRecord -> H.ComponentHTML Action Slots m
renderRecord selectedIds index record =
  let
    isSelected = Array.elem record.id selectedIds

    createdAt = formatUpdatedAt record.createdAt
  in
    HH.tr
      [ HP.classes
          if isSelected then [ HH.ClassName "hour-record-row-selected" ] else []
      , HE.onClick (SelectRecord index)
      ]
      [ HH.td_
          [ HH.button
              [ HP.class_ (HH.ClassName "hour-record-selection-mark")
              , HP.attr (HH.AttrName "role") "checkbox"
              , HP.attr (HH.AttrName "aria-checked") (if isSelected then "true" else "false")
              , HP.attr (HH.AttrName "aria-label") (if isSelected then "取消選取這筆紀錄" else "選取這筆紀錄")
              , HE.onClick (ToggleRecord record.id index)
              ]
              [ HH.text if isSelected then "✓" else "" ]
          ]
      , HH.td_ [ HH.text record.activityDate ]
      , HH.td_ [ HH.strong_ [ HH.text record.activityName ] ]
      , HH.td_
          [ HH.span
              [ HP.class_ (HH.ClassName "hour-record-type-tag")
              , HP.style ("background-color: " <> record.tagColor)
              ]
              [ HH.text (activityTypeLabel record.activityType) ]
          ]
      , HH.td_ [ HH.text record.volunteerName ]
      , HH.td_ [ HH.text (show record.hours) ]
      , HH.td
          [ HP.class_ (HH.ClassName "hour-record-note-cell") ]
          [ HH.text if String.trim record.note == "" then "-" else record.note ]
      , HH.td_
          [ HH.div
              [ HP.class_ (HH.ClassName "student-updated-at") ]
              [ HH.span_ [ HH.text createdAt.date ]
              , HH.span_ [ HH.text createdAt.time ]
              ]
          ]
      , HH.td_
          [ HH.div
              [ HP.class_ (HH.ClassName "student-row-actions") ]
              [ HH.button
                  [ HP.class_ (HH.ClassName "hour-record-copy-button")
                  , HP.attr (HH.AttrName "title") "複製到上方輸入區（不含學生）"
                  , HP.attr (HH.AttrName "aria-label") "複製這筆時數資料"
                  , HE.onClick (CopyRecord record)
                  ]
                  [ HH.text "⧉" ]
              , HH.button
                  [ HP.class_ (HH.ClassName "student-delete-button")
                  , HP.attr (HH.AttrName "title") "刪除這筆時數紀錄"
                  , HE.onClick (AskDeleteRecord record.id)
                  ]
                  [ HH.text "刪除" ]
              ]
          ]
      ]

renderDeleteDialog :: forall m. Int -> H.ComponentHTML Action Slots m
renderDeleteDialog selectedCount =
  HH.div_
    [ HH.div [ HP.class_ (HH.ClassName "delete-confirm-backdrop") ] []
    , HH.div
        [ HP.class_ (HH.ClassName "delete-confirm-dialog")
        , HP.attr (HH.AttrName "role") "dialog"
        , HP.attr (HH.AttrName "aria-modal") "true"
        ]
        [ HH.h3_ [ HH.text "確定刪除時數紀錄？" ]
        , HH.p_ [ HH.text ("即將刪除選取的 " <> show selectedCount <> " 筆紀錄，刪除後無法復原。") ]
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
                [ HH.text "確定刪除" ]
            ]
        ]
    ]

handleAction :: forall m. MonadEffect m => Action -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> do
    void $ H.subscribe (ClickedOutsideSeatPicker <$ OutsideClick.outsideClickEmitter ".seat-picker")
    void $ H.subscribe (ClickedOutsideOtherStudents <$ OutsideClick.outsideClickEmitter ".participant-unseated-dropdown")
    void
      $ H.subscribe
      $ ViewportChanged
      <$ HS.makeEmitter subscribeWindowScroll
  ClickedOutsideSeatPicker -> H.modify_ _ { isVolunteerFilterOpen = false }
  ClickedOutsideOtherStudents -> H.modify_ _ { isOtherStudentsOpen = false }
  Receive input -> do
    H.modify_ \state ->
      state
        { activities = input.activities
        , records = input.records
        , volunteers = input.volunteers
        , draftFilterVolunteerIds = input.draftFilterVolunteerIds
        , draftFilterActivityIds = input.draftFilterActivityIds
        , totalRecords = input.totalRecords
        , isLoading = input.isLoading
        , isLoadingMore = input.isLoadingMore
        , hasMore = input.hasMore
        , loadError = input.loadError
        , selectedIds =
          Array.filter
            (\id -> Array.any (\record -> record.id == id) input.records)
            state.selectedIds
        }
  ViewportChanged -> do
    state <- H.get
    when (state.hasMore && not state.isLoading && not state.isLoadingMore) do
      isVisible <- H.liftEffect isLoadMoreSentinelVisible
      when isVisible do
        H.modify_ _ { isLoadingMore = true }
        H.raise LoadMoreRequested
  SelectRecord index event -> do
    state <- H.get
    case Array.index state.records index of
      Nothing -> pure unit
      Just record ->
        if MouseEvent.shiftKey event then case state.selectionAnchor of
          Nothing -> H.modify_ _ { selectedIds = [ record.id ], selectionAnchor = Just index }
          Just anchor ->
            let
              start = min anchor index

              end = max anchor index

              rangeIds = map _.id (Array.slice start (end + 1) state.records)

              selectedIds =
                if MouseEvent.ctrlKey event || MouseEvent.metaKey event then
                  Array.nub (state.selectedIds <> rangeIds)
                else
                  rangeIds
            in
              H.modify_ _ { selectedIds = selectedIds }
        else if MouseEvent.ctrlKey event || MouseEvent.metaKey event then
          H.modify_
            _
              { selectedIds =
                if Array.elem record.id state.selectedIds then
                  Array.filter (_ /= record.id) state.selectedIds
                else
                  Array.snoc state.selectedIds record.id
              , selectionAnchor = Just index
              }
        else
          H.modify_ _ { selectedIds = [ record.id ], selectionAnchor = Just index }
  ToggleRecord id index event -> do
    H.liftEffect (Event.stopPropagation (MouseEvent.toEvent event))
    H.modify_ \state ->
      state
        { selectedIds =
          if Array.elem id state.selectedIds then
            Array.filter (_ /= id) state.selectedIds
          else
            Array.snoc state.selectedIds id
        , selectionAnchor = Just index
        }
  CopyRecord record event -> do
    H.liftEffect (Event.stopPropagation (MouseEvent.toEvent event))
    H.raise
      ( CopyRequested
          { activityId: record.activityId
          , activityType: record.activityType
          , activityDate: record.activityDate
          , hours: record.hours
          , note: record.note
          }
      )
  AskDeleteRecord id event -> do
    H.liftEffect (Event.stopPropagation (MouseEvent.toEvent event))
    H.modify_
      _
        { selectedIds = [ id ]
        , selectionAnchor = Nothing
        , isDeleteDialogOpen = true
        }
  AskDelete -> do
    state <- H.get
    if Array.null state.selectedIds then
      pure unit
    else
      H.modify_ _ { isDeleteDialogOpen = true }
  CancelDelete -> H.modify_ _ { isDeleteDialogOpen = false }
  ConfirmDelete -> do
    state <- H.get
    H.modify_ _ { isDeleteDialogOpen = false }
    if Array.null state.selectedIds then
      pure unit
    else
      H.raise (DeleteRequested state.selectedIds)
  ToggleVolunteerFilter ->  -- SeatPicker(懸浮窗)總開關
    H.modify_ \state ->
      state
        { isVolunteerFilterOpen = not state.isVolunteerFilterOpen
        , isOtherStudentsOpen = false
        }
  ToggleFilterOtherStudents ->  -- 其他學生(懸浮窗)總開關
    H.modify_ \state ->
      state
        { isOtherStudentsOpen = not state.isOtherStudentsOpen }
  ToggleFilterDraftStudents id ->  -- 單一學生選取/取消選取
    H.modify_ \state ->
      state
        { draftFilterVolunteerIds = toggleId id state.draftFilterVolunteerIds }
  ToggleActivityFilter ->
    H.modify_ \state ->
      state
        { isActivityFilterOpen = not state.isActivityFilterOpen }
  ToggleFilterDraftActivity id ->  -- 單一學活動選取/取消選取
    H.modify_ \state ->
      state
        { draftFilterActivityIds = toggleId id state.draftFilterActivityIds }
  SelectFilterSeatPeriod value -> H.modify_ _ { filterSeatPeriod = fromApiValue_ value, isOtherStudentsOpen = false }
  ApplyVolunteerFilter -> do
    state <- H.get
    H.modify_
      _
        { filterVolunteerIds = state.draftFilterVolunteerIds
        , isVolunteerFilterOpen = false
        , isOtherStudentsOpen = false
        }
    H.raise (VolunteerFilterChanged state.draftFilterVolunteerIds)
  ApplyActivityFilter -> do
    state <- H.get
    H.modify_
      _
        { filterActivityIds = state.draftFilterActivityIds
        , isActivityFilterOpen = false
        }
    H.raise (ActivityFilterChanged state.draftFilterActivityIds)
  ClearVolunteerFilter -> do
    H.modify_ _ { draftFilterVolunteerIds = [], filterVolunteerIds = [] }
    H.raise (VolunteerFilterChanged [])
  ClearActivityFilter -> do
    H.modify_ _ { draftFilterActivityIds = [], filterActivityIds = [] }
    H.raise (ActivityFilterChanged [])
  Retry -> H.raise RetryRequested

renderVolunteerFilter :: forall m. State -> H.ComponentHTML Action Slots m
renderVolunteerFilter state =
  HH.div
    [ HP.class_ (HH.ClassName "hour-record-filter-students-field") ]
    [ renderParticipantField
        { selectionTriggerLabel: "篩選學生"
        , volunteers: state.volunteers
        , selectedParticipantIds: state.draftFilterVolunteerIds
        , selectedSeatPeriod: state.filterSeatPeriod
        , isSeatPickerOpen: state.isVolunteerFilterOpen
        , isOtherStudentsOpen: state.isOtherStudentsOpen
        , participantError: Nothing
        , onToggleSeatPicker: ToggleVolunteerFilter
        , onSelectSeatPeriod: SelectFilterSeatPeriod
        , onToggleOtherParticipants: ToggleFilterOtherStudents
        , onToggleDraftParticipants: ToggleFilterDraftStudents
        , seatStageActions:
            [ { action: ApplyVolunteerFilter
              , btnLabel: "套用"
              , class_: Just "seat-confirm-button"
              }
            , { action: ClearVolunteerFilter
              , btnLabel: "清除"
              , class_: Just "seat-clear-button"
              }
            ]
        }
    ]

renderActivityFilter :: forall m. State -> H.ComponentHTML Action Slots m
renderActivityFilter state =
  let
    selectedNames =
      state.activities
        # Array.filter (\activity -> Array.elem activity.id state.filterActivityIds)
        # map _.name
        # String.joinWith ", "
  in
    HH.div
      [ HP.classes
          ( [ HH.ClassName "hour-record-filter" ]
              <> if state.isActivityFilterOpen then [ HH.ClassName "seat-picker-open" ] else []
          )
      ]
      [ HH.button
          [ HP.class_ (HH.ClassName "seat-picker-trigger")
          , HE.onClick \_ -> ToggleActivityFilter
          ]
          [ HH.text (if Array.null state.filterActivityIds then "篩選活動(全部)" else selectedNames) ]
      , if state.isActivityFilterOpen then
          HH.div
            [ HP.class_ (HH.ClassName "activity-dropdown") ]
            [ if state.isActivityFilterOpen then
                HH.div
                  [ HP.class_ (HH.ClassName "activity-picker") ]
                  ( if Array.null state.activities then
                      [ HH.p_ [ HH.text "沒有活動" ] ]
                    else
                      [ HH.div
                          [ HP.classes
                              [ HH.ClassName "participant-seat-actions"
                              , HH.ClassName "activity-filter-actions"
                              ]
                          ]
                          [ HH.button [ HP.class_ (HH.ClassName "seat-confirm-button"), HE.onClick \_ -> ApplyActivityFilter ] [ HH.text "套用" ]
                          , HH.button [ HP.class_ (HH.ClassName "seat-clear-button"), HE.onClick \_ -> ClearActivityFilter ] [ HH.text "清除" ]
                          ]
                      ]
                        <> map (renderFilterActivityOption state.draftFilterActivityIds) state.activities -- 產生選項們
                  )
              else
                HH.text ""
            ]
        else
          HH.text ""
      ]

renderFilterActivityOption :: forall m. Array Int -> Activity -> H.ComponentHTML Action Slots m
renderFilterActivityOption selectedIds activity =
  HH.button
    [ HP.classes
        ( [ HH.ClassName "participant-unseated-option" ]
            <> if Array.elem activity.id selectedIds then
                [ HH.ClassName "participant-unseated-option-selected" ]
              else
                []
        )
    , HE.onClick \_ -> ToggleFilterDraftActivity activity.id
    ]
    [ HH.div
        [ HP.class_ (HH.ClassName "activity-color-option-gap") ]
        [ HH.span
            [ HP.class_ (HH.ClassName "hour-record-type-tag")
            , HP.style ("background-color: " <> activity.tagColor)
            ]
            [ HH.text (activityTypeLabel activity.defaultType) ]
        , HH.div
            [ HP.class_ (HH.ClassName "activity-color-option-name") ]
            [ HH.text activity.name ]
        ]
    ]

toggleId :: Int -> Array Int -> Array Int
toggleId id ids = if Array.elem id ids then Array.filter (_ /= id) ids else Array.snoc ids id
