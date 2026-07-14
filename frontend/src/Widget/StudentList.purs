module Widget.StudentList
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Domain.Volunteer (Volunteer, ageToGradeLabel, showSeat)
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

type State = Input

data Action
  = Receive Input
  | Retry

data Output = RetryRequested

component :: forall query m. H.Component query Input Output m
component =
  H.mkComponent
    { initialState: identity
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
    , renderVolunteerList state
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
   . Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Receive input -> H.put input
  Retry -> H.raise RetryRequested
