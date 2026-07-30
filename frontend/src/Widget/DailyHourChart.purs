module Widget.DailyHourChart
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldMap, foldl)
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

type State =
  { totals :: Array DailyHourTotal
  , isLoading :: Boolean
  , loadError :: Maybe String
  , openedDescription :: Maybe String
  }

data Action
  = Receive Input
  | OpenDescription String
  | CloseDescription
  | Retry

data Output
  = RetryRequested

type Point =
  { x :: Number
  , y :: Number
  , value :: Number
  , date :: String
  , description :: Maybe String
  }

component :: forall query m. Monad m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState: \input ->
        { totals: input.totals
        , isLoading: input.isLoading
        , loadError: input.loadError
        , openedDescription: Nothing
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
    [ HP.class_ (HH.ClassName "summary-card daily-hour-card") ]
    [ renderDescriptionDialog state.openedDescription
    , HH.div
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
    height = 430.0
    left = 62.0
    right = 30.0
    top = 38.0
    bottom = 106.0
    maximumValue = foldl (\current total -> max current total.totalHours) 0.0 totals
    axisStep = max 1 (Int.ceil (maximumValue / 5.0))
    axisMaximum = Int.toNumber (axisStep * 5)
    points =
      Array.mapWithIndex
        (makePoint count width height left right top bottom axisMaximum)
        totals
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
              , svgElement "desc" [] [ HH.text "橫軸為日期，縱軸依最高時數自動調整。" ]
              ]
                <> renderGrid width height left right top bottom axisStep axisMaximum points
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
  -> Number
  -> Int
  -> DailyHourTotal
  -> Point
makePoint count width height left right top bottom axisMaximum index total =
  let
    plotWidth = width - left - right
    plotHeight = height - top - bottom
    x =
      if count <= 1 then left + plotWidth / 2.0
      else left + Int.toNumber index / Int.toNumber (count - 1) * plotWidth
    y = top + (1.0 - total.totalHours / axisMaximum) * plotHeight
  in
  { x
  , y
  , value: total.totalHours
  , date: total.activityDate
  , description: total.dailyActivityDescription
  }

renderGrid
  :: forall m
   . Number
  -> Number
  -> Number
  -> Number
  -> Number
  -> Number
  -> Int
  -> Number
  -> Array Point
  -> Array (H.ComponentHTML Action Slots m)
renderGrid width height left right top bottom axisStep axisMaximum points =
  let
    plotHeight = height - top - bottom
    levels = map (_ * axisStep) [ 0, 1, 2, 3, 4, 5 ]
  in
  (levels >>= renderHorizontalGrid width left right top plotHeight axisMaximum)
    <> map (renderVerticalGrid top (height - bottom)) points

renderHorizontalGrid
  :: forall m
   . Number
  -> Number
  -> Number
  -> Number
  -> Number
  -> Number
  -> Int
  -> Array (H.ComponentHTML Action Slots m)
renderHorizontalGrid width left right top plotHeight axisMaximum value =
  let y = top + (1.0 - Int.toNumber value / axisMaximum) * plotHeight
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
    ( [ svgElement "circle"
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
      <> renderActivityDescription point
    )

renderActivityDescription
  :: forall m
   . Point
  -> Array (H.ComponentHTML Action Slots m)
renderActivityDescription point = case point.description of
  Nothing -> []
  Just description ->
    let
      length = CodeUnits.length description
      content =
        if length <= 3 then
          [ xhtmlElement "span"
              [ HP.class_ (HH.ClassName "daily-chart-activity-note-single") ]
              [ HH.text description ]
          ]
        else if length <= 8 then
          let
            firstLineLength = div (length + 1) 2
          in
            [ xhtmlElement "span"
                [ HP.class_ (HH.ClassName "daily-chart-activity-note-lines") ]
                [ xhtmlElement "span" []
                    [ HH.text (CodeUnits.take firstLineLength description) ]
                , xhtmlElement "span" []
                    [ HH.text (CodeUnits.drop firstLineLength description) ]
                ]
            ]
        else
          [ xhtmlElement "span"
              [ HP.class_ (HH.ClassName "daily-chart-activity-note-preview") ]
              [ xhtmlElement "span" []
                  [ HH.text (CodeUnits.take 4 description) ]
              , xhtmlElement "span"
                  [ HP.class_ (HH.ClassName "daily-chart-activity-note-preview-more") ]
                  [ xhtmlElement "span" []
                      [ HH.text (CodeUnits.take 2 (CodeUnits.drop 4 description)) ]
                  , xhtmlElement "button"
                      [ HP.class_ (HH.ClassName "daily-chart-note-more")
                      , HP.attr (HH.AttrName "type") "button"
                      , HP.attr (HH.AttrName "aria-label") "查看完整當日活動"
                      , HE.onClick \_ -> OpenDescription description
                      ]
                      [ HH.text "..." ]
                  ]
              ]
          ]
    in
      [ svgElement "foreignObject"
          [ HP.attr (HH.AttrName "x") (show (point.x - 45.0))
          , HP.attr (HH.AttrName "y") "360"
          , HP.attr (HH.AttrName "width") "90"
          , HP.attr (HH.AttrName "height") "44"
          , HP.attr (HH.AttrName "class") "daily-chart-activity-note-object"
          ]
          [ xhtmlElement "div"
              [ HP.class_ (HH.ClassName "daily-chart-activity-note-box") ]
              content
          ]
      ]

renderDescriptionDialog
  :: forall m
   . Maybe String
  -> H.ComponentHTML Action Slots m
renderDescriptionDialog = case _ of
  Nothing -> HH.text ""
  Just description ->
    HH.div
      [ HP.class_ (HH.ClassName "daily-chart-note-overlay")
      , HP.attr (HH.AttrName "role") "dialog"
      , HP.attr (HH.AttrName "aria-modal") "true"
      , HE.onClick \_ -> CloseDescription
      ]
      [ HH.div
          [ HP.class_ (HH.ClassName "daily-chart-note-dialog") ]
          [ HH.h3_ [ HH.text "當日活動" ]
          , HH.p_ [ HH.text description ]
          , HH.span_ [ HH.text "點任意位置返回" ]
          ]
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

xhtmlElement
  :: forall r m
   . String
  -> Array (HP.IProp r Action)
  -> Array (H.ComponentHTML Action Slots m)
  -> H.ComponentHTML Action Slots m
xhtmlElement name =
  HH.elementNS
    (HH.Namespace "http://www.w3.org/1999/xhtml")
    (HH.ElemName name)

handleAction
  :: forall m
   . Monad m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Receive input ->
    H.modify_
      _
        { totals = input.totals
        , isLoading = input.isLoading
        , loadError = input.loadError
        }
  OpenDescription description ->
    H.modify_ _ { openedDescription = Just description }
  CloseDescription ->
    H.modify_ _ { openedDescription = Nothing }
  Retry -> H.raise RetryRequested
