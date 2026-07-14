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
import Domain.Volunteer (Seat, showSeat)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

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
  , seat :: Maybe Seat
  }

type State =
  { educationLevel :: EducationLevel
  , name :: String
  , age :: Int
  , seat :: Maybe Seat
  , nameError :: Maybe String
  , isSubmitting :: Boolean
  }

data Action
  = SetEducationLevel String
  | SetName String
  | SetAge String
  | SelectSeat Seat
  | Submit
  | Receive Input

data Output
  = SubmitVolunteer CreateVolunteerRequest

initialState :: Input -> State
initialState input =
  { educationLevel: ElementarySchool
  , name: ""
  , age: 7
  , seat: Nothing
  , nameError: Nothing
  , isSubmitting: input.isSubmitting
  }

component :: forall query m. H.Component query Input Output m
component =
  H.mkComponent
    { initialState
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
    [ HP.class_ (HH.ClassName "student-form-card") ]
    [ HH.h2_ [ HH.text "學生資料" ]
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
        , formField "年齡"
            ( HH.select
                [ HP.value (show state.age)
                , HE.onValueChange SetAge
                ]
                ( map
                    (\age ->
                      HH.option
                        [ HP.value (show age) ]
                        [ HH.text (show age <> " 歲") ]
                    )
                    (Array.range 5 15)
                )
            )
        , HH.div
            [ HP.class_ (HH.ClassName "form-field seat-field") ]
            [ HH.span_ [ HH.text "座位" ]
            , HH.button
                [ HP.class_ (HH.ClassName "seat-picker-trigger") ]
                [ HH.text case state.seat of
                    Nothing -> "選擇座位"
                    Just seat -> showSeat (Just seat)
                ]
            , HH.div
                [ HP.class_ (HH.ClassName "seat-picker") ]
                [ HH.p_ [ HH.text "選擇座位（5 排 × 4 列）" ]
                , HH.div
                    [ HP.class_ (HH.ClassName "seat-stage") ]
                    [ HH.span
                        [ HP.class_ (HH.ClassName "seat-stage-button") ]
                        [ HH.text "講台" ]
                    ]
                , HH.div
                    [ HP.class_ (HH.ClassName "seat-grid") ]
                    ( map
                        (\seat ->
                          HH.button
                            [ HP.class_ (HH.ClassName "seat-button")
                            , HE.onClick \_ -> SelectSeat seat
                            ]
                            [ HH.text (show seat.row <> "-" <> show seat.col) ]
                        )
                        seats
                    )
                ]
            ]
        ]
    , HH.button
        [ HP.class_ (HH.ClassName "student-submit")
        , HP.disabled state.isSubmitting
        , HE.onClick \_ -> Submit
        ]
        if state.isSubmitting then
          [ HH.span [ HP.class_ (HH.ClassName "submit-spinner") ] []
          , HH.text "新增中…"
          ]
        else
          [ HH.text "新增學生" ]
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

seats :: Array Seat
seats = do
  row <- Array.range 1 5
  col <- Array.range 1 4
  pure { row, col }

handleAction
  :: forall m
   . Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  SetEducationLevel value ->
    H.modify_ _ { educationLevel = educationLevelFromApi value }
  SetName name ->
    H.modify_ _ { name = name, nameError = Nothing }
  SetAge value -> case Int.fromString value of
    Nothing -> pure unit
    Just age -> H.modify_ _ { age = age }
  SelectSeat seat ->
    H.modify_ _ { seat = Just seat }
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
            , seat: state.seat
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
