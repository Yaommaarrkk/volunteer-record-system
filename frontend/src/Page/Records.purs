module Page.Records where

import Prelude
import Affjax.RequestBody as RequestBody
import Affjax.ResponseFormat as ResponseFormat
import Affjax.Web as AX
import Config.Api (apiUrl)
import Control.Parallel (parallel, sequential)
import Data.Array as Array
import Data.Argonaut.Parser (jsonParser)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String.Common as String
import Data.Time.Duration (Milliseconds(..))
import Domain.Activity (Activity)
import Domain.HourRecord (CopiedHourRecord, HourRecord)
import Domain.Volunteer (Volunteer)
import Effect.Aff (Aff, delay)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Simple.JSON (readJSON, writeJSON)
import Type.Proxy (Proxy(..))
import Widget.HourRecordForm as HourRecordForm
import Widget.HourRecordList as HourRecordList

type Slot id
  = forall query. H.Slot query Output id

_hourRecordForm = Proxy :: Proxy "hourRecordFormSlot"

_hourRecordList = Proxy :: Proxy "hourRecordListSlot"

type Slots
  = ( hourRecordFormSlot :: HourRecordForm.Slot Unit
    , hourRecordListSlot :: HourRecordList.Slot Unit
    )

type Input
  = Unit

type State
  = { activities :: Array Activity
    , volunteers :: Array Volunteer
    , records :: Array HourRecord
    , historyVolunteerIds :: Array Int
    , historyActivityIds :: Array Int
    , totalRecords :: Int
    , defaultYear :: Int
    , isLoading :: Boolean
    , isLoadingMore :: Boolean
    , hasMoreRecords :: Boolean
    , loadError :: Maybe String
    , isSubmitting :: Boolean
    , copiedRecord :: Maybe CopiedHourRecord
    , copyVersion :: Int
    , successfulSubmitVersion :: Int
    , notice :: Maybe Notice
    , noticeVersion :: Int
    }

type PageData
  = { activities :: Array Activity
    , volunteers :: Array Volunteer
    , records :: Array HourRecord
    , totalRecords :: Int
    , defaultYear :: Int
    }

type RecordOverview
  = { records :: Array HourRecord
    , totalRecords :: Int
    }

type ActivitiesResponse
  = { success :: Boolean
    , message :: String
    , data :: Array Activity
    }

type VolunteersResponse
  = { success :: Boolean
    , message :: String
    , data :: Array Volunteer
    }

type HourRecordsResponse
  = { success :: Boolean
    , message :: String
    , data :: Array HourRecord
    }

type HourRecordCountResponse
  = { success :: Boolean
    , message :: String
    , data :: Int
    }

type DefaultYearResponse
  = { success :: Boolean
    , message :: String
    , data :: Int
    }

type MutationResponse
  = { success :: Boolean
    , message :: String
    , data :: Maybe String
    }

data NoticeKind
  = SuccessNotice
  | ErrorNotice

type Notice
  = { kind :: NoticeKind
    , message :: String
    }

data Action
  = Initialize
  | RetryLoad
  | PageDataLoaded (Either String PageData)
  | RecordsLoaded (Either String RecordOverview)
  | MoreRecordsLoaded (Either String (Array HourRecord))
  | HourRecordFormOutput HourRecordForm.Output
  | HourRecordListOutput HourRecordList.Output
  | HideNotice Int

data Output
  = OutputUnit

