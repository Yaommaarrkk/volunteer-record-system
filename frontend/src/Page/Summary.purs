module Page.Summary where

import Prelude

import Affjax.ResponseFormat as ResponseFormat
import Affjax.Web as AX
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Domain.VolunteerHourSummary (VolunteerHourSummary)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Simple.JSON (readJSON)
import Type.Proxy (Proxy(..))
import Widget.VolunteerHourSummary as VolunteerHourSummary

type Slot id = forall query. H.Slot query Output id

_volunteerHourSummary = Proxy :: Proxy "volunteerHourSummarySlot"

type Slots =
  ( volunteerHourSummarySlot :: VolunteerHourSummary.Slot Unit
  )

type Input = Unit

type State =
  { summaries :: Array VolunteerHourSummary
  , isLoading :: Boolean
  , loadError :: Maybe String
  }

type SummaryResponse =
  { success :: Boolean
  , message :: String
  , data :: Array VolunteerHourSummary
  }

data Action
  = Initialize
  | SummariesLoaded (Either String (Array VolunteerHourSummary))
  | SummaryOutput VolunteerHourSummary.Output

data Output = OutputUnit

initialState :: State
initialState =
  { summaries: []
  , isLoading: true
  , loadError: Nothing
  }

component :: forall query m. MonadAff m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState: \_ -> initialState
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { initialize = Just Initialize
            , handleAction = handleAction
            }
    }

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render state =
  HH.main
    [ HP.class_ (HH.ClassName "master-data-page summary-page") ]
    [ HH.header
        [ HP.class_ (HH.ClassName "master-data-header") ]
        [ HH.div_
            [ HH.p [ HP.class_ (HH.ClassName "page-eyebrow") ] [ HH.text "DATABASE OVERVIEW" ]
            , HH.h1_ [ HH.text "查看資料庫" ]
            ]
        ]
    , HH.slot
        _volunteerHourSummary
        unit
        VolunteerHourSummary.component
        { summaries: state.summaries
        , isLoading: state.isLoading
        , loadError: state.loadError
        }
        SummaryOutput
    ]

handleAction
  :: forall m
   . MonadAff m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> loadSummaries
  SummaryOutput VolunteerHourSummary.RetryRequested -> loadSummaries
  SummariesLoaded result -> case result of
    Left message -> H.modify_ _ { isLoading = false, loadError = Just message }
    Right summaries ->
      H.modify_ _ { summaries = summaries, isLoading = false, loadError = Nothing }

loadSummaries
  :: forall m
   . MonadAff m
  => H.HalogenM State Action Slots Output m Unit
loadSummaries = do
  H.modify_ _ { isLoading = true, loadError = Nothing }
  result <- H.liftAff requestSummaries
  handleAction (SummariesLoaded result)

requestSummaries :: Aff (Either String (Array VolunteerHourSummary))
requestSummaries = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/summary/volunteer-hours"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("統計資料格式錯誤：" <> show errors)
      Right (decoded :: SummaryResponse) ->
        if decoded.success then Right decoded.data
        else Left decoded.message
