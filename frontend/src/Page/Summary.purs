module Page.Summary where

import Prelude

import Affjax.ResponseFormat as ResponseFormat
import Affjax.Web as AX
import Config.Api (apiUrl)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Domain.ActivityRanking (ActivityRanking)
import Domain.DailyHourTotal (DailyHourTotal)
import Domain.VolunteerHourSummary (VolunteerHourSummary)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Simple.JSON (readJSON)
import Type.Proxy (Proxy(..))
import Widget.ActivityRanking as ActivityRanking
import Widget.DailyHourChart as DailyHourChart
import Widget.VolunteerHourSummary as VolunteerHourSummary

foreign import loadSelectedSummaryView :: Effect String
foreign import saveSelectedSummaryView :: String -> Effect Unit

type Slot id = forall query. H.Slot query Output id

_volunteerHourSummary = Proxy :: Proxy "volunteerHourSummarySlot"

_dailyHourChart = Proxy :: Proxy "dailyHourChartSlot"

_activityRanking = Proxy :: Proxy "activityRankingSlot"

type Slots =
  ( volunteerHourSummarySlot :: VolunteerHourSummary.Slot Unit
  , dailyHourChartSlot :: DailyHourChart.Slot Unit
  , activityRankingSlot :: ActivityRanking.Slot Unit
  )

type Input = Unit

data SummaryView
  = StudentComparison
  | DailyTotal
  | ActivityRankingView

type State =
  { selectedView :: SummaryView
  , volunteerSummaries :: Array VolunteerHourSummary
  , areVolunteerSummariesLoading :: Boolean
  , volunteerSummariesError :: Maybe String
  , dailyTotals :: Array DailyHourTotal
  , areDailyTotalsLoading :: Boolean
  , dailyTotalsError :: Maybe String
  , activityRankings :: Array ActivityRanking
  , areActivityRankingsLoading :: Boolean
  , activityRankingsError :: Maybe String
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

type ActivityRankingsResponse =
  { success :: Boolean
  , message :: String
  , data :: Array ActivityRanking
  }

data Action
  = Initialize
  | SelectView String
  | VolunteerSummariesLoaded (Either String (Array VolunteerHourSummary))
  | DailyTotalsLoaded (Either String (Array DailyHourTotal))
  | ActivityRankingsLoaded (Either String (Array ActivityRanking))
  | VolunteerSummaryOutput VolunteerHourSummary.Output
  | DailyHourChartOutput DailyHourChart.Output
  | ActivityRankingOutput ActivityRanking.Output

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
  , activityRankings: []
  , areActivityRankingsLoading: true
  , activityRankingsError: Nothing
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
                , HH.option [ HP.value "activity-ranking" ] [ HH.text "活動時數排行" ]
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
        ActivityRankingView ->
          HH.slot
            _activityRanking
            unit
            ActivityRanking.component
            { rankings: state.activityRankings
            , isLoading: state.areActivityRankingsLoading
            , loadError: state.activityRankingsError
            }
            ActivityRankingOutput
    ]

summaryViewValue :: SummaryView -> String
summaryViewValue = case _ of
  StudentComparison -> "student-comparison"
  DailyTotal -> "daily-total"
  ActivityRankingView -> "activity-ranking"

summaryViewFromValue :: String -> SummaryView
summaryViewFromValue = case _ of
  "daily-total" -> DailyTotal
  "activity-ranking" -> ActivityRankingView
  _ -> StudentComparison

handleAction
  :: forall m
   . MonadAff m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> do
    storedView <- H.liftEffect loadSelectedSummaryView
    H.modify_ _ { selectedView = summaryViewFromValue storedView }
    loadVolunteerSummaries
    loadDailyTotals
    loadActivityRankings
  SelectView value -> do
    H.modify_
      _
        { selectedView = summaryViewFromValue value }
    H.liftEffect (saveSelectedSummaryView value)
  VolunteerSummaryOutput VolunteerHourSummary.RetryRequested -> loadVolunteerSummaries
  DailyHourChartOutput DailyHourChart.RetryRequested -> loadDailyTotals
  ActivityRankingOutput ActivityRanking.RetryRequested -> loadActivityRankings
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
  ActivityRankingsLoaded result -> case result of
    Left message ->
      H.modify_
        _
          { areActivityRankingsLoading = false
          , activityRankingsError = Just message
          }
    Right rankings ->
      H.modify_
        _
          { activityRankings = rankings
          , areActivityRankingsLoading = false
          , activityRankingsError = Nothing
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

loadActivityRankings
  :: forall m
   . MonadAff m
  => H.HalogenM State Action Slots Output m Unit
loadActivityRankings = do
  H.modify_
    _
      { areActivityRankingsLoading = true
      , activityRankingsError = Nothing
      }
  result <- H.liftAff requestActivityRankings
  handleAction (ActivityRankingsLoaded result)

requestVolunteerSummaries :: Aff (Either String (Array VolunteerHourSummary))
requestVolunteerSummaries = do
  result <- AX.get ResponseFormat.string (apiUrl "/api/summary/volunteer-hours")
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("學生統計資料格式錯誤：" <> show errors)
      Right (decoded :: VolunteerSummaryResponse) ->
        if decoded.success then Right decoded.data
        else Left decoded.message

requestDailyTotals :: Aff (Either String (Array DailyHourTotal))
requestDailyTotals = do
  result <- AX.get ResponseFormat.string (apiUrl "/api/summary/daily-hours")
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("每日時數資料格式錯誤：" <> show errors)
      Right (decoded :: DailyTotalsResponse) ->
        if decoded.success then Right decoded.data
        else Left decoded.message

requestActivityRankings :: Aff (Either String (Array ActivityRanking))
requestActivityRankings = do
  result <- AX.get ResponseFormat.string (apiUrl "/api/summary/activity-rankings")
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("活動排行資料格式錯誤：" <> show errors)
      Right (decoded :: ActivityRankingsResponse) ->
        if decoded.success then Right decoded.data
        else Left decoded.message
