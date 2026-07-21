module Page.Summary where

import Prelude

import Affjax.ResponseFormat as ResponseFormat
import Affjax.Web as AX
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Domain.DailyHourTotal (DailyHourTotal)
import Domain.VolunteerHourSummary (VolunteerHourSummary)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Simple.JSON (readJSON)
import Type.Proxy (Proxy(..))
import Widget.DailyHourChart as DailyHourChart
import Widget.VolunteerHourSummary as VolunteerHourSummary

type Slot id = forall query. H.Slot query Output id

_volunteerHourSummary = Proxy :: Proxy "volunteerHourSummarySlot"

_dailyHourChart = Proxy :: Proxy "dailyHourChartSlot"

type Slots =
  ( volunteerHourSummarySlot :: VolunteerHourSummary.Slot Unit
  , dailyHourChartSlot :: DailyHourChart.Slot Unit
  )

type Input = Unit

data SummaryView
  = StudentComparison
  | DailyTotal

type State =
  { selectedView :: SummaryView
  , volunteerSummaries :: Array VolunteerHourSummary
  , areVolunteerSummariesLoading :: Boolean
  , volunteerSummariesError :: Maybe String
  , dailyTotals :: Array DailyHourTotal
  , areDailyTotalsLoading :: Boolean
  , dailyTotalsError :: Maybe String
  }

type VolunteerSummaryResponse =
  { success :: Boolean
  , message :: String
  , data :: Array VolunteerHourSummary
  }

type DailyTotalsResponse =
  { success :: Boolean
  , message :: String
  , data :: Array DailyHourTotal
  }

data Action
  = Initialize
  | SelectView String
  | VolunteerSummariesLoaded (Either String (Array VolunteerHourSummary))
  | DailyTotalsLoaded (Either String (Array DailyHourTotal))
  | VolunteerSummaryOutput VolunteerHourSummary.Output
  | DailyHourChartOutput DailyHourChart.Output

data Output = OutputUnit

initialState :: State
initialState =
  { selectedView: StudentComparison
  , volunteerSummaries: []
  , areVolunteerSummariesLoading: true
  , volunteerSummariesError: Nothing
  , dailyTotals: []
  , areDailyTotalsLoading: true
  , dailyTotalsError: Nothing
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
        [ HP.class_ (HH.ClassName "master-data-header summary-page-header") ]
        [ HH.div_
            [ HH.p [ HP.class_ (HH.ClassName "page-eyebrow") ] [ HH.text "DATABASE OVERVIEW" ]
            , HH.h1_ [ HH.text "查看資料庫" ]
            ]
        , HH.label
            [ HP.class_ (HH.ClassName "summary-view-control") ]
            [ HH.span_ [ HH.text "顯示內容" ]
            , HH.select
                [ HP.value (summaryViewValue state.selectedView)
                , HE.onValueChange SelectView
                ]
                [ HH.option [ HP.value "student-comparison" ] [ HH.text "學生時數比較" ]
                , HH.option [ HP.value "daily-total" ] [ HH.text "每日總時數" ]
                ]
            ]
        ]
    , case state.selectedView of
        StudentComparison ->
          HH.slot
            _volunteerHourSummary
            unit
            VolunteerHourSummary.component
            { summaries: state.volunteerSummaries
            , isLoading: state.areVolunteerSummariesLoading
            , loadError: state.volunteerSummariesError
            }
            VolunteerSummaryOutput
        DailyTotal ->
          HH.slot
            _dailyHourChart
            unit
            DailyHourChart.component
            { totals: state.dailyTotals
            , isLoading: state.areDailyTotalsLoading
            , loadError: state.dailyTotalsError
            }
            DailyHourChartOutput
    ]

summaryViewValue :: SummaryView -> String
summaryViewValue = case _ of
  StudentComparison -> "student-comparison"
  DailyTotal -> "daily-total"

handleAction
  :: forall m
   . MonadAff m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> do
    loadVolunteerSummaries
    loadDailyTotals
  SelectView value ->
    H.modify_ _ { selectedView = if value == "daily-total" then DailyTotal else StudentComparison }
  VolunteerSummaryOutput VolunteerHourSummary.RetryRequested -> loadVolunteerSummaries
  DailyHourChartOutput DailyHourChart.RetryRequested -> loadDailyTotals
  VolunteerSummariesLoaded result -> case result of
    Left message ->
      H.modify_
        _
          { areVolunteerSummariesLoading = false
          , volunteerSummariesError = Just message
          }
    Right summaries ->
      H.modify_
        _
          { volunteerSummaries = summaries
          , areVolunteerSummariesLoading = false
          , volunteerSummariesError = Nothing
          }
  DailyTotalsLoaded result -> case result of
    Left message ->
      H.modify_
        _
          { areDailyTotalsLoading = false
          , dailyTotalsError = Just message
          }
    Right totals ->
      H.modify_
        _
          { dailyTotals = totals
          , areDailyTotalsLoading = false
          , dailyTotalsError = Nothing
          }

loadVolunteerSummaries
  :: forall m
   . MonadAff m
  => H.HalogenM State Action Slots Output m Unit
loadVolunteerSummaries = do
  H.modify_
    _
      { areVolunteerSummariesLoading = true
      , volunteerSummariesError = Nothing
      }
  result <- H.liftAff requestVolunteerSummaries
  handleAction (VolunteerSummariesLoaded result)

loadDailyTotals
  :: forall m
   . MonadAff m
  => H.HalogenM State Action Slots Output m Unit
loadDailyTotals = do
  H.modify_
    _
      { areDailyTotalsLoading = true
      , dailyTotalsError = Nothing
      }
  result <- H.liftAff requestDailyTotals
  handleAction (DailyTotalsLoaded result)

requestVolunteerSummaries :: Aff (Either String (Array VolunteerHourSummary))
requestVolunteerSummaries = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/summary/volunteer-hours"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("學生統計資料格式錯誤：" <> show errors)
      Right (decoded :: VolunteerSummaryResponse) ->
        if decoded.success then Right decoded.data
        else Left decoded.message

requestDailyTotals :: Aff (Either String (Array DailyHourTotal))
requestDailyTotals = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/summary/daily-hours"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("每日時數資料格式錯誤：" <> show errors)
      Right (decoded :: DailyTotalsResponse) ->
        if decoded.success then Right decoded.data
        else Left decoded.message
