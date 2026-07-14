module Page.MasterData where

import Prelude

import Affjax.ResponseFormat as ResponseFormat
import Affjax.Web as AX
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Domain.Volunteer (Volunteer, ageToGradeLabel, showSeat)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Router.Route (MasterDataType(..))
import Simple.JSON (readJSON)

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input = MasterDataType

type State =
  { masterDataType :: MasterDataType
  , volunteers :: Array Volunteer
  , isLoading :: Boolean
  , loadError :: Maybe String
  }

type VolunteersResponse =
  { success :: Boolean
  , message :: String
  , data :: Array Volunteer
  }

data Action
  = Initialize
  | Receive Input
  | VolunteersLoaded (Either String (Array Volunteer))

data Output = OutputUnit

initialState :: Input -> State
initialState masterDataType =
  { masterDataType
  , volunteers: []
  , isLoading: true
  , loadError: Nothing
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
    [ HH.header
        [ HP.class_ (HH.ClassName "master-data-header") ]
        [ HH.div_
            [ HH.p [ HP.class_ (HH.ClassName "page-eyebrow") ] [ HH.text "STUDENT MANAGEMENT" ]
            , HH.h1_ [ HH.text "修改學生資料" ]
            , HH.p [ HP.class_ (HH.ClassName "page-description") ]
                [ HH.text "建立學生基本資料與座位，並查看目前資料庫內的所有學生。" ]
            ]
        , HH.a [ HP.class_ (HH.ClassName "back-link"), HP.href "#/" ] [ HH.text "返回首頁" ]
        ]
    , HH.section
        [ HP.class_ (HH.ClassName "student-form-card") ]
        [ HH.h2_ [ HH.text "學生資料" ]
        , HH.div
            [ HP.class_ (HH.ClassName "student-form-grid") ]
            [ formField "類型"
                ( HH.select_
                    [ HH.option_ [ HH.text "國小" ]
                    , HH.option_ [ HH.text "國中" ]
                    ]
                )
            , formField "姓名"
                ( HH.input
                    [ HP.type_ HP.InputText
                    , HP.placeholder "請輸入學生姓名"
                    ]
                )
            , formField "年齡"
                ( HH.select_
                    (map (\age -> HH.option_ [ HH.text (show age <> " 歲") ]) (Array.range 5 15))
                )
            , HH.div
                [ HP.class_ (HH.ClassName "form-field seat-field") ]
                [ HH.span_ [ HH.text "座位" ]
                , HH.button
                    [ HP.class_ (HH.ClassName "seat-picker-trigger") ]
                    [ HH.text "選擇座位" ]
                , HH.div
                    [ HP.class_ (HH.ClassName "seat-picker") ]
                    [ HH.p_ [ HH.text "選擇座位（5 排 × 4 列）" ]
                    , HH.div
                        [ HP.class_ (HH.ClassName "seat-stage") ]
                        [ HH.span
                            [ HP.class_ (HH.ClassName "seat-stage-button") ]
                            [ HH.text "講台" ]
                        ]
                    , HH.div
                        [ HP.class_ (HH.ClassName "seat-grid") ]
                        ( map
                            (\seat ->
                              HH.button
                                [ HP.class_ (HH.ClassName "seat-button") ]
                                [ HH.text (show seat.row <> "-" <> show seat.col) ]
                            )
                            seats
                        )
                    ]
                ]
            ]
        , HH.button
            [ HP.class_ (HH.ClassName "student-submit") ]
            [ HH.text "新增學生" ]
        ]
    , HH.section
        [ HP.class_ (HH.ClassName "student-list-card") ]
        [ HH.div
            [ HP.class_ (HH.ClassName "list-heading") ]
            [ HH.div_
                [ HH.h2_ [ HH.text "學生清單" ]
                , HH.p_ [ HH.text "資料來源：GET /api/volunteers" ]
                ]
            , HH.span
                [ HP.class_ (HH.ClassName "student-count") ]
                [ HH.text (show (Array.length state.volunteers) <> " 位學生") ]
            ]
        , renderVolunteerList state
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

seats :: Array { row :: Int, col :: Int }
seats = do
  row <- Array.range 1 5
  col <- Array.range 1 4
  pure { row, col }

renderVolunteerList :: forall m. State -> H.ComponentHTML Action Slots m
renderVolunteerList state
  | state.isLoading =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在載入學生資料…" ]
  | Just message <- state.loadError =
      HH.div [ HP.class_ (HH.ClassName "list-status list-error") ] [ HH.text message ]
  | Array.null state.volunteers =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有學生資料。" ]
  | otherwise =
      HH.div
        [ HP.class_ (HH.ClassName "student-table-scroll") ]
        [ HH.table
            [ HP.class_ (HH.ClassName "student-table") ]
            [ HH.thead_
                [ HH.tr_
                    [ HH.th_ [ HH.text "編號" ]
                    , HH.th_ [ HH.text "姓名" ]
                    , HH.th_ [ HH.text "年級" ]
                    , HH.th_ [ HH.text "座位" ]
                    ]
                ]
            , HH.tbody_ (map renderVolunteer state.volunteers)
            ]
        ]

renderVolunteer :: forall m. Volunteer -> H.ComponentHTML Action Slots m
renderVolunteer volunteer =
  HH.tr_
    [ HH.td_ [ HH.text (show volunteer.id) ]
    , HH.td_ [ HH.strong_ [ HH.text volunteer.name ] ]
    , HH.td_ [ HH.text (ageToGradeLabel volunteer.age) ]
    , HH.td_ [ HH.text (showSeat volunteer.seat) ]
    ]

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

loadVolunteers :: Aff (Either String (Array Volunteer))
loadVolunteers = do
  result <- AX.get ResponseFormat.string "http://127.0.0.1:8080/api/volunteers"
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("學生資料格式錯誤：" <> show errors)
      Right (decoded :: VolunteersResponse) -> Right decoded.data