initialState :: State
initialState =
  { activities: []
  , volunteers: []
  , records: []
  , historyVolunteerIds: []
  , historyActivityIds: []
  , totalRecords: 0
  , defaultYear: 2026
  , isLoading: true
  , isLoadingMore: false
  , hasMoreRecords: true
  , loadError: Nothing
  , isSubmitting: false
  , copiedRecord: Nothing
  , copyVersion: 0
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
    [ HP.class_ (HH.ClassName "master-data-page hour-record-page") ]
    [ renderNotice state.notice
    , HH.header
        [ HP.class_ (HH.ClassName "master-data-header") ]
        [ HH.div_
            [ HH.p [ HP.class_ (HH.ClassName "page-eyebrow") ] [ HH.text "HOUR RECORDS" ]
            , HH.h1_ [ HH.text "時數條登錄系統" ]
            ]
        ]
    , HH.slot
        _hourRecordForm
        unit
        HourRecordForm.component
        { activities: state.activities
        , volunteers: state.volunteers
        , defaultYear: state.defaultYear
        , isSubmitting: state.isSubmitting
        , copiedRecord: state.copiedRecord
        , copyVersion: state.copyVersion
        , successfulSubmitVersion: state.successfulSubmitVersion
        }
        HourRecordFormOutput
    , HH.slot
        _hourRecordList
        unit
        HourRecordList.component
        { activities: state.activities
        , records: state.records
        , volunteers: state.volunteers
        , filterVolunteerIds: state.historyVolunteerIds
        , filterActivityIds: state.historyActivityIds
        , totalRecords: state.totalRecords
        , isLoading: state.isLoading
        , isLoadingMore: state.isLoadingMore
        , hasMore: state.hasMoreRecords
        , loadError: state.loadError
        }
        HourRecordListOutput
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

handleAction ::
  forall m.
  MonadAff m =>
  Action ->
  H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> do
    result <- H.liftAff loadPageData
    handleAction (PageDataLoaded result)
  RetryLoad -> do
    H.modify_
      _
        { isLoading = true
        , isLoadingMore = false
        , hasMoreRecords = true
        , loadError = Nothing
        }
    result <- H.liftAff loadPageData
    handleAction (PageDataLoaded result)
  PageDataLoaded result -> case result of
    Left message -> H.modify_ _ { isLoading = false, loadError = Just message }
    Right pageData ->
      H.modify_
        _
          { activities = pageData.activities
          , volunteers = pageData.volunteers
          , records = pageData.records
          , totalRecords = pageData.totalRecords
          , defaultYear = pageData.defaultYear
          , isLoading = false
          , isLoadingMore = false
          , hasMoreRecords = Array.length pageData.records < pageData.totalRecords
          , loadError = Nothing
          }
  RecordsLoaded result -> case result of
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
          { records = overview.records
          , totalRecords = overview.totalRecords
          , isLoading = false
          , isLoadingMore = false
          , hasMoreRecords = Array.length overview.records < overview.totalRecords
          , loadError = Nothing
          }
  MoreRecordsLoaded result -> case result of
    Left message -> do
      H.modify_ _ { isLoadingMore = false }
      showNotice ErrorNotice message
    Right moreRecords ->
      H.modify_ \state ->
        let
          records = state.records <> moreRecords
        in
          state
            { records = records
            , isLoadingMore = false
            , hasMoreRecords = Array.length records < state.totalRecords
            }
  HourRecordFormOutput (HourRecordForm.SubmitHourRecord request) -> do
    H.modify_ _ { isSubmitting = true, notice = Nothing }
    result <-
      H.liftAff
        $ sequential
        $ (\postResult _ -> postResult)
        <$> parallel (createHourRecord request)
        <*> parallel (delay (Milliseconds 1000.0))
    case result of
      Left message -> do
        H.modify_ _ { isSubmitting = false }
        showNotice ErrorNotice message
      Right message -> do
        state <- H.get
        H.modify_
          _
            { isSubmitting = false
            , isLoading = true
            , loadError = Nothing
            , successfulSubmitVersion = state.successfulSubmitVersion + 1
            }
        showNotice SuccessNotice message
        recordsResult <- H.liftAff (loadRecordOverview state.historyVolunteerIds state.historyActivityIds)
        handleAction (RecordsLoaded recordsResult)
  HourRecordFormOutput (HourRecordForm.UpdateDefaultYear year) -> do
    state <- H.get
    let
      oldYear = state.defaultYear
    H.modify_ _ { defaultYear = year }
    result <- H.liftAff (updateDefaultYear year)
    case result of
      Left message -> do
        H.modify_ _ { defaultYear = oldYear }
        showNotice ErrorNotice message
      Right message -> showNotice SuccessNotice message
  HourRecordListOutput (HourRecordList.DeleteRequested ids) -> do
    H.modify_ _ { isLoading = true, loadError = Nothing }
    result <- H.liftAff (deleteHourRecords ids)
    case result of
      Left message -> do
        H.modify_ _ { isLoading = false }
        showNotice ErrorNotice message
      Right message -> do
        showNotice SuccessNotice message
        state <- H.get
        recordsResult <- H.liftAff (loadRecordOverview state.historyVolunteerIds state.historyActivityIds)
        handleAction (RecordsLoaded recordsResult)
  HourRecordListOutput (HourRecordList.CopyRequested copiedRecord) -> do
    state <- H.get
    H.modify_
      _
        { copiedRecord = Just copiedRecord
        , copyVersion = state.copyVersion + 1
        }
    showNotice SuccessNotice "已複製到上方輸入區"
  HourRecordListOutput (HourRecordList.VolunteerFilterChanged volunteerIds) -> do
    H.modify_
      _
        { historyVolunteerIds = volunteerIds
        , isLoading = true
        , isLoadingMore = false
        , hasMoreRecords = true
        , loadError = Nothing
        }
    historyActivityIds <- H.gets _.historyActivityIds
    result <- H.liftAff (loadRecordOverview volunteerIds historyActivityIds)
    handleAction (RecordsLoaded result)
  HourRecordListOutput (HourRecordList.ActivityFilterChanged activityIds) -> do
    H.modify_
      _
        { historyActivityIds = activityIds
        , isLoading = true
        , isLoadingMore = false
        , hasMoreRecords = true
        , loadError = Nothing
        }
    historyVolunteerIds <- H.gets _.historyVolunteerIds
    result <- H.liftAff (loadRecordOverview historyVolunteerIds activityIds)
    handleAction (RecordsLoaded result)
  HourRecordListOutput HourRecordList.LoadMoreRequested -> do
    state <- H.get
    when (state.hasMoreRecords && not state.isLoadingMore) do
      H.modify_ _ { isLoadingMore = true }
      result <- H.liftAff (loadHourRecordsPage state.historyVolunteerIds state.historyActivityIds (Array.length state.records))
      handleAction (MoreRecordsLoaded result)
  HourRecordListOutput HourRecordList.RetryRequested -> handleAction RetryLoad
  HideNotice version -> do
    state <- H.get
    when (state.noticeVersion == version)
      $ H.modify_ _ { notice = Nothing }

showNotice ::
  forall m.
  MonadAff m =>
  NoticeKind ->
  String ->
  H.HalogenM State Action Slots Output m Unit
showNotice kind message = do
  state <- H.get
  let
    version = state.noticeVersion + 1
  H.modify_ _ { notice = Just { kind, message }, noticeVersion = version }
  void
    $ H.fork do
        H.liftAff (delay (Milliseconds 3000.0))
        handleAction (HideNotice version)

loadPageData :: Aff (Either String PageData)
loadPageData = do
  activitiesResult <- loadActivities
  case activitiesResult of
    Left message -> pure (Left message)
    Right activities -> do
      volunteersResult <- loadVolunteers
      case volunteersResult of
        Left message -> pure (Left message)
        Right volunteers -> do
          yearResult <- loadDefaultYear
          case yearResult of
            Left message -> pure (Left message)
            Right defaultYear -> do
              overviewResult <- loadRecordOverview [] []
              pure case overviewResult of
                Left message -> Left message
                Right overview ->
                  Right
                    { activities
                    , volunteers
                    , records: overview.records
                    , totalRecords: overview.totalRecords
                    , defaultYear
                    }

loadActivities :: Aff (Either String (Array Activity))
loadActivities = do
  result <- AX.get ResponseFormat.string (apiUrl "/api/activities")
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("活動資料格式錯誤：" <> show errors)
      Right (decoded :: ActivitiesResponse) -> Right decoded.data

loadVolunteers :: Aff (Either String (Array Volunteer))
loadVolunteers = do
  result <- AX.get ResponseFormat.string (apiUrl "/api/volunteers")
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("學生資料格式錯誤：" <> show errors)
      Right (decoded :: VolunteersResponse) -> Right decoded.data

loadDefaultYear :: Aff (Either String Int)
loadDefaultYear = do
  result <- AX.get ResponseFormat.string (apiUrl "/api/record-settings/default-year")
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("預設年份格式錯誤：" <> show errors)
      Right (decoded :: DefaultYearResponse) -> Right decoded.data

hourRecordPageSize :: Int
hourRecordPageSize = 20

loadHourRecords :: Array Int -> Array Int -> Aff (Either String (Array HourRecord))
loadHourRecords volunteerIds activityIds = loadHourRecordsPage volunteerIds activityIds 0

loadRecordOverview :: Array Int -> Array Int -> Aff (Either String RecordOverview)
loadRecordOverview volunteerIds activityIds = do
  recordsResult <- loadHourRecords volunteerIds activityIds
  case recordsResult of
    Left message -> pure (Left message)
    Right records -> do
      countResult <- loadHourRecordCount volunteerIds activityIds
      pure case countResult of
        Left message -> Left message
        Right totalRecords -> Right { records, totalRecords }

loadHourRecordCount :: Array Int -> Array Int -> Aff (Either String Int)
loadHourRecordCount volunteerIds activityIds = do
  result <- AX.get ResponseFormat.string (apiUrl ("/api/hour-records/count" <> filterQuery volunteerIds activityIds))
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("時數紀錄總筆數格式錯誤：" <> show errors)
      Right (decoded :: HourRecordCountResponse) -> Right decoded.data

loadHourRecordsPage :: Array Int -> Array Int -> Int -> Aff (Either String (Array HourRecord))
loadHourRecordsPage volunteerIds activityIds offset = do
  result <-
    AX.get
      ResponseFormat.string
      ( apiUrl
          ( "/api/hour-records?"
              <> genericFilterParameters "volunteerIds" volunteerIds -- ?volunteerIds=1&volunteerIds=2
              <> genericFilterParameters "activityIds" activityIds
              <> "offset="
              <> show offset
              <> "&limit="
              <> show hourRecordPageSize
          )
      )
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("時數紀錄格式錯誤：" <> show errors)
      Right (decoded :: HourRecordsResponse) -> Right decoded.data

filterQuery :: Array Int -> Array Int -> String
filterQuery volunteerIds activityIds =
  if Array.null volunteerIds && Array.null activityIds then
    ""
  else
    "?"
      <> genericFilterParameters "volunteerIds" volunteerIds
      <> genericFilterParameters "activityIds" activityIds
      <> ""

genericFilterParameters :: String -> Array Int -> String
genericFilterParameters type_str ids =
  if Array.null ids then
    ""
  else
    String.joinWith "" (map (\id -> type_str <> "=" <> show id <> "&") ids)

createHourRecord :: HourRecordForm.CreateHourRecordRequest -> Aff (Either String String)
createHourRecord request = postMutation (apiUrl "/api/hour-record") (writeJSON request) "新增時數紀錄"

updateDefaultYear :: Int -> Aff (Either String String)
updateDefaultYear year =
  patchMutation
    (apiUrl "/api/record-settings/default-year")
    (writeJSON { year })
    "修改預設年份"

deleteHourRecords :: Array Int -> Aff (Either String String)
deleteHourRecords ids =
  postMutation
    (apiUrl "/api/hour-records/delete")
    (writeJSON { ids })
    "刪除時數紀錄"

postMutation :: String -> String -> String -> Aff (Either String String)
postMutation url body operation = case jsonParser body of
  Left error -> pure (Left error)
  Right json -> do
    result <- AX.post ResponseFormat.string url (Just (RequestBody.json json))
    pure (decodeMutationResponse operation result)

patchMutation :: String -> String -> String -> Aff (Either String String)
patchMutation url body operation = case jsonParser body of
  Left error -> pure (Left error)
  Right json -> do
    result <- AX.patch ResponseFormat.string url (RequestBody.json json)
    pure (decodeMutationResponse operation result)

decodeMutationResponse ::
  String ->
  Either AX.Error (AX.Response String) ->
  Either String String
decodeMutationResponse operation = case _ of
  Left error -> Left (AX.printError error)
  Right response -> case readJSON response.body of
    Left errors -> Left (operation <> "回應格式錯誤：" <> show errors)
    Right (decoded :: MutationResponse) ->
      if decoded.success then
        Right decoded.message
      else
        Left decoded.message
