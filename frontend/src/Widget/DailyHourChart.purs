module Widget.DailyHourChart
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldMap)
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits as CodeUnits
import Data.String.Common as String
import Data.String.Pattern (Pattern(..), Replacement(..))
import Domain.DailyHourTotal (DailyHourTotal)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { totals :: Array DailyHourTotal
  , isLoading :: Boolean
  , loadError :: Maybe String
  }

type State = Input

data Action
  = Receive Input
  | Retry

data Output
  = RetryRequested

type Point =
  { x :: Number
  , y :: Number
  , value :: Number
  , date :: String
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
    [ HP.class_ (HH.ClassName "summary-card daily-hour-card") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "list-heading") ]
        [ HH.div_
            [ HH.h2_ [ HH.text "每日總時數" ]
            , HH.p_ [ HH.text "將同一天所有學生的登錄時數加總，日期由舊到新排列。" ]
            ]
        ]
    , renderContent state
    ]

renderContent :: forall m. State -> H.ComponentHTML Action Slots m
renderContent state
  | state.isLoading =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在讀取每日時數……" ]
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
  | Array.null state.totals =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有時數紀錄。" ]
  | otherwise = renderChart state.totals

renderChart :: forall m. Array DailyHourTotal -> H.ComponentHTML Action Slots m
renderChart totals =
  let
    count = Array.length totals
    width = max 720.0 (110.0 + Int.toNumber (max 0 (count - 1)) * 90.0)
    height = 390.0
    left = 62.0
    right = 30.0
    top = 38.0
    bottom = 66.0
    points = Array.mapWithIndex (makePoint count width height left right top bottom) totals
  in
  HH.div
    [ HP.class_ (HH.ClassName "daily-chart-area") ]
    [ HH.div
        [ HP.class_ (HH.ClassName "daily-chart-year") ]
        [ HH.text (yearLabel totals) ]
    , HH.div
        [ HP.class_ (HH.ClassName "daily-chart-scroll") ]
        [ svgElement "svg"
            [ HP.attr (HH.AttrName "viewBox") ("0 0 " <> show width <> " " <> show height)
            , HP.attr (HH.AttrName "role") "img"
            , HP.attr (HH.AttrName "aria-label") "依日期排列的每日學生總時數折線圖"
            , HP.style ("min-width: " <> show width <> "px")
            , HP.attr (HH.AttrName "class") "daily-hour-chart"
            ]
            ( [ svgElement "title" [] [ HH.text "每日學生總時數" ]
              , svgElement "desc" [] [ HH.text "橫軸為日期，縱軸固定為零到十小時。" ]
              ]
                <> renderGrid width height left right top bottom points
                <> [ svgElement "path"
                      [ HP.attr (HH.AttrName "d") (straightPath points)
                      , HP.attr (HH.AttrName "class") "daily-chart-line"
                      , HP.attr (HH.AttrName "fill") "none"
                      , HP.attr (HH.AttrName "stroke") "#3b82f6"
                      , HP.attr (HH.AttrName "stroke-width") "2.5"
                      , HP.attr (HH.AttrName "stroke-linecap") "round"
                      , HP.attr (HH.AttrName "stroke-linejoin") "round"
                      ]
                      []
                   ]
                <> map renderPoint points
            )
        ]
    ]

makePoint
  :: Int
  -> Number
  -> Number
  -> Number
  -> Number
  -> Number
  -> Number
  -> Int
  -> DailyHourTotal
  -> Point
makePoint count width height left right top bottom index total =
  let
    plotWidth = width - left - right
    plotHeight = height - top - bottom
    x =
      if count <= 1 then left + plotWidth / 2.0
      else left + Int.toNumber index / Int.toNumber (count - 1) * plotWidth
    y = top + (1.0 - min 10.0 total.totalHours / 10.0) * plotHeight
  in
  { x, y, value: total.totalHours, date: total.activityDate }

renderGrid
  :: forall m
   . Number
  -> Number
  -> Number
  -> Number
  -> Number
  -> Number
  -> Array Point
  -> Array (H.ComponentHTML Action Slots m)
renderGrid width height left right top bottom points =
  let
    plotHeight = height - top - bottom
    levels = [ 0, 2, 4, 6, 8, 10 ]
  in
  (levels >>= renderHorizontalGrid width left right top plotHeight)
    <> map (renderVerticalGrid top (height - bottom)) points

renderHorizontalGrid
  :: forall m
   . Number
  -> Number
  -> Number
  -> Number
  -> Number
  -> Int
  -> Array (H.ComponentHTML Action Slots m)
