module Widget.ActivityForm
  ( CreateActivityRequest
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.String.Common as String
import Domain.Activity (ActivityType(..), activityTypeFromApi, activityTypeToApi)
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

type CreateActivityRequest =
  { name :: String
  , defaultType :: String
  }

type State =
  { name :: String
  , defaultType :: ActivityType
  , nameError :: Maybe String
  , isSubmitting :: Boolean
  }

data Action
  = SetName String
  | SetDefaultType String
  | Submit
  | Receive Input

data Output
  = SubmitActivity CreateActivityRequest

initialState :: Input -> State
initialState input =
  { name: ""
  , defaultType: Teaching
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
    [ HH.h2_ [ HH.text "添加活動" ]
    , HH.div
        [ HP.class_ (HH.ClassName "activity-form-grid") ]
        [ HH.label
            [ HP.class_ (HH.ClassName "form-field") ]
            [ HH.span_ [ HH.text "活動名" ]
            , HH.input
                [ HP.type_ HP.InputText
                , HP.placeholder "請輸入活動名稱"
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
        , formField "預設類型"
            ( HH.select
                [ HP.value (activityTypeToApi state.defaultType)
                , HE.onValueChange SetDefaultType
                ]
                [ activityTypeOption "TEACHING" "教學"
                , activityTypeOption "COMPANION_READING" "陪讀"
                , activityTypeOption "PLAY" "玩樂"
                , activityTypeOption "DAILY_INTERACTION" "日常互動"
                , activityTypeOption "PASSIVE" "被動"
                ]
            )
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

activityTypeOption :: forall m. String -> String -> H.ComponentHTML Action Slots m
activityTypeOption value label =
  HH.option [ HP.value value ] [ HH.text label ]

handleAction
  :: forall m
   . Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  SetName name -> H.modify_ _ { name = name, nameError = Nothing }
  SetDefaultType value -> H.modify_ _ { defaultType = activityTypeFromApi value }
  Submit -> do
    state <- H.get
    if state.isSubmitting then
      pure unit
    else if String.trim state.name == "" then
      H.modify_ _ { nameError = Just "活動名不能為空" }
    else
      H.raise
        ( SubmitActivity
            { name: String.trim state.name
            , defaultType: activityTypeToApi state.defaultType
            }
        )
  Receive input -> H.modify_ _ { isSubmitting = input.isSubmitting }
