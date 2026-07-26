module Widget.ActivityRanking
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Domain.Activity (activityTypeLabel)
import Domain.ActivityRanking (ActivityRanking, RankedVolunteer)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { rankings :: Array ActivityRanking
  , isLoading :: Boolean
  , loadError :: Maybe String
  }

type State = Input

data Action
  = Receive Input
  | Retry

data Output
  = RetryRequested

component :: forall query m. Monad m => H.Component query Input Output m
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
    [ HP.class_ (HH.ClassName "summary-card activity-ranking-card") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "list-heading") ]
        [ HH.div_
            [ HH.h2_ [ HH.text "活動時數排行" ]
            , HH.p_ [ HH.text "依活動類型與活動單項，列出累積時數最高的五位學生。" ]
            ]
        ]
    , renderContent state
    ]

renderContent :: forall m. State -> H.ComponentHTML Action Slots m
renderContent state
  | state.isLoading =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在讀取活動排行……" ]
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
  | Array.null state.rankings =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有活動時數紀錄。" ]
  | otherwise =
      HH.div
        [ HP.class_ (HH.ClassName "summary-table-scroll") ]
        [ HH.table
            [ HP.class_ (HH.ClassName "summary-table activity-ranking-table") ]
            [ HH.thead_
                [ HH.tr_
                    [ HH.th_ [ HH.text "活動類型" ]
                    , HH.th_ [ HH.text "活動單項" ]
                    , HH.th_ [ HH.text "第 1 名" ]
                    , HH.th_ [ HH.text "第 2 名" ]
                    , HH.th_ [ HH.text "第 3 名" ]
                    , HH.th_ [ HH.text "第 4 名" ]
                    , HH.th_ [ HH.text "第 5 名" ]
                    ]
                ]
            , HH.tbody_ (map renderRanking state.rankings)
            ]
        ]

renderRanking :: forall m. ActivityRanking -> H.ComponentHTML Action Slots m
renderRanking ranking =
  HH.tr_
    ( [ HH.td_
          [ HH.span
              [ HP.class_ (HH.ClassName ("activity-ranking-type activity-ranking-type-" <> ranking.activityType)) ]
              [ HH.text (activityTypeLabel ranking.activityType) ]
          ]
      , HH.td
          [ HP.class_ (HH.ClassName "activity-ranking-name") ]
          [ HH.text ranking.activityName ]
      ]
      <> map (renderRankedVolunteer ranking.topVolunteers) [ 0, 1, 2, 3, 4 ]
    )

renderRankedVolunteer
  :: forall m
   . Array RankedVolunteer
  -> Int
  -> H.ComponentHTML Action Slots m
renderRankedVolunteer volunteers index =
  HH.td
    [ HP.class_ (HH.ClassName "activity-ranking-volunteer") ]
    case Array.index volunteers index of
      Nothing -> []
      Just volunteer ->
        [ HH.span
            [ HP.class_ (HH.ClassName "activity-ranking-volunteer-name") ]
            [ HH.text volunteer.volunteerName ]
        , HH.span
            [ HP.class_ (HH.ClassName "activity-ranking-hours") ]
            [ HH.text (formatHours volunteer.hours <> " 小時") ]
        ]

formatHours :: Number -> String
formatHours value =
  show (Int.toNumber (Int.round (value * 10.0)) / 10.0)

handleAction
  :: forall m
   . Monad m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Receive input -> H.put input
  Retry -> H.raise RetryRequested
