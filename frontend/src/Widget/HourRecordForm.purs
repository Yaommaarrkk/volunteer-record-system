module Widget.HourRecordForm
  ( CreateHourRecordRequest
  , Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Number as Number
import Data.String.Common as String
import Data.String.Pattern (Pattern(..))
import Domain.Activity (Activity, activityTypeLabel)
import Domain.HourRecord (CopiedHourRecord)
import Domain.Volunteer (Seat, SeatPeriod(..), Volunteer, getGrade, seatForPeriod, seatPeriodToApi)
import Effect (Effect)
import Effect.Class (class MonadEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Widget.OutsideClick as OutsideClick

foreign import isPositiveOneDecimal :: String -> Boolean
foreign import focusHoursInputAfterRender :: Effect Unit
foreign import focusNoteInputAfterClear :: Effect Unit

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { activities :: Array Activity
  , volunteers :: Array Volunteer
  , defaultYear :: Int
  , isSubmitting :: Boolean
  , copiedRecord :: Maybe CopiedHourRecord
  , copyVersion :: Int
  , successfulSubmitVersion :: Int
  }

type CreateHourRecordRequest =
  { activityId :: Int
  , activityType :: String
  , activityDate :: String
  , hours :: Number
  , note :: String
  , volunteerIds :: Array Int
  }

type State =
  { activities :: Array Activity
  , volunteers :: Array Volunteer
  , selectedActivityId :: Maybe Int
  , activityType :: String
  , defaultYear :: Int
  , savedDefaultYear :: Int
  , dateText :: String
  , hoursText :: String
  , note :: String
  , selectedVolunteerIds :: Array Int
  , draftVolunteerIds :: Array Int
  , selectedSeatPeriod :: SeatPeriod
  , isSeatPickerOpen :: Boolean
  , isOtherStudentsOpen :: Boolean
  , isHoursPickerOpen :: Boolean
  , isNoteModalOpen :: Boolean
  , isEditingYear :: Boolean
  , yearDraft :: String
  , dateError :: Maybe String
  , hoursError :: Maybe String
  , participantError :: Maybe String
  , isSubmitting :: Boolean
  , clearParticipantsAfterSubmit :: Boolean
  , copyVersion :: Int
  , successfulSubmitVersion :: Int
  }

data Action
  = Initialize
  | Receive Input
  | ClickedOutsideParticipant
  | ClickedOutsideHours
  | SelectActivity String
  | SetActivityType String
  | SetDate String
  | SetHours String
  | OpenHoursPicker
  | CloseHoursPicker
  | SelectQuickHours String
  | SetNote String
  | ClearNote
  | BeginYearEdit
  | SetYearDraft String
  | SaveYear
  | CancelYearEdit
  | ToggleSeatPicker
  | CloseSeatPicker
  | SelectSeatPeriod String
  | ToggleDraftVolunteer Int
  | ToggleOtherStudents
  | ClearDraftVolunteers
  | ConfirmVolunteers
  | OpenNoteModal
  | CloseNoteModal
  | SetClearParticipantsAfterSubmit Boolean
  | Submit

data Output
  = SubmitHourRecord CreateHourRecordRequest
  | UpdateDefaultYear Int

initialState :: Input -> State
initialState input =
  let
    firstActivity = Array.head input.activities
  in
    { activities: input.activities
    , volunteers: input.volunteers
    , selectedActivityId: map _.id firstActivity
    , activityType: fromMaybe "TEACHING" (map _.defaultType firstActivity)
    , defaultYear: input.defaultYear
    , savedDefaultYear: input.defaultYear
    , dateText: ""
    , hoursText: ""
    , note: ""
    , selectedVolunteerIds: []
    , draftVolunteerIds: []
    , selectedSeatPeriod: Year114SecondSemester
    , isSeatPickerOpen: false
    , isOtherStudentsOpen: false
    , isHoursPickerOpen: false
    , isNoteModalOpen: false
    , isEditingYear: false
    , yearDraft: show input.defaultYear
    , dateError: Nothing
    , hoursError: Nothing
    , participantError: Nothing
    , isSubmitting: input.isSubmitting
    , clearParticipantsAfterSubmit: true
    , copyVersion: input.copyVersion
    , successfulSubmitVersion: input.successfulSubmitVersion
    }

component :: forall query m. MonadEffect m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState
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
    [ HP.class_ (HH.ClassName "student-form-card hour-record-form-card") ]
    [ if state.isNoteModalOpen then renderNoteModal state.note
      else HH.text ""
    , HH.h2_ [ HH.text "登錄時數條" ]
    , HH.div
        [ HP.class_ (HH.ClassName "hour-record-primary-row") ]
        [ formField "類型" (renderActivityTypeSelect state.activityType)
        , formField "活動名" (renderActivitySelect state)
        , renderDateField state
        , renderParticipantField state
        , HH.div
            [ HP.classes
                ( [ HH.ClassName "form-field"
                  , HH.ClassName "hour-record-hours-field"
                  ]
                    <> if state.isHoursPickerOpen then
                        [ HH.ClassName "hours-picker-open" ]
                      else
                        []
                )
            ]
            [ HH.span_ [ HH.text "時數" ]
            , HH.button
                [ HP.class_ (HH.ClassName "seat-picker-trigger")
                , HE.onClick \_ -> OpenHoursPicker
                ]
                [ HH.text if String.trim state.hoursText == "" then "輸入時數" else state.hoursText ]
            , renderFieldError state.hoursError
            , renderHoursPicker state
            ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "hour-record-secondary-row") ]
        [ HH.label
            [ HP.class_ (HH.ClassName "form-field hour-record-note-field") ]
            [ HH.span_ [ HH.text "備註" ]
            , HH.div
                [ HP.class_ (HH.ClassName "hour-record-note-input-wrap") ]
                [ HH.div
                    [ HP.class_ (HH.ClassName "hour-record-note-text-wrap") ]
                    [ HH.input
                        [ HP.type_ HP.InputText
                        , HP.attr (HH.AttrName "data-hour-record-note-input") ""
                        , HP.placeholder "輸入備註，或按右側按鈕放大"
                        , HP.value state.note
                        , HE.onValueInput SetNote
                        ]
                    , HH.button
                        [ HP.class_ (HH.ClassName "hour-record-note-clear")
                        , HP.disabled (String.trim state.note == "")
                        , HP.attr (HH.AttrName "aria-label") "清除目前備註"
                        , HP.attr (HH.AttrName "title") "清除備註"
                        , HE.onClick \_ -> ClearNote
                        ]
                        [ HH.text "×" ]
                    ]
                , HH.button
                    [ HP.class_ (HH.ClassName "hour-record-note-expand")
                    , HP.attr (HH.AttrName "aria-label") "放大備註輸入框"
                    , HP.attr (HH.AttrName "title") "放大備註"
                    , HE.onClick \_ -> OpenNoteModal
                    ]
                    [ HH.text "⛶" ]
                ]
            ]
        , HH.label
            [ HP.class_ (HH.ClassName "hour-record-clear-participants") ]
            [ HH.input
                [ HP.type_ HP.InputCheckbox
                , HP.checked state.clearParticipantsAfterSubmit
                , HE.onChecked SetClearParticipantsAfterSubmit
                ]
            , HH.span_ [ HH.text "送出後清空學生" ]
            ]
        , HH.button
            [ HP.class_ (HH.ClassName "student-submit hour-record-submit")
            , HP.disabled state.isSubmitting
            , HE.onClick \_ -> Submit
            ]
            if state.isSubmitting then
              [ HH.span [ HP.class_ (HH.ClassName "submit-spinner") ] []
              , HH.text "送出中…"
              ]
            else
              [ HH.text "送出" ]
        ]
    ]

renderActivitySelect :: forall m. State -> H.ComponentHTML Action Slots m
renderActivitySelect state =
  let
    activities = Array.filter (\activity -> activity.defaultType == state.activityType) state.activities
  in
    HH.select
      [ HP.value (fromMaybe "" (map show state.selectedActivityId))
      , HE.onValueChange SelectActivity
      ]
      ( if Array.null activities then
          [ HH.option [ HP.value "" ] [ HH.text "此類型目前沒有活動" ] ]
        else
          map
            (\activity ->
              HH.option
                [ HP.value (show activity.id) ]
                [ HH.text activity.name ]
            )
            activities
      )

renderActivityTypeSelect :: forall m. String -> H.ComponentHTML Action Slots m
renderActivityTypeSelect selectedType =
  HH.select
    [ HP.value selectedType
    , HE.onValueChange SetActivityType
    ]
    [ typeOption "TEACHING"
    , typeOption "COMPANION_READING"
    , typeOption "PLAY"
    , typeOption "DAILY_INTERACTION"
    , typeOption "PASSIVE"
    ]

typeOption :: forall m. String -> H.ComponentHTML Action Slots m
typeOption value = HH.option [ HP.value value ] [ HH.text (activityTypeLabel value) ]

renderHoursPicker :: forall m. State -> H.ComponentHTML Action Slots m
renderHoursPicker state =
  HH.div
    [ HP.class_ (HH.ClassName "seat-picker hour-record-hours-picker") ]
    [ HH.input
        [ HP.type_ HP.InputText
        , HP.attr (HH.AttrName "data-hour-record-hours-input") ""
        , HP.autofocus true
        , HP.placeholder "例如 1 或 1.5"
        , HP.value state.hoursText
        , HE.onValueInput SetHours
        ]
    , renderQuickHoursRow [ "0.1", "0.2", "0.3", "0.4", "0.5" ]
    , renderQuickHoursRow [ "0.6", "0.7", "0.8", "0.9", "1" ]
    ]

renderQuickHoursRow :: forall m. Array String -> H.ComponentHTML Action Slots m
renderQuickHoursRow values =
  HH.div
    [ HP.class_ (HH.ClassName "hour-record-quick-hours-row") ]
    ( map
        (\value ->
          HH.button
            [ HE.onClick \_ -> SelectQuickHours value ]
            [ HH.text value ]
        )
        values
    )

renderDateField :: forall m. State -> H.ComponentHTML Action Slots m
renderDateField state =
  HH.div
    [ HP.class_ (HH.ClassName "form-field hour-record-date-field") ]
    [ HH.span_ [ HH.text "日期" ]
    , HH.div
        [ HP.class_ (HH.ClassName "hour-record-date-inputs") ]
        [ if state.isEditingYear then
            HH.div
              [ HP.class_ (HH.ClassName "hour-record-year-editor") ]
              [ HH.input
                  [ HP.type_ HP.InputText
                  , HP.value state.yearDraft
                  , HE.onValueInput SetYearDraft
                  ]
              , HH.button [ HE.onClick \_ -> SaveYear ] [ HH.text "✓" ]
              , HH.button [ HE.onClick \_ -> CancelYearEdit ] [ HH.text "↻" ]
              ]
          else
            HH.button
              [ HP.class_ (HH.ClassName "hour-record-year-button")
              , HP.attr (HH.AttrName "title") "修改預設年份"
              , HE.onClick \_ -> BeginYearEdit
              ]
              [ HH.text (show state.defaultYear) ]
        , HH.input
            [ HP.type_ HP.InputText
            , HP.placeholder "例如 7/15"
            , HP.value state.dateText
            , HE.onValueInput SetDate
            ]
        ]
    , renderFieldError state.dateError
    ]

renderParticipantField :: forall m. State -> H.ComponentHTML Action Slots m
renderParticipantField state =
  let
    selectedNames =
      state.volunteers
        # Array.filter (\volunteer -> Array.elem volunteer.id state.selectedVolunteerIds)
        # map _.name
        # String.joinWith ", "
    volunteersWithoutSeat =
      state.volunteers
        # Array.filter
            (\volunteer ->
              case seatForPeriod state.selectedSeatPeriod volunteer of
                Nothing -> true
                Just _ -> false
            )
  in
  HH.div
    [ HP.classes
        ( [ HH.ClassName "form-field"
          , HH.ClassName "seat-field"
          , HH.ClassName "hour-record-participant-field"
          ]
            <> if state.isSeatPickerOpen then [ HH.ClassName "seat-picker-open" ] else []
            <> if state.participantError /= Nothing then [ HH.ClassName "participant-field-error" ] else []
        )
    ]
    [ HH.span_ [ HH.text "參與學生" ]
    , HH.button
        [ HP.class_ (HH.ClassName "seat-picker-trigger")
        , HE.onClick \_ -> ToggleSeatPicker
        ]
        [ HH.span
            [ HP.class_ (HH.ClassName "participant-name-summary")
            , HP.attr (HH.AttrName "title") selectedNames
            ]
            [ HH.text
                if Array.null state.selectedVolunteerIds then
                  "選擇學生"
                else
                  selectedNames
            ]
        ]
    , renderFieldError state.participantError
    , HH.div
        [ HP.class_ (HH.ClassName "seat-picker hour-record-seat-picker") ]
        [ HH.label
            [ HP.class_ (HH.ClassName "seat-period-select") ]
            [ HH.span_ [ HH.text "選學期" ]
            , HH.select
                [ HP.value (seatPeriodToApi state.selectedSeatPeriod)
                , HE.onValueChange SelectSeatPeriod
                ]
                [ HH.option
                    [ HP.value "YEAR_114_SECOND_SEMESTER" ]
                    [ HH.text "114下" ]
                , HH.option
                    [ HP.value "YEAR_115_SUMMER" ]
                    [ HH.text "115暑假" ]
                ]
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "participant-seat-stage") ]
            [ HH.div
                [ HP.class_ (HH.ClassName "participant-unseated-dropdown") ]
                [ HH.button
                    [ HP.class_ (HH.ClassName "participant-unseated-trigger")
                    , HE.onClick \_ -> ToggleOtherStudents
                    ]
                    [ HH.span_ [ HH.text "其他學生" ]
                    , HH.span_ [ HH.text if state.isOtherStudentsOpen then "▴" else "▾" ]
                    ]
                , if state.isOtherStudentsOpen then
                    HH.div
                      [ HP.class_ (HH.ClassName "participant-unseated-menu") ]
                      if Array.null volunteersWithoutSeat then
                        [ HH.p_ [ HH.text "沒有其他學生" ] ]
                      else
                        map
                          (\volunteer ->
                            HH.button
                              [ HP.classes
                                  ( [ HH.ClassName "participant-unseated-option" ]
                                      <> if Array.elem volunteer.id state.draftVolunteerIds then
                                          [ HH.ClassName "participant-unseated-option-selected" ]
                                        else
                                          []
                                  )
                              , HE.onClick \_ -> ToggleDraftVolunteer volunteer.id
                              ]
                              [ HH.text (volunteerWithGrade volunteer) ]
                          )
                          volunteersWithoutSeat
                  else
                    HH.text ""
                ]
            , HH.span
                [ HP.class_ (HH.ClassName "seat-stage-button") ]
                [ HH.text "講台" ]
            , HH.div
                [ HP.class_ (HH.ClassName "participant-seat-actions") ]
                [ HH.button
                    [ HP.class_ (HH.ClassName "seat-confirm-button")
                    , HE.onClick \_ -> ConfirmVolunteers
                    ]
                    [ HH.text "確認" ]
                , HH.button
                    [ HP.class_ (HH.ClassName "seat-clear-button")
                    , HE.onClick \_ -> ClearDraftVolunteers
                    ]
                    [ HH.text "清除" ]
                ]
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "seat-grid participant-seat-grid") ]
            (map (renderVolunteerSeat state) seats)
        ]
    ]

