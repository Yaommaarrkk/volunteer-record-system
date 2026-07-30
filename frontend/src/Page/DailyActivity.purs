module Page.DailyActivity where

import Prelude

import Affjax.RequestBody as RequestBody
import Affjax.ResponseFormat as ResponseFormat
import Affjax.Web as AX
import Config.Api (apiUrl)
import Data.Array as Array
import Data.Argonaut.Parser (jsonParser)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Time.Duration (Milliseconds(..))
import Domain.DailyActivity (DailyActivity)
import Effect.Aff (Aff, delay)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Simple.JSON (readJSON, writeJSON)
import Type.Proxy (Proxy(..))
import Widget.DailyActivityForm as DailyActivityForm
import Widget.DailyActivityList as DailyActivityList

type Slot id = forall query. H.Slot query Output id

_dailyActivityForm = Proxy :: Proxy "dailyActivityFormSlot"

_dailyActivityList = Proxy :: Proxy "dailyActivityListSlot"

type Slots =
  ( dailyActivityFormSlot :: DailyActivityForm.Slot Unit
  , dailyActivityListSlot :: DailyActivityList.Slot Unit
  )

type Input = Unit

type State =
  { activities :: Array DailyActivity
  , totalActivities :: Int
  , isLoading :: Boolean
  , isLoadingMore :: Boolean
  , hasMoreActivities :: Boolean
  , loadError :: Maybe String
  , isSubmitting :: Boolean
  , successfulSubmitVersion :: Int
  , notice :: Maybe Notice
  , noticeVersion :: Int
  }

type ActivityOverview =
  { activities :: Array DailyActivity
  , totalActivities :: Int
  }

type DailyActivitiesResponse =
  { success :: Boolean
  , message :: String
  , data :: Array DailyActivity
  }

type DailyActivityCountResponse =
  { success :: Boolean
  , message :: String
  , data :: Int
  }

type MutationResponse =
  { success :: Boolean
  , message :: String
  , data :: Maybe String
  }

data NoticeKind
  = SuccessNotice
  | ErrorNotice

type Notice =
  { kind :: NoticeKind
  , message :: String
  }

data Action
  = Initialize
  | ActivitiesLoaded (Either String ActivityOverview)
  | MoreActivitiesLoaded (Either String (Array DailyActivity))
  | DailyActivityFormOutput DailyActivityForm.Output
  | DailyActivityListOutput DailyActivityList.Output
  | HideNotice Int

data Output = OutputUnit

