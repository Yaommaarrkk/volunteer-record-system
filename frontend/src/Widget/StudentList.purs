module Widget.StudentList
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Domain.Volunteer (SeatPeriod(..), Volunteer, ageToGradeLabel, seatForPeriod, showSeat)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { volunteers :: Array Volunteer
  , isLoading :: Boolean
  , loadError :: Maybe String
  }

type State =
  { volunteers :: Array Volunteer
  , isLoading :: Boolean
  , loadError :: Maybe String
  , selectedSeatPeriod :: SeatPeriod
  }

data Action
  = Receive Input
  | Retry
  | Delete Int
  | SelectSeatPeriod SeatPeriod

data Output
  = RetryRequested
  | DeleteRequested Int

component :: forall query m. H.Component query Input Output m
component =
  H.mkComponent
    { initialState: \input ->
        { volunteers: input.volunteers
        , isLoading: input.isLoading
        , loadError: input.loadError
        , selectedSeatPeriod: Year114SecondSemester
        }
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { handleAction = handleAction
            , receive = Just <<< Receive
            }
    }

render :: forall m. State -> H.ComponentHTML Action Slots m
render state =
  HH.section
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
    , HH.div
        [ HP.class_ (HH.ClassName "seat-period-selector") ]
        [ seatPeriodRadio "114下" Year114SecondSemester state.selectedSeatPeriod
        , seatPeriodRadio "115暑假" Year115Summer state.selectedSeatPeriod
        ]
    , renderVolunteerList state
    ]

seatPeriodRadio
  :: forall m
   . String
  -> SeatPeriod
  -> SeatPeriod
  -> H.ComponentHTML Action Slots m
seatPeriodRadio label period selectedPeriod =
  HH.label_
    [ HH.input
        [ HP.type_ HP.InputRadio
        , HP.name "student-seat-period"
        , HP.checked (period == selectedPeriod)
        , HE.onChange \_ -> SelectSeatPeriod period
        ]
    , HH.text label
    ]

renderVolunteerList :: forall m. State -> H.ComponentHTML Action Slots m
renderVolunteerList state
  | state.isLoading =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在載入學生資料…" ]
  | Just message <- state.loadError =
      HH.div
        [ HP.class_ (HH.ClassName "list-status list-error") ]
        [ HH.p_ [ HH.text message ]
        , HH.button
            [ HP.class_ (HH.ClassName "list-retry-button")
            , HE.onClick \_ -> Retry
            ]
            [ HH.text "重新請求" ]
        ]
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
                    , HH.th_ [ HH.text "操作" ]
                    ]
                ]
            , HH.tbody_ (map (renderVolunteer state.selectedSeatPeriod) state.volunteers)
            ]
        ]

renderVolunteer :: forall m. SeatPeriod -> Volunteer -> H.ComponentHTML Action Slots m
renderVolunteer period volunteer =
  HH.tr_
    [ HH.td_ [ HH.text (show volunteer.id) ]
    , HH.td_ [ HH.strong_ [ HH.text volunteer.name ] ]
    , HH.td_ [ HH.text (ageToGradeLabel volunteer.age) ]
    , HH.td_ [ HH.text (showSeat (seatForPeriod period volunteer)) ]
    , HH.td_
        [ HH.button
            [ HP.class_ (HH.ClassName "student-delete-button")
            , HE.onClick \_ -> Delete volunteer.id
            ]
            [ HH.text "刪除" ]
        ]
    ]

handleAction
  :: forall m
   . Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Receive input ->
    H.modify_
      _
        { volunteers = input.volunteers
        , isLoading = input.isLoading
        , loadError = input.loadError
        }
  Retry -> H.raise RetryRequested
  Delete id -> H.raise (DeleteRequested id)
  SelectSeatPeriod period -> H.modify_ _ { selectedSeatPeriod = period }
