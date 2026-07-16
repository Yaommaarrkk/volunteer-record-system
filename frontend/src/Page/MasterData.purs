module Page.MasterData where

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
import Domain.Volunteer (Seat, SeatPeriod, Volunteer, seatPeriodToApi)
import Effect.Aff (Aff, delay)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Router.Route (MasterDataType(..))
import Simple.JSON (readJSON, writeJSON)
import Type.Proxy (Proxy(..))
import Widget.ActivityForm as ActivityForm
import Widget.ActivityList as ActivityList
import Widget.StudentForm as StudentForm
import Widget.StudentList as StudentList

type Slot id = forall query. H.Slot query Output id

_studentForm = Proxy :: Proxy "studentFormSlot"

_studentList = Proxy :: Proxy "studentListSlot"

_activityForm = Proxy :: Proxy "activityFormSlot"

_activityList = Proxy :: Proxy "activityListSlot"

type Slots
  = ( studentFormSlot :: StudentForm.Slot Unit
    , studentListSlot :: StudentList.Slot Unit
    , activityFormSlot :: ActivityForm.Slot Unit
    , activityListSlot :: ActivityList.Slot Unit
    )

type Input = MasterDataType

type State =
  { masterDataType :: MasterDataType
  , volunteers :: Array Volunteer
  , activities :: Array Activity
  , isLoading :: Boolean
  , loadError :: Maybe String
  , isSubmitting :: Boolean
  , notice :: Maybe Notice
  , noticeVersion :: Int
  }

type VolunteersResponse =
  { success :: Boolean
  , message :: String
  , data :: Array Volunteer
  }