renderVolunteerSeat :: forall m. State -> Seat -> H.ComponentHTML Action Slots m
renderVolunteerSeat state seat =
  case volunteerAtSeat state.selectedSeatPeriod seat state.volunteers of
    Nothing ->
      HH.button
        [ HP.classes [ HH.ClassName "seat-button", HH.ClassName "participant-seat-empty" ]
        , HP.disabled true
        ]
        [ HH.text (show seat.row <> "-" <> show seat.col) ]
    Just volunteer ->
      HH.button
        [ HP.classes
            ( [ HH.ClassName "seat-button"
              , HH.ClassName "participant-seat-button"
              ]
                <> if Array.elem volunteer.id state.draftVolunteerIds then
                    [ HH.ClassName "participant-seat-selected" ]
                  else
                    []
            )
        , HE.onClick \_ -> ToggleDraftVolunteer volunteer.id
        ]
        [ HH.strong_ [ HH.text (volunteerWithGrade volunteer) ] ]

volunteerWithGrade :: Volunteer -> String
volunteerWithGrade volunteer = volunteer.name <> "(" <> show (getGrade volunteer) <> ")"

renderNoteModal :: forall m. String -> H.ComponentHTML Action Slots m
renderNoteModal note =
  HH.div_
    [ HH.div
        [ HP.class_ (HH.ClassName "delete-confirm-backdrop")
        , HE.onClick \_ -> CloseNoteModal
        ]
        []
    , HH.div
        [ HP.class_ (HH.ClassName "hour-record-note-modal") ]
        [ HH.h3_ [ HH.text "備註" ]
        , HH.textarea
            [ HP.attr (HH.AttrName "rows") "10"
            , HP.placeholder "輸入備註"
            , HP.value note
            , HE.onValueInput SetNote
            ]
        , HH.button
            [ HP.class_ (HH.ClassName "activity-note-done")
            , HE.onClick \_ -> CloseNoteModal
            ]
            [ HH.text "完成" ]
        ]
    ]