initialState :: State
initialState =
  { activities: []
  , totalActivities: 0
  , isLoading: true
  , isLoadingMore: false
  , hasMoreActivities: true
  , loadError: Nothing
  , isSubmitting: false
  , successfulSubmitVersion: 0
  , notice: Nothing
  , noticeVersion: 0
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
    [ HP.class_ (HH.ClassName "master-data-page daily-activity-page") ]
    [ renderNotice state.notice
    , HH.header
        [ HP.class_ (HH.ClassName "master-data-header daily-activity-header") ]
        [ HH.div_
            [ HH.p [ HP.class_ (HH.ClassName "page-eyebrow") ] [ HH.text "DAILY ACTIVITY" ]
            , HH.h1_ [ HH.text "添加當日活動" ]
            ]
        ]
    , HH.slot
        _dailyActivityForm
        unit
        DailyActivityForm.component
        { isSubmitting: state.isSubmitting
        , successfulSubmitVersion: state.successfulSubmitVersion
        }
        DailyActivityFormOutput
    , HH.slot
        _dailyActivityList
        unit
        DailyActivityList.component
        { activities: state.activities
        , totalActivities: state.totalActivities
        , isLoading: state.isLoading
        , isLoadingMore: state.isLoadingMore
        , hasMore: state.hasMoreActivities
        , loadError: state.loadError
        }
        DailyActivityListOutput
    ]

renderNotice :: forall m. Maybe Notice -> H.ComponentHTML Action Slots m
renderNotice = case _ of
  Nothing -> HH.text ""
  Just notice ->
    HH.div
      [ HP.classes
          [ HH.ClassName "submit-notice"
          , HH.ClassName case notice.kind of
              SuccessNotice -> "submit-notice-success"
              ErrorNotice -> "submit-notice-error"
          ]
      ]
      [ HH.text notice.message ]

handleAction
  :: forall m
   . MonadAff m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> loadActivities
  ActivitiesLoaded result -> case result of
    Left message ->
      H.modify_
        _
          { isLoading = false
          , isLoadingMore = false
          , loadError = Just message
          }
    Right overview ->
      H.modify_
        _
          { activities = overview.activities
          , totalActivities = overview.totalActivities
          , isLoading = false
          , isLoadingMore = false
          , hasMoreActivities =
              Array.length overview.activities < overview.totalActivities
          , loadError = Nothing
          }
  MoreActivitiesLoaded result -> case result of
    Left message -> do
      H.modify_ _ { isLoadingMore = false }
      showNotice ErrorNotice message
    Right moreActivities ->
      H.modify_
        \state ->
          let
            activities = state.activities <> moreActivities
          in
            state
              { activities = activities
              , isLoadingMore = false
              , hasMoreActivities =
                  Array.length activities < state.totalActivities
              }
  DailyActivityFormOutput (DailyActivityForm.SaveDailyActivity request) -> do
    H.modify_ _ { isSubmitting = true, notice = Nothing }
    result <- H.liftAff (saveDailyActivity request)
    case result of
      Left message -> do
        H.modify_ _ { isSubmitting = false }
        showNotice ErrorNotice message
      Right message -> do
        state <- H.get
        H.modify_
          _
            { isSubmitting = false
            , successfulSubmitVersion = state.successfulSubmitVersion + 1
            }
        showNotice SuccessNotice message
        loadActivities
  DailyActivityListOutput (DailyActivityList.DeleteRequested activityDates) -> do
    H.modify_ _ { isLoading = true, loadError = Nothing }
    result <- H.liftAff (deleteDailyActivities activityDates)
    case result of
      Left message -> do
        H.modify_ _ { isLoading = false }
        showNotice ErrorNotice message
      Right message -> do
        showNotice SuccessNotice message
        loadActivities
  DailyActivityListOutput DailyActivityList.LoadMoreRequested -> do
    state <- H.get
    when (state.hasMoreActivities && not state.isLoadingMore) do
      H.modify_ _ { isLoadingMore = true }
      result <-
        H.liftAff
          (requestDailyActivityPage (Array.length state.activities))
      handleAction (MoreActivitiesLoaded result)
  DailyActivityListOutput DailyActivityList.RetryRequested -> loadActivities
  HideNotice version -> do
    state <- H.get
    when (state.noticeVersion == version)
      $ H.modify_ _ { notice = Nothing }

loadActivities
  :: forall m
   . MonadAff m
  => H.HalogenM State Action Slots Output m Unit
loadActivities = do
  H.modify_
    _
      { isLoading = true
      , isLoadingMore = false
      , hasMoreActivities = true
      , loadError = Nothing
      }
  result <- H.liftAff requestDailyActivityOverview
  handleAction (ActivitiesLoaded result)

showNotice
  :: forall m
   . MonadAff m
  => NoticeKind
  -> String
  -> H.HalogenM State Action Slots Output m Unit
showNotice kind message = do
  state <- H.get
  let version = state.noticeVersion + 1
  H.modify_ _ { notice = Just { kind, message }, noticeVersion = version }
  void $ H.fork do
    H.liftAff (delay (Milliseconds 3000.0))
    handleAction (HideNotice version)

dailyActivityPageSize :: Int
dailyActivityPageSize = 20

requestDailyActivityOverview :: Aff (Either String ActivityOverview)
requestDailyActivityOverview = do
  activitiesResult <- requestDailyActivityPage 0
  case activitiesResult of
    Left message -> pure (Left message)
    Right activities -> do
      countResult <- requestDailyActivityCount
      pure case countResult of
        Left message -> Left message
        Right totalActivities -> Right { activities, totalActivities }

requestDailyActivityPage
  :: Int
  -> Aff (Either String (Array DailyActivity))
requestDailyActivityPage offset = do
  result <-
    AX.get
      ResponseFormat.string
      ( apiUrl
          ( "/api/daily-activities?offset="
              <> show offset
              <> "&limit="
              <> show dailyActivityPageSize
          )
      )
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("當日活動格式錯誤：" <> show errors)
      Right (decoded :: DailyActivitiesResponse) ->
        if decoded.success then Right decoded.data
        else Left decoded.message

requestDailyActivityCount :: Aff (Either String Int)
requestDailyActivityCount = do
  result <-
    AX.get
      ResponseFormat.string
      (apiUrl "/api/daily-activities/count")
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("當日活動總筆數格式錯誤：" <> show errors)
      Right (decoded :: DailyActivityCountResponse) ->
        if decoded.success then Right decoded.data
        else Left decoded.message

saveDailyActivity
  :: DailyActivityForm.SaveDailyActivityRequest
  -> Aff (Either String String)
saveDailyActivity request = case jsonParser (writeJSON request) of
  Left error -> pure (Left error)
  Right json -> do
    result <-
      AX.post
        ResponseFormat.string
        (apiUrl "/api/daily-activity")
        (Just (RequestBody.json json))
    pure case result of
      Left error -> Left (AX.printError error)
      Right response -> case readJSON response.body of
        Left errors -> Left ("儲存當日活動回應格式錯誤：" <> show errors)
        Right (decoded :: MutationResponse) ->
          if decoded.success then Right decoded.message
          else Left decoded.message

deleteDailyActivities :: Array String -> Aff (Either String String)
deleteDailyActivities activityDates =
  postMutation
    (apiUrl "/api/daily-activities/delete")
    (writeJSON { activityDates })
    "刪除當日活動"

postMutation :: String -> String -> String -> Aff (Either String String)
postMutation url body operation = case jsonParser body of
  Left error -> pure (Left error)
  Right json -> do
    result <- AX.post ResponseFormat.string url (Just (RequestBody.json json))
    pure case result of
      Left error -> Left (AX.printError error)
      Right response -> case readJSON response.body of
        Left errors -> Left (operation <> "回應格式錯誤：" <> show errors)
        Right (decoded :: MutationResponse) ->
          if decoded.success then Right decoded.message
          else Left decoded.message