type ActivitiesResponse =
  { success :: Boolean
  , message :: String
  , data :: Array Activity
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
  | LoadCurrentData
  | Receive Input
  | VolunteersLoaded (Either String (Array Volunteer))
  | ActivitiesLoaded (Either String (Array Activity))
  | StudentFormOutput StudentForm.Output
  | StudentListOutput StudentList.Output
  | ActivityFormOutput ActivityForm.Output
  | ActivityListOutput ActivityList.Output
  | HideNotice Int

data Output = OutputUnit

initialState :: Input -> State
initialState masterDataType =
  { masterDataType
  , volunteers: []
  , activities: []
  , isLoading: true
  , loadError: Nothing
  , isSubmitting: false
  , notice: Nothing
  , noticeVersion: 0
  }

component :: forall query m. MonadAff m => H.Component query Input Output m
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

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render state = case state.masterDataType of
  Students -> renderStudents state
  Activities -> renderActivities state

renderStudents :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
renderStudents state =
  HH.main
    [ HP.class_ (HH.ClassName "master-data-page") ]
    [ renderNotice state.notice
    , HH.header
        [ HP.class_ (HH.ClassName "master-data-header") ]
        [ HH.div_
            [ HH.p [ HP.class_ (HH.ClassName "page-eyebrow") ] [ HH.text "STUDENT MANAGEMENT" ]
            , HH.h1_ [ HH.text "修改學生資料" ]
            , HH.p [ HP.class_ (HH.ClassName "page-description") ]
                [ HH.text "建立學生基本資料與座位，並查看目前資料庫內的所有學生。" ]
            ]
        ]
    , HH.slot
        _studentForm
        unit
        StudentForm.component
        { isSubmitting: state.isSubmitting }
        StudentFormOutput
    , HH.slot
        _studentList
        unit
        StudentList.component
        { volunteers: state.volunteers
        , isLoading: state.isLoading
        , loadError: state.loadError
        }
        StudentListOutput
    ]

renderActivities :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
renderActivities state =
  HH.main
    [ HP.class_ (HH.ClassName "master-data-page") ]
    [ renderNotice state.notice
    , HH.header
        [ HP.class_ (HH.ClassName "master-data-header") ]
        [ HH.div_
            [ HH.p [ HP.class_ (HH.ClassName "page-eyebrow") ] [ HH.text "ACTIVITY MANAGEMENT" ]
            , HH.h1_ [ HH.text "修改活動資料" ]
            ]
        ]
    , HH.slot
        _activityForm
        unit
        ActivityForm.component
        { isSubmitting: state.isSubmitting }
        ActivityFormOutput
    , HH.slot
        _activityList
        unit
        ActivityList.component
        { activities: state.activities
        , isLoading: state.isLoading
        , loadError: state.loadError
        }
        ActivityListOutput
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
  Initialize -> handleAction LoadCurrentData
  LoadCurrentData -> do
    state <- H.get
    case state.masterDataType of
      Students -> do
        result <- H.liftAff loadVolunteers
        handleAction (VolunteersLoaded result)
      Activities -> do
        result <- H.liftAff loadActivities
        handleAction (ActivitiesLoaded result)
  Receive masterDataType -> do
    state <- H.get
    when (state.masterDataType /= masterDataType) do
      H.modify_
        _
          { masterDataType = masterDataType
          , isLoading = true
          , loadError = Nothing
          , notice = Nothing
          }
      handleAction LoadCurrentData
  VolunteersLoaded result -> case result of
    Left message ->
      H.modify_ _ { isLoading = false, loadError = Just message }
    Right volunteers ->
      H.modify_ _ { volunteers = volunteers, isLoading = false, loadError = Nothing }
  ActivitiesLoaded result -> case result of
    Left message ->
      H.modify_ _ { isLoading = false, loadError = Just message }
    Right activities ->
      H.modify_ _ { activities = activities, isLoading = false, loadError = Nothing }
  StudentFormOutput (StudentForm.SubmitVolunteer request) -> do
    H.modify_ _ { isSubmitting = true, notice = Nothing }
    result <- H.liftAff
      $ sequential
      $ (\postResult _ -> postResult)
          <$> parallel (createVolunteer request)
          <*> parallel (delay (Milliseconds 1000.0))
    case result of
      Left message -> do
        H.modify_ _ { isSubmitting = false }
        showNotice ErrorNotice message
      Right message -> do
        H.modify_
          _
            { isSubmitting = false
            , isLoading = true
            , loadError = Nothing
            }
        showNotice SuccessNotice message
        volunteersResult <- H.liftAff loadVolunteers
        handleAction (VolunteersLoaded volunteersResult)
  StudentListOutput StudentList.RetryRequested -> do
    H.modify_ _ { isLoading = true, loadError = Nothing }
    result <- H.liftAff loadVolunteers
    handleAction (VolunteersLoaded result)
  StudentListOutput (StudentList.DeleteRequested id) -> do
    H.modify_ _ { isLoading = true, loadError = Nothing }
    result <- H.liftAff (deleteVolunteer id)
    case result of
      Left message -> do
        H.modify_ _ { isLoading = false }
        showNotice ErrorNotice message
      Right message -> do
        showNotice SuccessNotice message
        volunteersResult <- H.liftAff loadVolunteers
        handleAction (VolunteersLoaded volunteersResult)
  StudentListOutput (StudentList.UpdateNameRequested id name) ->
    handleStudentUpdate (updateVolunteerName id name)
  StudentListOutput (StudentList.UpdateAgeRequested id age) ->
    handleStudentUpdate (updateVolunteerAge id age)
  StudentListOutput (StudentList.UpdateSeatRequested id period seat) ->
    handleStudentUpdate (updateVolunteerSeat id period seat)
  ActivityFormOutput (ActivityForm.SubmitActivity request) -> do
    H.modify_ _ { isSubmitting = true, notice = Nothing }
    result <- H.liftAff
      $ sequential
      $ (\postResult _ -> postResult)
          <$> parallel (createActivity request)
          <*> parallel (delay (Milliseconds 1000.0))
    case result of
      Left message -> do
        H.modify_ _ { isSubmitting = false }
        showNotice ErrorNotice message
      Right message -> do
        H.modify_
          _
            { isSubmitting = false
            , isLoading = true
            , loadError = Nothing
            }
        showNotice SuccessNotice message
        activitiesResult <- H.liftAff loadActivities
        handleAction (ActivitiesLoaded activitiesResult)
  ActivityListOutput ActivityList.RetryRequested -> do
    H.modify_ _ { isLoading = true, loadError = Nothing }
    result <- H.liftAff loadActivities
    handleAction (ActivitiesLoaded result)
  ActivityListOutput (ActivityList.DeleteRequested id) -> do
    H.modify_ _ { isLoading = true, loadError = Nothing }
    result <- H.liftAff (deleteActivity id)
    case result of
      Left message -> do
        H.modify_ _ { isLoading = false }
        showNotice ErrorNotice message
      Right message -> do
        showNotice SuccessNotice message
        activitiesResult <- H.liftAff loadActivities
        handleAction (ActivitiesLoaded activitiesResult)
  ActivityListOutput (ActivityList.UpdateNameRequested id name) ->
    handleActivityUpdate (updateActivityName id name)
  ActivityListOutput (ActivityList.UpdateTypeRequested id defaultType) ->
    handleActivityUpdate (updateActivityType id defaultType)
  ActivityListOutput (ActivityList.ReorderRequested defaultType activityIds) ->
    handleActivityUpdate (updateActivityOrder defaultType activityIds)
  ActivityListOutput (ActivityList.UpdateColorRequested defaultType tagColor) ->
    handleActivityUpdate (updateActivityColor defaultType tagColor)
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
  H.modify_
    _
      { notice = Just { kind, message }
      , noticeVersion = version
      }
  void $ H.fork do
    H.liftAff (delay (Milliseconds 3000.0))
    handleAction (HideNotice version)

handleStudentUpdate
  :: forall m
   . MonadAff m
  => Aff (Either String String)
  -> H.HalogenM State Action Slots Output m Unit
handleStudentUpdate request = do
  H.modify_ _ { isLoading = true, loadError = Nothing }
  result <- H.liftAff request
  case result of
    Left message -> do
      H.modify_ _ { isLoading = false }
      showNotice ErrorNotice message
    Right message -> do
      showNotice SuccessNotice message
      volunteersResult <- H.liftAff loadVolunteers
      handleAction (VolunteersLoaded volunteersResult)

handleActivityUpdate
  :: forall m
   . MonadAff m
  => Aff (Either String String)
  -> H.HalogenM State Action Slots Output m Unit
handleActivityUpdate request = do
  H.modify_ _ { isLoading = true, loadError = Nothing }
  result <- H.liftAff request
  case result of
    Left message -> do
      H.modify_ _ { isLoading = false }
      showNotice ErrorNotice message
    Right message -> do
      showNotice SuccessNotice message
      activitiesResult <- H.liftAff loadActivities
      handleAction (ActivitiesLoaded activitiesResult)

loadVolunteers :: Aff (Either String (Array Volunteer))
loadVolunteers = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/volunteers"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("學生資料格式錯誤：" <> show errors)
      Right (decoded :: VolunteersResponse) -> Right decoded.data

loadActivities :: Aff (Either String (Array Activity))
loadActivities = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/activities"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("活動資料格式錯誤：" <> show errors)
      Right (decoded :: ActivitiesResponse) -> Right decoded.data

createVolunteer :: StudentForm.CreateVolunteerRequest -> Aff (Either String String)
createVolunteer volunteerRq = case jsonParser (writeJSON volunteerRq) of
  Left error -> pure (Left error)
  Right json -> do
    result <-
      AX.post
        ResponseFormat.string
        "http://127.0.0.1:8080/api/volunteer"
        (Just (RequestBody.json json))
    pure case result of
      Left error -> Left (AX.printError error)
      Right response -> case readJSON response.body of
        Left errors -> Left ("新增學生回應格式錯誤：" <> show errors)
        Right (decoded :: MutationResponse) ->
          if decoded.success then Right decoded.message
          else Left decoded.message

createActivity :: ActivityForm.CreateActivityRequest -> Aff (Either String String)
createActivity activityRequest =
  postMutation "http://127.0.0.1:8080/api/activity" (writeJSON activityRequest) "新增活動"

deleteVolunteer :: Int -> Aff (Either String String)
deleteVolunteer id = do
  result <-
    AX.delete
      ResponseFormat.string
      ("http://127.0.0.1:8080/api/volunteer/" <> show id)
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("刪除學生回應格式錯誤：" <> show errors)
      Right (decoded :: MutationResponse) ->
        if decoded.success then Right decoded.message
        else Left decoded.message

deleteActivity :: Int -> Aff (Either String String)
deleteActivity id = do
  result <-
    AX.delete
      ResponseFormat.string
      ("http://127.0.0.1:8080/api/activity/" <> show id)
  pure (decodeMutationResponse "刪除活動" result)

updateVolunteerName :: Int -> String -> Aff (Either String String)
updateVolunteerName id name =
  patchVolunteer
    ("http://127.0.0.1:8080/api/volunteer/" <> show id <> "/name")
    (writeJSON { name })

updateVolunteerAge :: Int -> Int -> Aff (Either String String)
updateVolunteerAge id age =
  patchVolunteer
    ("http://127.0.0.1:8080/api/volunteer/" <> show id <> "/age")
    (writeJSON { age })

updateVolunteerSeat :: Int -> SeatPeriod -> Maybe Seat -> Aff (Either String String)
updateVolunteerSeat id period seat =
  let
    request = case seat of
      Nothing -> { row: Nothing, col: Nothing }
      Just selectedSeat -> { row: Just selectedSeat.row, col: Just selectedSeat.col }
  in
    patchVolunteer
      ( "http://127.0.0.1:8080/api/volunteer/"
          <> show id
          <> "/seat/"
          <> seatPeriodToApi period
      )
      (writeJSON request)

updateActivityName :: Int -> String -> Aff (Either String String)
updateActivityName id name =
  patchMutation
    ("http://127.0.0.1:8080/api/activity/" <> show id <> "/name")
    (writeJSON { name })
    "修改活動名"

updateActivityType :: Int -> String -> Aff (Either String String)
updateActivityType id defaultType =
  patchMutation
    ("http://127.0.0.1:8080/api/activity/" <> show id <> "/default-type")
    (writeJSON { defaultType })
    "修改活動類型"

updateActivityOrder :: String -> Array Int -> Aff (Either String String)
updateActivityOrder defaultType activityIds =
  putMutation
    "http://127.0.0.1:8080/api/activities/order"
    (writeJSON { defaultType, activityIds })
    "修改活動排序"

updateActivityColor :: String -> String -> Aff (Either String String)
updateActivityColor defaultType tagColor =
  patchMutation
    ("http://127.0.0.1:8080/api/activity-types/" <> defaultType <> "/color")
    (writeJSON { tagColor })
    "修改活動類型顏色"

patchVolunteer :: String -> String -> Aff (Either String String)
patchVolunteer url body = case jsonParser body of
  Left error -> pure (Left error)
  Right json -> do
    result <- AX.patch ResponseFormat.string url (RequestBody.json json)
    pure case result of
      Left error -> Left (AX.printError error)
      Right response -> case readJSON response.body of
        Left errors -> Left ("修改學生回應格式錯誤：" <> show errors)
        Right (decoded :: MutationResponse) ->
          if decoded.success then Right decoded.message
          else Left decoded.message

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

putMutation :: String -> String -> String -> Aff (Either String String)
putMutation url body operation = case jsonParser body of
  Left error -> pure (Left error)
  Right json -> do
    result <- AX.put ResponseFormat.string url (Just (RequestBody.json json))
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