formField
  :: forall m
   . String
  -> H.ComponentHTML Action Slots m
  -> H.ComponentHTML Action Slots m
formField label control =
  HH.label
    [ HP.class_ (HH.ClassName "form-field") ]
    [ HH.span_ [ HH.text label ]
    , control
    ]

renderFieldError :: forall m. Maybe String -> H.ComponentHTML Action Slots m
renderFieldError = case _ of
  Nothing -> HH.text ""
  Just message -> HH.span [ HP.class_ (HH.ClassName "form-error") ] [ HH.text message ]

handleAction
  :: forall m
   . MonadEffect m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> do
    void $ H.subscribe (ClickedOutsideParticipant <$ OutsideClick.outsideClickEmitter ".hour-record-participant-field")
    void $ H.subscribe (ClickedOutsideHours <$ OutsideClick.outsideClickEmitter ".hour-record-hours-field")
  ClickedOutsideParticipant -> H.modify_ _ { isSeatPickerOpen = false, isOtherStudentsOpen = false }
  ClickedOutsideHours -> H.modify_ _ { isHoursPickerOpen = false }
  Receive input -> do
    state <- H.get
    let firstActivity = Array.head input.activities
    let hasNewCopy = input.copyVersion /= state.copyVersion
    let copiedDate = input.copiedRecord >>= parseIsoDate
    let hasSavedYearUpdate = input.defaultYear /= state.savedDefaultYear
    let hasSuccessfulSubmit = input.successfulSubmitVersion /= state.successfulSubmitVersion
    let shouldClearParticipants = hasSuccessfulSubmit && state.clearParticipantsAfterSubmit
    let activeYear =
          if hasNewCopy then fromMaybe state.defaultYear (copiedDate <#> _.year)
          else if hasSavedYearUpdate then input.defaultYear
          else state.defaultYear
    H.modify_
      _
        { activities = input.activities
        , volunteers = input.volunteers
        , selectedActivityId =
            if hasNewCopy then input.copiedRecord <#> _.activityId
            else case state.selectedActivityId of
              Nothing -> map _.id firstActivity
              selected -> selected
        , activityType =
            if hasNewCopy then fromMaybe state.activityType (input.copiedRecord <#> _.activityType)
            else case state.selectedActivityId of
              Nothing -> fromMaybe state.activityType (map _.defaultType firstActivity)
              _ -> state.activityType
        , defaultYear = activeYear
        , savedDefaultYear = input.defaultYear
        , dateText = if hasNewCopy then fromMaybe state.dateText (copiedDate <#> \date -> show date.month <> "/" <> show date.day) else state.dateText
        , hoursText = if hasNewCopy then fromMaybe state.hoursText (input.copiedRecord <#> \record -> show record.hours) else state.hoursText
        , note = if hasNewCopy then fromMaybe state.note (input.copiedRecord <#> _.note) else state.note
        , selectedVolunteerIds = if shouldClearParticipants then [] else state.selectedVolunteerIds
        , draftVolunteerIds = if shouldClearParticipants then [] else state.draftVolunteerIds
        , participantError = if shouldClearParticipants then Nothing else state.participantError
        , isSubmitting = input.isSubmitting
        , isHoursPickerOpen = if hasSuccessfulSubmit then false else state.isHoursPickerOpen
        , yearDraft = show activeYear
        , copyVersion = input.copyVersion
        , successfulSubmitVersion = input.successfulSubmitVersion
        }
  SelectActivity value -> case Int.fromString value of
    Nothing -> pure unit
    Just id -> do
      state <- H.get
      case Array.find (\activity -> activity.id == id) state.activities of
        Nothing -> pure unit
        Just _ ->
          H.modify_
            _
              { selectedActivityId = Just id
              }
  SetActivityType activityType -> do
    state <- H.get
    let selectedActivity = Array.find (\activity -> activity.defaultType == activityType) state.activities
    H.modify_
      _
        { activityType = activityType
        , selectedActivityId = map _.id selectedActivity
        }
  SetDate value -> do
    state <- H.get
    H.modify_ _ { dateText = value, dateError = validateDate state.defaultYear value }
  SetHours value -> H.modify_ _ { hoursText = value, hoursError = validateHours value }
  OpenHoursPicker -> do
    H.modify_
      _
        { isHoursPickerOpen = true
        , isSeatPickerOpen = false
        , isOtherStudentsOpen = false
        }
    H.liftEffect focusHoursInputAfterRender
  CloseHoursPicker -> H.modify_ _ { isHoursPickerOpen = false }
  SelectQuickHours value ->
    H.modify_
      _
        { hoursText = value
        , hoursError = Nothing
        , isHoursPickerOpen = false
        }
  SetNote note -> H.modify_ _ { note = note }
  ClearNote -> do
    H.modify_ _ { note = "" }
    H.liftEffect focusNoteInputAfterClear
  BeginYearEdit -> H.modify_ \state -> state { isEditingYear = true, yearDraft = show state.defaultYear }
  SetYearDraft year -> H.modify_ _ { yearDraft = year }
  SaveYear -> do
    state <- H.get
    case Int.fromString (String.trim state.yearDraft) of
      Just year | year >= 2000 && year <= 2100 -> do
        H.modify_
          _
            { defaultYear = year
            , isEditingYear = false
            , dateError = validateDate year state.dateText
            }
        H.raise (UpdateDefaultYear year)
      _ -> H.modify_ _ { dateError = Just "年份必須介於 2000 到 2100" }
  CancelYearEdit -> H.modify_ \state -> state { isEditingYear = false, yearDraft = show state.defaultYear }
  ToggleSeatPicker ->
    H.modify_ \state ->
      if state.isSeatPickerOpen then state { isSeatPickerOpen = false, isOtherStudentsOpen = false }
      else
        state
          { isSeatPickerOpen = true
          , isOtherStudentsOpen = false
          , isHoursPickerOpen = false
          , draftVolunteerIds = state.selectedVolunteerIds
          }
  CloseSeatPicker -> H.modify_ _ { isSeatPickerOpen = false, isOtherStudentsOpen = false }
  SelectSeatPeriod value ->
    H.modify_ _ { selectedSeatPeriod = seatPeriodFromApi value, isOtherStudentsOpen = false }
  ToggleDraftVolunteer id ->
    H.modify_ \state ->
      let
        volunteerIds =
          if Array.elem id state.draftVolunteerIds then
            Array.filter (_ /= id) state.draftVolunteerIds
          else
            Array.snoc state.draftVolunteerIds id
      in
        state
          { draftVolunteerIds = volunteerIds
          , selectedVolunteerIds = volunteerIds
          , participantError = if Array.null volunteerIds then Just "至少選擇一位學生" else Nothing
          }
  ToggleOtherStudents -> H.modify_ \state -> state { isOtherStudentsOpen = not state.isOtherStudentsOpen }
  ClearDraftVolunteers ->
    H.modify_
      _
        { draftVolunteerIds = []
        , selectedVolunteerIds = []
        , participantError = Just "至少選擇一位學生"
        }
  ConfirmVolunteers -> H.modify_ _ { isSeatPickerOpen = false, isOtherStudentsOpen = false }
  OpenNoteModal -> H.modify_ _ { isNoteModalOpen = true }
  CloseNoteModal -> H.modify_ _ { isNoteModalOpen = false }
  SetClearParticipantsAfterSubmit value -> H.modify_ _ { clearParticipantsAfterSubmit = value }
  Submit -> do
    state <- H.get
    let dateError = validateDate state.defaultYear state.dateText
    let hoursError = validateHours state.hoursText
    let participantError = if Array.null state.selectedVolunteerIds then Just "請重新選擇至少一位參與學生" else Nothing
    H.modify_
      _
        { dateError = dateError
        , hoursError = hoursError
        , participantError = participantError
        }
    case state.selectedActivityId, parseDate state.defaultYear state.dateText, Number.fromString state.hoursText of
      Just activityId, Just activityDate, Just hours
        | dateError == Nothing && hoursError == Nothing && participantError == Nothing ->
            H.raise
              ( SubmitHourRecord
                  { activityId
                  , activityType: state.activityType
                  , activityDate
                  , hours
                  , note: String.trim state.note
                  , volunteerIds: state.selectedVolunteerIds
                  }
              )
      _, _, _ -> pure unit

validateDate :: Int -> String -> Maybe String
validateDate year value =
  if String.trim value == "" then Just "日期不能為空"
  else case parseMonthDay value of
    Nothing -> Just "日期格式請輸入月/日，例如 7/15"
    Just date ->
      if date.month < 1 || date.month > 12 then Just "月份必須介於 1 到 12"
      else if date.day < 1 || date.day > daysInMonth year date.month then Just "這個日期不存在"
      else Nothing

parseDate :: Int -> String -> Maybe String
parseDate year value = do
  date <- parseMonthDay value
  if validateDate year value == Nothing then
    Just (show year <> "-" <> pad2 date.month <> "-" <> pad2 date.day)
  else
    Nothing

parseMonthDay :: String -> Maybe { month :: Int, day :: Int }
parseMonthDay value = case String.split (Pattern "/") (String.trim value) of
  [ monthText, dayText ] -> do
    month <- Int.fromString (String.trim monthText)
    day <- Int.fromString (String.trim dayText)
    pure { month, day }
  _ -> Nothing

parseIsoDate :: CopiedHourRecord -> Maybe { year :: Int, month :: Int, day :: Int }
parseIsoDate record = case String.split (Pattern "-") record.activityDate of
  [ yearText, monthText, dayText ] -> do
    year <- Int.fromString yearText
    month <- Int.fromString monthText
    day <- Int.fromString dayText
    pure { year, month, day }
  _ -> Nothing

validateHours :: String -> Maybe String
validateHours value
  | String.trim value == "" = Just "時數不能為空"
  | not (isPositiveOneDecimal (String.trim value)) = Just "時數必須是正數，且最多一位小數"
  | otherwise = Nothing

daysInMonth :: Int -> Int -> Int
daysInMonth year = case _ of
  2 -> if isLeapYear year then 29 else 28
  4 -> 30
  6 -> 30
  9 -> 30
  11 -> 30
  _ -> 31

isLeapYear :: Int -> Boolean
isLeapYear year = mod year 400 == 0 || (mod year 4 == 0 && mod year 100 /= 0)

pad2 :: Int -> String
pad2 value = if value < 10 then "0" <> show value else show value

seatPeriodFromApi :: String -> SeatPeriod
seatPeriodFromApi = case _ of
  "YEAR_115_SUMMER" -> Year115Summer
  _ -> Year114SecondSemester

volunteerAtSeat :: SeatPeriod -> Seat -> Array Volunteer -> Maybe Volunteer
volunteerAtSeat period seat =
  Array.find (\volunteer -> seatForPeriod period volunteer == Just seat)

seats :: Array Seat
seats = do
  row <- Array.range 1 5
  col <- Array.range 1 4
  pure { row, col }
