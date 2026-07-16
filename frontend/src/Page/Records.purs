module Page.Records where

import Prelude

import Affjax.RequestBody as RequestBody
import Affjax.ResponseFormat as ResponseFormat
import Affjax.Web as AX
import Control.Parallel (parallel, sequential)
import Data.Argonaut.Parser (jsonParser)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
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

type Slot id = forall query. H.Slot query Output id

_hourRecordForm = Proxy :: Proxy "hourRecordFormSlot"

_hourRecordList = Proxy :: Proxy "hourRecordListSlot"

type Slots
  = ( hourRecordFormSlot :: HourRecordForm.Slot Unit
    , hourRecordListSlot :: HourRecordList.Slot Unit
    )

type Input = Unit

type State =
  { activities :: Array Activity
  , volunteers :: Array Volunteer
  , records :: Array HourRecord
  , defaultYear :: Int
  , isLoading :: Boolean
  , loadError :: Maybe String
  , isSubmitting :: Boolean
  , copiedRecord :: Maybe CopiedHourRecord
  , copyVersion :: Int
  , notice :: Maybe Notice
  , noticeVersion :: Int
  }

type PageData =
  { activities :: Array Activity
  , volunteers :: Array Volunteer
  , records :: Array HourRecord
  , defaultYear :: Int
  }

type ActivitiesResponse =
  { success :: Boolean
  , message :: String
  , data :: Array Activity
  }

type VolunteersResponse =
  { success :: Boolean
  , message :: String
  , data :: Array Volunteer
  }

type HourRecordsResponse =
  { success :: Boolean
  , message :: String
  , data :: Array HourRecord
  }

type DefaultYearResponse =
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
  | RetryLoad
  | PageDataLoaded (Either String PageData)
  | RecordsLoaded (Either String (Array HourRecord))
  | HourRecordFormOutput HourRecordForm.Output
  | HourRecordListOutput HourRecordList.Output
  | HideNotice Int

data Output = OutputUnit

initialState :: State
initialState =
  { activities: []
  , volunteers: []
  , records: []
  , defaultYear: 2026
  , isLoading: true
  , loadError: Nothing
  , isSubmitting: false
  , copiedRecord: Nothing
  , copyVersion: 0
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
        }
        HourRecordFormOutput
    , HH.slot
        _hourRecordList
        unit
        HourRecordList.component
        { records: state.records
        , isLoading: state.isLoading
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

handleAction
  :: forall m
   . MonadAff m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize -> do
    result <- H.liftAff loadPageData
    handleAction (PageDataLoaded result)
  RetryLoad -> do
    H.modify_ _ { isLoading = true, loadError = Nothing }
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
          , defaultYear = pageData.defaultYear
          , isLoading = false
          , loadError = Nothing
          }
  RecordsLoaded result -> case result of
    Left message -> H.modify_ _ { isLoading = false, loadError = Just message }
    Right records -> H.modify_ _ { records = records, isLoading = false, loadError = Nothing }
  HourRecordFormOutput (HourRecordForm.SubmitHourRecord request) -> do
    H.modify_ _ { isSubmitting = true, notice = Nothing }
    result <- H.liftAff
      $ sequential
      $ (\postResult _ -> postResult)
          <$> parallel (createHourRecord request)
          <*> parallel (delay (Milliseconds 1000.0))
    case result of
      Left message -> do
        H.modify_ _ { isSubmitting = false }
        showNotice ErrorNotice message
      Right message -> do
        H.modify_ _ { isSubmitting = false, isLoading = true, loadError = Nothing }
        showNotice SuccessNotice message
        recordsResult <- H.liftAff loadHourRecords
        handleAction (RecordsLoaded recordsResult)
  HourRecordFormOutput (HourRecordForm.UpdateDefaultYear year) -> do
    state <- H.get
    let oldYear = state.defaultYear
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
        recordsResult <- H.liftAff loadHourRecords
        handleAction (RecordsLoaded recordsResult)
  HourRecordListOutput (HourRecordList.CopyRequested copiedRecord) -> do
    state <- H.get
    H.modify_
      _
        { copiedRecord = Just copiedRecord
        , copyVersion = state.copyVersion + 1
        }
    showNotice SuccessNotice "已複製到上方輸入區，請重新選擇學生"
  HourRecordListOutput HourRecordList.RetryRequested -> handleAction RetryLoad
  HideNotice version -> do
    state <- H.get
    when (state.noticeVersion == version)
      $ H.modify_ _ { notice = Nothing }

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
              recordsResult <- loadHourRecords
              pure case recordsResult of
                Left message -> Left message
                Right records -> Right { activities, volunteers, records, defaultYear }

loadActivities :: Aff (Either String (Array Activity))
loadActivities = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/activities"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("活動資料格式錯誤：" <> show errors)
      Right (decoded :: ActivitiesResponse) -> Right decoded.data

loadVolunteers :: Aff (Either String (Array Volunteer))
loadVolunteers = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/volunteers"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("學生資料格式錯誤：" <> show errors)
      Right (decoded :: VolunteersResponse) -> Right decoded.data

loadDefaultYear :: Aff (Either String Int)
loadDefaultYear = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/record-settings/default-year"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("預設年份格式錯誤：" <> show errors)
      Right (decoded :: DefaultYearResponse) -> Right decoded.data

loadHourRecords :: Aff (Either String (Array HourRecord))
loadHourRecords = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/hour-records"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("時數紀錄格式錯誤：" <> show errors)
      Right (decoded :: HourRecordsResponse) -> Right decoded.data

createHourRecord :: HourRecordForm.CreateHourRecordRequest -> Aff (Either String String)
createHourRecord request =
  postMutation "http://127.0.0.1:8080/api/hour-record" (writeJSON request) "新增時數紀錄"

updateDefaultYear :: Int -> Aff (Either String String)
updateDefaultYear year =
  patchMutation
    "http://127.0.0.1:8080/api/record-settings/default-year"
    (writeJSON { year })
    "修改預設年份"

deleteHourRecords :: Array Int -> Aff (Either String String)
deleteHourRecords ids =
  postMutation
    "http://127.0.0.1:8080/api/hour-records/delete"
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

decodeMutationResponse
  :: String
  -> Either AX.Error (AX.Response String)
  -> Either String String
decodeMutationResponse operation = case _ of
  Left error -> Left (AX.printError error)
  Right response -> case readJSON response.body of
    Left errors -> Left (operation <> "回應格式錯誤：" <> show errors)
    Right (decoded :: MutationResponse) ->
      if decoded.success then Right decoded.message
      else Left decoded.message
