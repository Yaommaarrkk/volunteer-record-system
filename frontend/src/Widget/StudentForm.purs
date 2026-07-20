module Widget.StudentForm
  ( CreateVolunteerRequest
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.String.Common as String
import Domain.EducationLevel (EducationLevel(..), educationLevelToApi)
import Domain.Volunteer (Seat, SeatAssignment, SeatPeriod(..), ageToGradeLabel, seatPeriodToApi, showSeat)
import Effect.Class (class MonadEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Widget.OutsideClick as OutsideClick

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { isSubmitting :: Boolean
  }

type CreateVolunteerRequest =
  { educationLevel :: String
  , name :: String
  , age :: Int
  , seats :: Array SeatAssignment
  }

type State =
  { educationLevel :: EducationLevel
  , name :: String
  , age :: Int
  , seat114SecondSemester :: Maybe Seat
  , seat115Summer :: Maybe Seat
  , nameError :: Maybe String
  , isSubmitting :: Boolean
  , openSeatPicker :: Maybe SeatPeriod
  }

data Action
  = Initialize
  | SetEducationLevel String
  | SetName String
  | SetAge String
  | ToggleSeatPicker SeatPeriod
  | CloseSeatPicker
  | ClearSeat SeatPeriod
  | SelectSeat SeatPeriod Seat
  | Submit
  | Receive Input

data Output
  = SubmitVolunteer CreateVolunteerRequest

initialState :: Input -> State
initialState input =
  { educationLevel: ElementarySchool
  , name: ""
  , age: 7
  , seat114SecondSemester: Nothing
  , seat115Summer: Nothing
  , nameError: Nothing
  , isSubmitting: input.isSubmitting
  , openSeatPicker: Nothing
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
    [ HP.class_ (HH.ClassName "student-form-card") ]
    [ HH.h2_ [ HH.text "添加學生" ]
    , HH.div
        [ HP.class_ (HH.ClassName "student-form-grid") ]
        [ formField "類型"
            ( HH.select
                [ HP.value (educationLevelToApi state.educationLevel)
                , HE.onValueChange SetEducationLevel
                ]
                [ HH.option
                    [ HP.value "ELEMENTARY_SCHOOL" ]
                    [ HH.text "國小" ]
                , HH.option
                    [ HP.value "JUNIOR_HIGH_SCHOOL" ]
                    [ HH.text "國中" ]
                ]
            )
        , HH.label
            [ HP.class_ (HH.ClassName "form-field") ]
            [ HH.span_ [ HH.text "姓名" ]
            , HH.input
                [ HP.type_ HP.InputText
                , HP.placeholder "請輸入學生姓名"
                , HP.value state.name
                , HE.onValueInput SetName
                ]
            , case state.nameError of
                Nothing -> HH.text ""
                Just message ->
                  HH.span
                    [ HP.class_ (HH.ClassName "form-error") ]
                    [ HH.text message ]
            ]
        , formField "年級(暑假前)"
            ( HH.select
                [ HP.value (show state.age)
                , HE.onValueChange SetAge
                ]
                ( map
                    (\age ->
                      HH.option
                        [ HP.value (show age) ]
                        [ HH.text (ageToGradeLabel age) ]
                    )
                    (Array.range 5 15)
                )
            )
        , seatField "114下座位" Year114SecondSemester state.seat114SecondSemester state.openSeatPicker
        , seatField "115暑假座位" Year115Summer state.seat115Summer state.openSeatPicker
        , HH.button
            [ HP.class_ (HH.ClassName "student-submit")
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

seatField
  :: forall m
   . String
  -> SeatPeriod
  -> Maybe Seat
  -> Maybe SeatPeriod
  -> H.ComponentHTML Action Slots m
seatField label period selectedSeat openSeatPicker =
  HH.div
    [ HP.classes
        ( [ HH.ClassName "form-field"
          , HH.ClassName "seat-field"
          ]
            <> if openSeatPicker == Just period then
                [ HH.ClassName "seat-picker-open" ]
              else
                []
        )
    ]
    [ HH.span_ [ HH.text label ]
    , HH.button
        [ HP.class_ (HH.ClassName "seat-picker-trigger")
        , HE.onClick \_ -> ToggleSeatPicker period
        ]
        [ HH.text (showSeat selectedSeat) ]
    , HH.div
        [ HP.class_ (HH.ClassName "seat-picker") ]
        [ HH.p_ [ HH.text "選擇座位（5 排 × 4 列）" ]
        , HH.div
            [ HP.class_ (HH.ClassName "seat-stage") ]
            [ HH.span
                [ HP.class_ (HH.ClassName "seat-stage-spacer") ]
                []
            , HH.span
                [ HP.class_ (HH.ClassName "seat-stage-button") ]
                [ HH.text "講台" ]
            , HH.button
                [ HP.class_ (HH.ClassName "seat-clear-button")
                , HE.onClick \_ -> ClearSeat period
                ]
                [ HH.text "清除" ]
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "seat-grid") ]
            ( map
                (\seat ->
                  HH.button
                    [ HP.class_ (HH.ClassName "seat-button")
                    , HE.onClick \_ -> SelectSeat period seat
                    ]
                    [ HH.text (show seat.row <> "-" <> show seat.col) ]
                )
                seats
            )
        ]
    ]

seats :: Array Seat
seats = do
  row <- Array.range 1 5
  col <- Array.range 1 4
  pure { row, col }

handleAction
  :: forall m
   . MonadEffect m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> void $ H.subscribe (CloseSeatPicker <$ OutsideClick.outsideClickEmitter ".seat-field")
  SetEducationLevel value ->
    H.modify_ _ { educationLevel = educationLevelFromApi value }
  SetName name ->
    H.modify_ _ { name = name, nameError = Nothing }
  SetAge value -> case Int.fromString value of
    Nothing -> pure unit
    Just age -> H.modify_ _ { age = age }
  ToggleSeatPicker period ->
    H.modify_ \state ->
      state
        { openSeatPicker =
            if state.openSeatPicker == Just period then Nothing
            else Just period
        }
  CloseSeatPicker ->
    H.modify_ _ { openSeatPicker = Nothing }
  ClearSeat period -> case period of
    Year114SecondSemester ->
      H.modify_ _ { seat114SecondSemester = Nothing, openSeatPicker = Nothing }
    Year115Summer ->
      H.modify_ _ { seat115Summer = Nothing, openSeatPicker = Nothing }
  SelectSeat period seat -> case period of
    Year114SecondSemester ->
      H.modify_ _ { seat114SecondSemester = Just seat, openSeatPicker = Nothing }
    Year115Summer ->
      H.modify_ _ { seat115Summer = Just seat, openSeatPicker = Nothing }
  Submit -> do
    state <- H.get
    if state.isSubmitting then
      pure unit
    else if String.trim state.name == "" then
      H.modify_ _ { nameError = Just "姓名不能為空" }
    else
      H.raise
        ( SubmitVolunteer
            { educationLevel: educationLevelToApi state.educationLevel
            , name: String.trim state.name
            , age: state.age
            , seats:
                Array.catMaybes
                  [ map
                      (\seat -> { period: seatPeriodToApi Year114SecondSemester, seat })
                      state.seat114SecondSemester
                  , map
                      (\seat -> { period: seatPeriodToApi Year115Summer, seat })
                      state.seat115Summer
                  ]
            }
        )
  Receive input ->
    H.modify_ _ { isSubmitting = input.isSubmitting }

educationLevelFromApi :: String -> EducationLevel
educationLevelFromApi = case _ of
  "KINDERGARTEN" -> Kindergarten
  "JUNIOR_HIGH_SCHOOL" -> JuniorHighSchool
  "SENIOR_HIGH_SCHOOL" -> SeniorHighSchool
  "ADULT" -> Adult
  _ -> ElementarySchool
