module Widget.DailyActivityForm
  ( Input
  , Output(..)
  , SaveDailyActivityRequest
  , Slot
  , component
  ) where

import Prelude

import Data.Maybe (Maybe(..), fromMaybe)
import Data.String.CodeUnits as CodeUnits
import Data.String.Common as String
import Effect (Effect)
import Effect.Class (class MonadEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { isSubmitting :: Boolean
  , successfulSubmitVersion :: Int
  , copiedDescription :: Maybe String
  , copyVersion :: Int
  }

type SaveDailyActivityRequest =
  { activityDate :: String
  , description :: String
  }

type State =
  { activityDate :: String
  , description :: String
  , dateError :: Maybe String
  , descriptionError :: Maybe String
  , isSubmitting :: Boolean
  , successfulSubmitVersion :: Int
  , copyVersion :: Int
  }

data Action
  = Initialize
  | Receive Input
  | SetActivityDate String
  | SetDescription String
  | Submit

data Output
  = SaveDailyActivity SaveDailyActivityRequest

foreign import getTodayIsoDate :: Effect String
foreign import trimLeadingDescriptionWhitespace :: String -> String

component :: forall query m. MonadEffect m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState: \input ->
        { activityDate: ""
        , description: ""
        , dateError: Nothing
        , descriptionError: Nothing
        , isSubmitting: input.isSubmitting
        , successfulSubmitVersion: input.successfulSubmitVersion
        , copyVersion: input.copyVersion
        }
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { initialize = Just Initialize
            , receive = Just <<< Receive
            , handleAction = handleAction
            }
    }

render :: forall m. State -> H.ComponentHTML Action Slots m
render state =
  HH.section
    [ HP.class_ (HH.ClassName "student-form-card daily-activity-form-card") ]
    [ HH.h2_ [ HH.text "添加當日活動" ]
    , HH.div
        [ HP.class_ (HH.ClassName "daily-activity-form-row") ]
        [ HH.label
            [ HP.class_ (HH.ClassName "form-field daily-activity-date-field") ]
            [ HH.span_ [ HH.text "日期" ]
            , HH.input
                [ HP.type_ HP.InputDate
                , HP.value state.activityDate
                , HE.onValueInput SetActivityDate
                ]
            , renderError state.dateError
            ]
        , HH.label
            [ HP.class_ (HH.ClassName "form-field daily-activity-description-field") ]
            [ HH.span_ [ HH.text "當日主要活動" ]
            , HH.input
                [ HP.type_ HP.InputText
                , HP.attr (HH.AttrName "maxlength") "120"
                , HP.placeholder "例如：戶外教學"
                , HP.value state.description
                , HE.onValueInput SetDescription
                ]
            , renderError state.descriptionError
            ]
        , HH.button
            [ HP.class_ (HH.ClassName "student-submit daily-activity-submit")
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

renderError :: forall m. Maybe String -> H.ComponentHTML Action Slots m
renderError = case _ of
  Nothing -> HH.text ""
  Just message -> HH.span [ HP.class_ (HH.ClassName "form-error") ] [ HH.text message ]

handleAction
  :: forall m
   . MonadEffect m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> do
    today <- H.liftEffect getTodayIsoDate
    H.modify_ _ { activityDate = today }
  Receive input -> do
    state <- H.get
    let hasSuccessfulSubmit =
          input.successfulSubmitVersion /= state.successfulSubmitVersion
    let hasCopiedDescription = input.copyVersion /= state.copyVersion
    H.modify_
      _
        { description =
            if hasSuccessfulSubmit then ""
            else if hasCopiedDescription then String.trim (fromMaybe state.description input.copiedDescription)
            else state.description
        , descriptionError =
            if hasSuccessfulSubmit then Nothing
            else if hasCopiedDescription then Nothing
            else state.descriptionError
        , isSubmitting = input.isSubmitting
        , successfulSubmitVersion = input.successfulSubmitVersion
        , copyVersion = input.copyVersion
        }
  SetActivityDate activityDate ->
    H.modify_
      _
        { activityDate = activityDate
        , dateError =
            if String.trim activityDate == "" then Just "日期不能為空"
            else Nothing
        }
  SetDescription description ->
    let cleanedDescription = trimLeadingDescriptionWhitespace description
    in
    H.modify_
      _
        { description = cleanedDescription
        , descriptionError = validateDescription cleanedDescription
        }
  Submit -> do
    state <- H.get
    let
      dateError =
        if String.trim state.activityDate == "" then Just "日期不能為空"
        else Nothing
      descriptionError = validateDescription state.description
    H.modify_
      _
        { dateError = dateError
        , descriptionError = descriptionError
        }
    when (dateError == Nothing && descriptionError == Nothing)
      $ H.raise
      $ SaveDailyActivity
          { activityDate: state.activityDate
          , description: String.trim state.description
          }

validateDescription :: String -> Maybe String
validateDescription description
  | String.trim description == "" = Just "當日主要活動不能為空"
  | CodeUnits.length description > 120 = Just "當日主要活動不能超過 120 個字"
  | otherwise = Nothing
