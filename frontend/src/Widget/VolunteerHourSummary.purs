module Widget.VolunteerHourSummary
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..))
import Domain.VolunteerHourSummary (VolunteerHourSummary)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { summaries :: Array VolunteerHourSummary
  , isLoading :: Boolean
  , loadError :: Maybe String
  }

type State = Input

data Action
  = Receive Input
  | Retry

data Output
  = RetryRequested

type Maximums =
  { teaching :: Number
  , virtue :: Number
  , interaction :: Number
  , passive :: Number
  }

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
    [ HP.class_ (HH.ClassName "summary-card") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "list-heading") ]
        [ HH.div_
            [ HH.h2_ [ HH.text "學生時數比較" ]
            , HH.p_ [ HH.text "依 114 下座位排序；各色長條以該欄最高時數為 100%。" ]
            ]
        , HH.span
            [ HP.class_ (HH.ClassName "student-count") ]
            [ HH.text (show (Array.length state.summaries) <> " 位學生") ]
        ]
    , renderContent state
    ]

renderContent :: forall m. State -> H.ComponentHTML Action Slots m
renderContent state
  | state.isLoading =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在讀取統計資料……" ]
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
  | Array.null state.summaries =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有學生資料。" ]
  | otherwise =
      let maximums = findMaximums state.summaries
      in
      HH.div
        [ HP.class_ (HH.ClassName "summary-table-scroll") ]
        [ HH.table
            [ HP.class_ (HH.ClassName "summary-table") ]
            [ HH.thead_
                [ HH.tr_
                    [ HH.th_ [ HH.text "姓名（年級）" ]
                    , explainedHeader "教學" "教學類型的時數，但不包含「品格教育」與「討論」。"
                    , explainedHeader "品德教育" "活動名為「品格教育」、「討論」或「深聊」的時數總和。"
                    , explainedHeader "互動" "陪讀、玩樂、日常互動三種類型的時數總和。"
                    , explainedHeader "被動" "被動類型的時數，但不包含「旁聽訓話」。"
                    , HH.th_ [ HH.text "觀察" ]
                    ]
                ]
            , HH.tbody_ (map (renderSummary maximums) state.summaries)
            ]
        ]

explainedHeader :: forall m. String -> String -> H.ComponentHTML Action Slots m
explainedHeader label explanation =
  HH.th
    [ HP.attr (HH.AttrName "title") explanation
    , HP.class_ (HH.ClassName "summary-explained-header")
    ]
    [ HH.text label
    , HH.span [ HP.class_ (HH.ClassName "summary-help-icon") ] [ HH.text "?" ]
    ]

findMaximums :: Array VolunteerHourSummary -> Maximums
findMaximums =
  foldl
    (\maximums summary ->
      { teaching: max maximums.teaching summary.teachingHours
      , virtue: max maximums.virtue summary.virtueHours
      , interaction: max maximums.interaction summary.interactionHours
      , passive: max maximums.passive summary.passiveHours
      }
    )
    { teaching: 0.0, virtue: 0.0, interaction: 0.0, passive: 0.0 }

renderSummary
  :: forall m
   . Maximums
  -> VolunteerHourSummary
  -> H.ComponentHTML Action Slots m
renderSummary maximums summary =
  HH.tr_
    [ HH.td_
        [ HH.strong_ [ HH.text (summary.volunteerName <> "(" <> show (summary.age - 6) <> ")") ]
        , HH.span
            [ HP.class_ (HH.ClassName "summary-seat") ]
            [ HH.text (showSeat summary.seatRow summary.seatCol) ]
        ]
    , metricCell "summary-bar-teaching" summary.teachingHours maximums.teaching
    , metricCell "summary-bar-virtue" summary.virtueHours maximums.virtue
    , metricCell "summary-bar-interaction" summary.interactionHours maximums.interaction
    , metricCell "summary-bar-passive" summary.passiveHours maximums.passive
    , HH.td_ [ renderObservation summary ]
    ]

showSeat :: Maybe Int -> Maybe Int -> String
showSeat (Just row) (Just col) = "114下座位 " <> show row <> "-" <> show col
showSeat _ _ = "114下未排座位"

metricCell
  :: forall m
   . String
  -> Number
  -> Number
  -> H.ComponentHTML Action Slots m
metricCell colorClass value maximum =
  let percentage = if maximum <= 0.0 then 0.0 else value / maximum * 100.0
  in
  HH.td_
    [ HH.div
        [ HP.class_ (HH.ClassName "summary-metric") ]
        [ HH.span [ HP.class_ (HH.ClassName "summary-hours") ] [ HH.text (show value <> " 小時") ]
        , HH.div
            [ HP.class_ (HH.ClassName "summary-bar-track") ]
            [ HH.div
                [ HP.classes [ HH.ClassName "summary-bar", HH.ClassName colorClass ]
                , HP.style ("width: " <> show percentage <> "%")
                ]
                []
            ]
        ]
    ]

renderObservation :: forall m. VolunteerHourSummary -> H.ComponentHTML Action Slots m
renderObservation summary
  | summary.totalHours <= 0.0 = observationTag "summary-tag-empty" "尚無紀錄"
  | summary.teachingHours > 0.0 && summary.totalHours == summary.teachingHours =
      observationTag "summary-tag-teaching" "只有教學"
  | summary.dailyInteractionHours > 0.0 && summary.totalHours == summary.dailyInteractionHours =
      observationTag "summary-tag-interaction" "只有日常互動"
  | otherwise = HH.span [ HP.class_ (HH.ClassName "summary-tag-balanced") ] [ HH.text "—" ]

observationTag :: forall m. String -> String -> H.ComponentHTML Action Slots m
observationTag className label =
  HH.span
    [ HP.classes [ HH.ClassName "summary-observation-tag", HH.ClassName className ] ]
    [ HH.text label ]

handleAction
  :: forall m
   . Monad m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Receive input -> H.put input
  Retry -> H.raise RetryRequested
