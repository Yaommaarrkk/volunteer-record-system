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
import Domain.Volunteer (Volunteer)
import Effect.Aff (Aff, delay)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Router.Route (MasterDataType(..))
import Simple.JSON (readJSON, writeJSON)
import Type.Proxy (Proxy(..))
import Widget.StudentForm as StudentForm
import Widget.StudentList as StudentList

type Slot id = forall query. H.Slot query Output id

_studentForm = Proxy :: Proxy "studentFormSlot"

_studentList = Proxy :: Proxy "studentListSlot"

type Slots
  = ( studentFormSlot :: StudentForm.Slot Unit
    , studentListSlot :: StudentList.Slot Unit
    )

type Input = MasterDataType

type State =
  { masterDataType :: MasterDataType
  , volunteers :: Array Volunteer
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
  | Receive Input
  | VolunteersLoaded (Either String (Array Volunteer))
  | StudentFormOutput StudentForm.Output
  | StudentListOutput StudentList.Output
  | HideNotice Int

data Output = OutputUnit

initialState :: Input -> State
initialState masterDataType =
  { masterDataType
  , volunteers: []
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
  Activities ->
    HH.main
      [ HP.class_ (HH.ClassName "master-data-page") ]
      [ HH.h1_ [ HH.text "修改活動資料" ] ]

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
    result <- H.liftAff loadVolunteers
    handleAction (VolunteersLoaded result)
  Receive masterDataType ->
    H.modify_ _ { masterDataType = masterDataType }
  VolunteersLoaded result -> case result of
    Left message ->
      H.modify_ _ { isLoading = false, loadError = Just message }
    Right volunteers ->
      H.modify_ _ { volunteers = volunteers, isLoading = false, loadError = Nothing }
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

loadVolunteers :: Aff (Either String (Array Volunteer))
loadVolunteers = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/volunteers"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("學生資料格式錯誤：" <> show errors)
      Right (decoded :: VolunteersResponse) -> Right decoded.data

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