renderHorizontalGrid width left right top plotHeight value =
  let y = top + (1.0 - Int.toNumber value / 10.0) * plotHeight
  in
  [ svgElement "line"
      [ HP.attr (HH.AttrName "x1") (show left)
      , HP.attr (HH.AttrName "x2") (show (width - right))
      , HP.attr (HH.AttrName "y1") (show y)
      , HP.attr (HH.AttrName "y2") (show y)
      , HP.attr (HH.AttrName "class") "daily-chart-grid-line"
      , HP.attr (HH.AttrName "stroke") "#d9e5e1"
      , HP.attr (HH.AttrName "stroke-width") "1"
      ]
      []
  , svgElement "text"
      [ HP.attr (HH.AttrName "x") (show (left - 10.0))
      , HP.attr (HH.AttrName "y") (show (y + 4.0))
      , HP.attr (HH.AttrName "text-anchor") "end"
      , HP.attr (HH.AttrName "class") "daily-chart-axis-label"
      ]
      [ HH.text (show value) ]
  ]

renderVerticalGrid
  :: forall m
   . Number
  -> Number
  -> Point
  -> H.ComponentHTML Action Slots m
renderVerticalGrid top bottom point =
  svgElement "line"
    [ HP.attr (HH.AttrName "x1") (show point.x)
    , HP.attr (HH.AttrName "x2") (show point.x)
    , HP.attr (HH.AttrName "y1") (show top)
    , HP.attr (HH.AttrName "y2") (show bottom)
    , HP.attr (HH.AttrName "class") "daily-chart-grid-line daily-chart-grid-line-vertical"
    , HP.attr (HH.AttrName "stroke") "#e8efed"
    , HP.attr (HH.AttrName "stroke-width") "1"
    ]
    []

straightPath :: Array Point -> String
straightPath points = case Array.uncons points of
  Nothing -> ""
  Just { head, tail } ->
    "M " <> show head.x <> " " <> show head.y
      <> foldMap (\point -> " L " <> show point.x <> " " <> show point.y) tail

renderPoint :: forall m. Point -> H.ComponentHTML Action Slots m
renderPoint point =
  svgElement "g"
    [ HP.attr (HH.AttrName "class") "daily-chart-point-group" ]
    [ svgElement "circle"
        [ HP.attr (HH.AttrName "cx") (show point.x)
        , HP.attr (HH.AttrName "cy") (show point.y)
        , HP.attr (HH.AttrName "r") "5"
        , HP.attr (HH.AttrName "class") "daily-chart-point"
        , HP.attr (HH.AttrName "fill") "#ffffff"
        , HP.attr (HH.AttrName "stroke") "#2563eb"
        , HP.attr (HH.AttrName "stroke-width") "3"
        ]
        [ svgElement "title" [] [ HH.text (point.date <> "：" <> formatHours point.value <> " 小時") ] ]
    , svgElement "text"
        [ HP.attr (HH.AttrName "x") (show point.x)
        , HP.attr (HH.AttrName "y") (show (point.y - 12.0))
        , HP.attr (HH.AttrName "text-anchor") "middle"
        , HP.attr (HH.AttrName "class") "daily-chart-value-label"
        ]
        [ HH.text (formatHours point.value) ]
    , svgElement "text"
        [ HP.attr (HH.AttrName "x") (show point.x)
        , HP.attr (HH.AttrName "y") "350"
        , HP.attr (HH.AttrName "text-anchor") "middle"
        , HP.attr (HH.AttrName "class") "daily-chart-date-label"
        ]
        [ HH.text (shortDate point.date) ]
    ]

yearLabel :: Array DailyHourTotal -> String
yearLabel totals =
  String.joinWith "、" (Array.nub (map (CodeUnits.take 4 <<< _.activityDate) totals)) <> " 年"

shortDate :: String -> String
shortDate =
  String.replaceAll (Pattern "-") (Replacement "/") <<< CodeUnits.drop 5

formatHours :: Number -> String
formatHours value =
  show (Int.toNumber (Int.round (value * 10.0)) / 10.0)

svgElement
  :: forall r m
   . String
  -> Array (HP.IProp r Action)
  -> Array (H.ComponentHTML Action Slots m)
  -> H.ComponentHTML Action Slots m
svgElement name =
  HH.elementNS
    (HH.Namespace "http://www.w3.org/2000/svg")
    (HH.ElemName name)

handleAction
  :: forall m
   . Monad m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Receive input -> H.put input
  Retry -> H.raise RetryRequested
