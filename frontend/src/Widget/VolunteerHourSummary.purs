module Widget.VolunteerHourSummary
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude
import Affjax.ResponseFormat as ResponseFormat
import Affjax.Web as AX
import Config.Api (apiUrl)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.String.Common as String
import Data.String.Pattern (Pattern(..), Replacement(..))
import Data.Time.Duration (Milliseconds(..))
import Domain.Activity (activityTypeLabel)
import Domain.Volunteer (ageToGrade)
import Domain.VolunteerHourDetail (VolunteerHourDetail)
import Domain.VolunteerHourSummary (VolunteerHourSummary)
import Effect (Effect)
import Effect.Aff (Aff, delay, makeAff, nonCanceler)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Simple.JSON (readJSON)

type Slot id
  = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots
  = ()

type Input
  = { summaries :: Array VolunteerHourSummary
    , isLoading :: Boolean
    , loadError :: Maybe String
    }

type State
  = { summaries :: Array VolunteerHourSummary -- 原始資料表
    , isLoading :: Boolean
    , loadError :: Maybe String
    , selectedSummary :: Maybe VolunteerHourSummary
    , detail :: Maybe VolunteerHourDetail
    , isDetailLoading :: Boolean
    , detailError :: Maybe String
    , copyStatus :: Maybe Boolean
    }

type RankedSummary  -- 原始個人數據 + PR值相關
  = { summary :: VolunteerHourSummary
    , teachingPr :: Int
    , interactionPr :: Int
    , combinedPr :: Int
    }

type VolunteerDetailResponse
  = { success :: Boolean
    , message :: String
    , data :: VolunteerHourDetail
    }

data Action
  = Receive Input
  | Retry
  | OpenDetail VolunteerHourSummary
  | CloseDetail
  | DetailLoaded (Either String VolunteerHourDetail)
  | CopyTable
  | ClearCopyStatus

data Output
  = RetryRequested

component :: forall query m. MonadAff m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { handleAction = handleAction
            , receive = Just <<< Receive
            }
    }

initialState :: Input -> State
initialState input =
  { summaries: input.summaries
  , isLoading: input.isLoading
  , loadError: input.loadError
  , selectedSummary: Nothing
  , detail: Nothing
  , isDetailLoading: false
  , detailError: Nothing
  , copyStatus: Nothing
  }

render :: forall m. State -> H.ComponentHTML Action Slots m
render state =
  let
    rankedSummaries = rankSummaries state.summaries
  in
    HH.section
      [ HP.class_ (HH.ClassName "summary-card") ]
      ( [ HH.div
            [ HP.class_ (HH.ClassName "list-heading") ]
            [ HH.div_
                [ HH.h2_ [ HH.text "學生時數比較" ]
                , HH.p_ [ HH.text "依教學 PR 與互動 PR 的合計由高到低排序；點學生可查看明細。" ]
                ]
            , HH.div
                [ HP.class_ (HH.ClassName "summary-heading-actions") ]
                ( ( case state.copyStatus of
                      Nothing -> []
                      Just true ->
                        [ HH.span
                            [ HP.class_ (HH.ClassName "summary-copy-status summary-copy-success") ]
                            [ HH.text "已複製" ]
                        ]
                      Just false ->
                        [ HH.span
                            [ HP.class_ (HH.ClassName "summary-copy-status summary-copy-error") ]
                            [ HH.text "複製失敗" ]
                        ]
                  )
                    <> [ HH.button
                          [ HP.class_ (HH.ClassName "summary-copy-button")
                          , HP.disabled (state.isLoading || Array.null state.summaries)
                          , HE.onClick \_ -> CopyTable
                          ]
                          [ HH.text "複製表格" ]
                      , HH.span
                          [ HP.class_ (HH.ClassName "student-count") ]
                          [ HH.text (show (Array.length state.summaries) <> " 位學生") ]
                      ]
                )
            ]
        , renderContent state rankedSummaries
        ]
          <> case state.selectedSummary of
              Nothing -> []
              Just summary -> [ renderDetailModal state summary ]
      )

renderContent ::
  forall m.
  State ->
  Array RankedSummary ->
  H.ComponentHTML Action Slots m
renderContent state rankedSummaries
  | state.isLoading = HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在讀取統計資料……" ]
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
  | Array.null rankedSummaries = HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有學生資料。" ]
  | otherwise =
    let
      averageInteraction = classInteractionPercentage state.summaries
    in
      HH.div_
        [ renderClassAverage state.summaries
        , HH.div
            [ HP.class_ (HH.ClassName "summary-table-scroll") ]
            [ HH.table
                [ HP.class_ (HH.ClassName "summary-table summary-pr-table") ]
                [ HH.thead_
                    [ HH.tr_
                        [ HH.th_ [ HH.text "姓名（年級）" ]
                        , explainedHeader
                            "教學／互動"
                            "同一個圓餅呈現教學與互動的比例；圓心顯示兩項時數在全班的 PR。"
                        , HH.th_ [ HH.text "原始數據" ]
                        , explainedHeader
                            "其他"
                            "品德教育與被動時數的合計，不參與圓餅比例與 PR 排序。"
                        ]
                    ]
                , HH.tbody_ (map (renderSummary averageInteraction) rankedSummaries)
                ]
            ]
        ]

renderClassAverage ::
  forall m.
  Array VolunteerHourSummary ->
  H.ComponentHTML Action Slots m
renderClassAverage summaries =
  let
    totals =
      foldl
        ( \result summary ->
            { teaching: result.teaching + summary.teachingHours
            , interaction: result.interaction + summary.interactionHours
            }
        )
        { teaching: 0.0, interaction: 0.0 }
        summaries
  in
    HH.div
      [ HP.class_ (HH.ClassName "summary-class-average") ]
      [ HH.div_
          [ HH.h3_ [ HH.text "全班平均比例" ]
          , HH.p_ [ HH.text "以全班教學與互動的總時數計算。" ]
          ]
      , renderRatioPie "summary-pie-large" totals.teaching totals.interaction
      , renderRatioLegend totals.teaching totals.interaction
      ]

classInteractionPercentage :: Array VolunteerHourSummary -> Int
classInteractionPercentage summaries =
  let
    totals =
      foldl
        ( \result summary ->
            { teaching: result.teaching + summary.teachingHours
            , interaction: result.interaction + summary.interactionHours
            }
        )
        { teaching: 0.0, interaction: 0.0 }
        summaries
  in
    (ratioPercentages totals.teaching totals.interaction).interaction

explainedHeader :: forall m. String -> String -> H.ComponentHTML Action Slots m
explainedHeader label explanation =
  HH.th
    [ HP.attr (HH.AttrName "title") explanation
    , HP.class_ (HH.ClassName "summary-explained-header")
    ]
    [ HH.text label
    , HH.span [ HP.class_ (HH.ClassName "summary-help-icon") ] [ HH.text "?" ]
    ]

rankSummaries :: Array VolunteerHourSummary -> Array RankedSummary -- 原始資料表轉含PR且排序的表
rankSummaries summaries =
  let
    teachingValues = map _.teachingHours summaries

    interactionValues = map _.interactionHours summaries

    addRank summary =
      let
        teachingPr = percentileRank teachingValues summary.teachingHours

        interactionPr = percentileRank interactionValues summary.interactionHours
      in
        { summary
        , teachingPr
        , interactionPr
        , combinedPr: teachingPr + interactionPr
        }
  in
    Array.sortBy compareRanked (map addRank summaries)

percentileRank :: Array Number -> Number -> Int
percentileRank values value
  | Array.null values = 0
  | otherwise =
    Int.round
      ( Int.toNumber (Array.length (Array.filter (_ < value) values))
          / Int.toNumber (Array.length values)
          * 100.0
      )

compareRanked :: RankedSummary -> RankedSummary -> Ordering
compareRanked left right = case compare right.combinedPr left.combinedPr of
  EQ -> case compare
      (right.summary.teachingHours + right.summary.interactionHours)
      (left.summary.teachingHours + left.summary.interactionHours) of
    EQ -> compare left.summary.volunteerName right.summary.volunteerName
    order -> order
  order -> order

-- 處理單一帶PR值資料轉HTML(一列)
renderSummary :: forall m. Int -> RankedSummary -> H.ComponentHTML Action Slots m
renderSummary averageInteraction ranked =
  let
    summary = ranked.summary

    otherHours = summary.virtueHours + summary.passiveHours
  in
    HH.tr_
      [ HH.td_
          [ HH.button
              [ HP.class_ (HH.ClassName "summary-student-button")
              , HE.onClick \_ -> OpenDetail summary
              ]
              [ HH.strong_ [ HH.text (summary.volunteerName <> "(" <> show (ageToGrade summary.age) <> ")") ] ]
          ]
      , HH.td_
          [ renderPrPie
              summary.teachingHours
              summary.interactionHours
              ranked.teachingPr
              ranked.interactionPr
              averageInteraction
          ]
      , HH.td_
          [ HH.div
              [ HP.class_ (HH.ClassName "summary-raw-data") ]
              [ HH.div
                  [ HP.class_ (HH.ClassName "summary-raw-data-left") ]
                  [ HH.text ("教學：" <> formatHours summary.teachingHours) ]
              , HH.div
                  [ HP.class_ (HH.ClassName "summary-raw-data-right") ]
                  [ HH.text ("互動：" <> formatHours summary.interactionHours) ]
              ]
          ]
      , HH.td_
          ( if otherHours <= 0.0 then
              []
            else
              [ HH.strong
                  [ HP.class_ (HH.ClassName "summary-other-hours") ]
                  [ HH.text (formatHours otherHours <> " 小時") ]
              , HH.span
                  [ HP.class_ (HH.ClassName "summary-other-detail") ]
                  [ HH.text (otherHoursDetail summary) ]
              ]
          )
      ]

otherHoursDetail :: VolunteerHourSummary -> String
otherHoursDetail summary
  | summary.virtueHours > 0.0 && summary.passiveHours > 0.0 =
    "品德 "
      <> formatHours summary.virtueHours
      <> "・被動 "
      <> formatHours summary.passiveHours
  | summary.virtueHours > 0.0 = "品德 " <> formatHours summary.virtueHours
  | summary.passiveHours > 0.0 = "被動 " <> formatHours summary.passiveHours
  | otherwise = ""

renderPrPie ::
  forall m.
  Number ->
  Number ->
  Int ->
  Int ->
  Int ->
  H.ComponentHTML Action Slots m
renderPrPie teaching interaction teachingPr interactionPr averageInteraction =
  let
    studentInteraction = (ratioPercentages teaching interaction).interaction
  in
    HH.div
      [ HP.class_ (HH.ClassName "summary-pie-row") ]
      [ renderDonut
          ""
          teaching
          interaction
          [ HH.span [ HP.class_ (HH.ClassName "summary-pr-teaching") ]
              [ HH.text ("教 PR" <> show teachingPr) ]
          , HH.span [ HP.class_ (HH.ClassName "summary-pr-interaction") ]
              [ HH.text ("互 PR" <> show interactionPr) ]
          ]
      , renderInteractionPercentage
          teaching
          interaction
          (Just (studentInteraction - averageInteraction))
      ]

renderRatioPie ::
  forall m.
  String ->
  Number ->
  Number ->
  H.ComponentHTML Action Slots m
renderRatioPie sizeClass teaching interaction =
  let
    percentages = ratioPercentages teaching interaction
  in
    HH.div
      [ HP.class_ (HH.ClassName "summary-pie-row") ]
      [ renderDonut
          sizeClass
          teaching
          interaction
          [ HH.span [ HP.class_ (HH.ClassName "summary-pr-teaching") ]
              [ HH.text ("教學 " <> show percentages.teaching <> "%") ]
          ]
      , renderInteractionPercentage teaching interaction Nothing
      ]

renderDonut ::
  forall m.
  String ->
  Number ->
  Number ->
  Array (H.ComponentHTML Action Slots m) ->
  H.ComponentHTML Action Slots m
renderDonut sizeClass teaching interaction centerContent =
  let
    total = teaching + interaction

    teachingPercentage =
      if total <= 0.0 then
        0.0
      else
        teaching / total * 100.0

    interactionPercentage =
      if total <= 0.0 then
        0.0
      else
        100.0 - teachingPercentage

    teachingArc =
      if teaching <= 0.0 then
        []
      else
        [ donutArc
            "summary-donut-teaching"
            teachingPercentage
            0.0
            ("教學 " <> formatHours teaching <> " 小時")
        ]

    interactionArc =
      if interaction <= 0.0 then
        []
      else
        [ donutArc
            "summary-donut-interaction"
            interactionPercentage
            teachingPercentage
            ("互動 " <> formatHours interaction <> " 小時")
        ]
  in
    HH.div
      [ HP.classes
          [ HH.ClassName "summary-donut-shell"
          , HH.ClassName sizeClass
          ]
      ]
      [ svgElement "svg"
          [ HP.attr (HH.AttrName "viewBox") "0 0 120 120"
          , HP.attr (HH.AttrName "class") "summary-donut-svg"
          , HP.attr (HH.AttrName "aria-label") "教學與互動時數比例"
          ]
          ( [ svgElement "circle"
                [ HP.attr (HH.AttrName "cx") "60"
                , HP.attr (HH.AttrName "cy") "60"
                , HP.attr (HH.AttrName "r") "44"
                , HP.attr (HH.AttrName "pathLength") "100"
                , HP.attr (HH.AttrName "class") "summary-donut-track"
                ]
                []
            ]
              <> teachingArc
              <> interactionArc
          )
      , HH.div
          [ HP.class_ (HH.ClassName "summary-pie-center") ]
          centerContent
      ]

donutArc ::
  forall m.
  String ->
  Number ->
  Number ->
  String ->
  H.ComponentHTML Action Slots m
donutArc className percentage offset title =
  svgElement "circle"
    [ HP.attr (HH.AttrName "cx") "60"
    , HP.attr (HH.AttrName "cy") "60"
    , HP.attr (HH.AttrName "r") "44"
    , HP.attr (HH.AttrName "pathLength") "100"
    , HP.attr (HH.AttrName "class") ("summary-donut-segment " <> className)
    , HP.attr (HH.AttrName "stroke-dasharray") (show percentage <> " 100")
    , HP.attr (HH.AttrName "stroke-dashoffset") (show (-offset))
    , HP.attr (HH.AttrName "transform") "rotate(-90 60 60)"
    ]
    [ svgElement "title" [] [ HH.text title ] ]

renderInteractionPercentage ::
  forall m.
  Number ->
  Number ->
  Maybe Int ->
  H.ComponentHTML Action Slots m
renderInteractionPercentage teaching interaction difference =
  let
    total = teaching + interaction

    percentages = ratioPercentages teaching interaction

    toneClass =
      if total <= 0.0 then
        "summary-interaction-no-data"
      else case difference of
        Nothing -> "summary-interaction-average"
        Just value -> interactionToneClass value
  in
    HH.div
      [ HP.classes
          [ HH.ClassName "summary-interaction-percentage"
          , HH.ClassName toneClass
          ]
      ]
      [ HH.span_ [ HH.text "互動" ]
      , HH.strong_
          [ HH.text
              (if total <= 0.0 then "—" else show percentages.interaction <> "%")
          ]
      , case difference of
          Just value
            | total > 0.0 -> HH.small_ [ HH.text ("(" <> signedPercentage value <> ")") ]
          _ ->
            if total <= 0.0 then
              HH.small_ [ HH.text "(無紀錄)" ]
            else
              HH.text ""
      ]

interactionToneClass :: Int -> String
interactionToneClass difference
  | difference < -30 = "summary-interaction-very-low"
  | difference < -15 = "summary-interaction-low"
  | difference <= 8 = "summary-interaction-normal"
  | difference <= 18 = "summary-interaction-high"
  | otherwise = "summary-interaction-very-high"

signedPercentage :: Int -> String
signedPercentage value = (if value >= 0 then "+" else "") <> show value <> "%"

tableHeaders :: Array String
tableHeaders =
  [ "姓名（年級）"
  , "教學時數"
  , "互動時數"
  , "其他時數"
  , "教學 PR"
  , "互動 PR"
  , "互動比例"
  , "與全班平均差"
  ]

tableRowValues :: Int -> RankedSummary -> Array String
tableRowValues averageInteraction ranked =
  let
    summary = ranked.summary

    otherHours = summary.virtueHours + summary.passiveHours

    interactionPercentage = (ratioPercentages summary.teachingHours summary.interactionHours).interaction

    hasRatio = summary.teachingHours + summary.interactionHours > 0.0
  in
    [ summary.volunteerName <> "(" <> show (ageToGrade summary.age) <> ")"
    , formatHours summary.teachingHours
    , formatHours summary.interactionHours
    , if otherHours <= 0.0 then "" else formatHours otherHours
    , show ranked.teachingPr
    , show ranked.interactionPr
    , if hasRatio then show interactionPercentage <> "%" else ""
    , if hasRatio then signedPercentage (interactionPercentage - averageInteraction) else ""
    ]

summaryTableTsv :: Int -> Array RankedSummary -> String
summaryTableTsv averageInteraction rankedSummaries =
  String.joinWith "\n"
    ( [ String.joinWith "\t" tableHeaders ]
        <> map
            -- tableRowValues會進一步處理和整合資料(例如組合出姓名與年級[楊凱睿(4)])
            (String.joinWith "\t" <<< tableRowValues averageInteraction)
            rankedSummaries
    )

summaryTableHtml :: Int -> Array RankedSummary -> String
summaryTableHtml averageInteraction rankedSummaries =
  let
    headerHtml =
      String.joinWith ""
        (map (\header -> htmlCell "th" header) tableHeaders)

    bodyHtml =
      String.joinWith ""
        ( map
            ( \ranked ->
                "<tr>"
                  <> String.joinWith ""
                      (map (htmlCell "td") (tableRowValues averageInteraction ranked))
                  <> "</tr>"
            )
            rankedSummaries
        )
  in
    "<table style=\"border-collapse:collapse\">"
      <> "<thead><tr>"
      <> headerHtml
      <> "</tr></thead><tbody>"
      <> bodyHtml
      <> "</tbody></table>"

htmlCell :: String -> String -> String
htmlCell tag value =
  "<"
    <> tag
    <> " style=\"border:1px solid #cbd5d1;padding:6px 9px;text-align:left\">"
    <> escapeHtml value
    <> "</"
    <> tag
    <> ">"

escapeHtml :: String -> String
escapeHtml =
  String.replaceAll (Pattern "\"") (Replacement "&quot;")
    <<< String.replaceAll (Pattern ">") (Replacement "&gt;")
    <<< String.replaceAll (Pattern "<") (Replacement "&lt;")
    <<< String.replaceAll (Pattern "&") (Replacement "&amp;")

foreign import copySummaryTableImpl ::
  String ->
  String ->
  (Boolean -> Effect Unit) ->
  Effect Unit

copySummaryTable :: String -> String -> Aff Boolean
copySummaryTable html plainText =
  makeAff \done -> do
    copySummaryTableImpl html plainText (done <<< Right)
    pure nonCanceler

renderRatioLegend ::
  forall m.
  Number ->
  Number ->
  H.ComponentHTML Action Slots m
renderRatioLegend teaching interaction =
  HH.div
    [ HP.class_ (HH.ClassName "summary-ratio-legend") ]
    [ HH.span [ HP.class_ (HH.ClassName "summary-legend-teaching") ]
        [ HH.text ("教學 " <> formatHours teaching <> " 小時") ]
    , HH.span [ HP.class_ (HH.ClassName "summary-legend-interaction") ]
        [ HH.text ("互動 " <> formatHours interaction <> " 小時") ]
    ]

ratioPercentages :: Number -> Number -> { teaching :: Int, interaction :: Int }
ratioPercentages teaching interaction =
  let
    total = teaching + interaction

    teachingPercentage =
      if total <= 0.0 then
        0
      else
        Int.round (teaching / total * 100.0)
  in
    { teaching: teachingPercentage
    , interaction: if total <= 0.0 then 0 else 100 - teachingPercentage
    }

renderDetailModal ::
  forall m.
  State ->
  VolunteerHourSummary ->
  H.ComponentHTML Action Slots m
renderDetailModal state summary =
  HH.div_
    [ HH.div
        [ HP.class_ (HH.ClassName "summary-detail-backdrop")
        , HE.onClick \_ -> CloseDetail
        ]
        []
    , HH.section
        [ HP.class_ (HH.ClassName "summary-detail-dialog")
        , HP.attr (HH.AttrName "role") "dialog"
        , HP.attr (HH.AttrName "aria-modal") "true"
        ]
        [ HH.header
            [ HP.class_ (HH.ClassName "summary-detail-header") ]
            [ HH.div_
                [ HH.p [ HP.class_ (HH.ClassName "page-eyebrow") ] [ HH.text "STUDENT DETAIL" ]
                , HH.h3_ [ HH.text (summary.volunteerName <> " 的時數明細") ]
                ]
            , HH.button
                [ HP.class_ (HH.ClassName "summary-detail-close")
                , HP.attr (HH.AttrName "aria-label") "關閉"
                , HE.onClick \_ -> CloseDetail
                ]
                [ HH.text "×" ]
            ]
        , renderDetailContent state summary
        ]
    ]

renderDetailContent ::
  forall m.
  State ->
  VolunteerHourSummary ->
  H.ComponentHTML Action Slots m
renderDetailContent state summary
  | state.isDetailLoading = HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在讀取學生明細……" ]
  | Just message <- state.detailError =
    HH.div
      [ HP.class_ (HH.ClassName "list-status list-error") ]
      [ HH.p_ [ HH.text message ]
      , HH.button
          [ HP.class_ (HH.ClassName "list-retry-button")
          , HE.onClick \_ -> OpenDetail summary
          ]
          [ HH.text "重新請求" ]
      ]
  | Just detail <- state.detail =
    HH.div
      [ HP.class_ (HH.ClassName "summary-detail-content") ]
      [ HH.section
          [ HP.class_ (HH.ClassName "summary-detail-ratio") ]
          [ HH.div_
              [ HH.h4_ [ HH.text "類型比例" ]
              , HH.p_
                  [ HH.text
                      ( "其他 "
                          <> formatHours (summary.virtueHours + summary.passiveHours)
                          <> " 小時"
                      )
                  ]
              ]
          , renderRatioPie
              "summary-pie-large"
              summary.teachingHours
              summary.interactionHours
          , renderRatioLegend summary.teachingHours summary.interactionHours
          ]
      , renderActivityTotals detail
      , renderRecentRecords detail
      ]
  | otherwise = HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有明細。" ]

renderActivityTotals ::
  forall m.
  VolunteerHourDetail ->
  H.ComponentHTML Action Slots m
renderActivityTotals detail =
  HH.section_
    [ HH.h4_ [ HH.text "參與活動" ]
    , if Array.null detail.activities then
        HH.p [ HP.class_ (HH.ClassName "summary-detail-empty") ] [ HH.text "尚無活動紀錄。" ]
      else
        HH.div
          [ HP.class_ (HH.ClassName "summary-detail-table-scroll") ]
          [ HH.table
              [ HP.class_ (HH.ClassName "summary-detail-table") ]
              [ HH.thead_
                  [ HH.tr_
                      [ HH.th_ [ HH.text "活動" ]
                      , HH.th_ [ HH.text "類型" ]
                      , HH.th_ [ HH.text "合計時數" ]
                      ]
                  ]
              , HH.tbody_
                  ( map
                      ( \activity ->
                          HH.tr_
                            [ HH.td_ [ HH.text activity.activityName ]
                            , HH.td_ [ HH.text (activityTypeLabel activity.activityType) ]
                            , HH.td_ [ HH.text (formatHours activity.hours <> " 小時") ]
                            ]
                      )
                      detail.activities
                  )
              ]
          ]
    ]

renderRecentRecords ::
  forall m.
  VolunteerHourDetail ->
  H.ComponentHTML Action Slots m
renderRecentRecords detail =
  HH.section_
    [ HH.h4_ [ HH.text "最近紀錄" ]
    , if Array.null detail.recentRecords then
        HH.p [ HP.class_ (HH.ClassName "summary-detail-empty") ] [ HH.text "尚無最近紀錄。" ]
      else
        HH.div
          [ HP.class_ (HH.ClassName "summary-detail-table-scroll") ]
          [ HH.table
              [ HP.class_ (HH.ClassName "summary-detail-table summary-recent-table") ]
              [ HH.thead_
                  [ HH.tr_
                      [ HH.th_ [ HH.text "日期" ]
                      , HH.th_ [ HH.text "活動" ]
                      , HH.th_ [ HH.text "類型" ]
                      , HH.th_ [ HH.text "時數" ]
                      , HH.th_ [ HH.text "備註" ]
                      ]
                  ]
              , HH.tbody_
                  ( map
                      ( \record ->
                          HH.tr_
                            [ HH.td_ [ HH.text record.activityDate ]
                            , HH.td_ [ HH.text record.activityName ]
                            , HH.td_ [ HH.text (activityTypeLabel record.activityType) ]
                            , HH.td_ [ HH.text (formatHours record.hours) ]
                            , HH.td_ [ HH.text (if record.note == "" then "—" else record.note) ]
                            ]
                      )
                      detail.recentRecords
                  )
              ]
          ]
    ]

svgElement ::
  forall r m.
  String ->
  Array (HP.IProp r Action) ->
  Array (H.ComponentHTML Action Slots m) ->
  H.ComponentHTML Action Slots m
svgElement name =
  HH.elementNS
    (HH.Namespace "http://www.w3.org/2000/svg")
    (HH.ElemName name)

formatHours :: Number -> String
formatHours value = show (Int.toNumber (Int.round (value * 10.0)) / 10.0)

handleAction ::
  forall m.
  MonadAff m =>
  Action ->
  H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Receive input ->
    H.modify_
      _
        { summaries = input.summaries
        , isLoading = input.isLoading
        , loadError = input.loadError
        }
  Retry -> H.raise RetryRequested
  OpenDetail summary -> do
    H.modify_
      _
        { selectedSummary = Just summary
        , detail = Nothing
        , isDetailLoading = true
        , detailError = Nothing
        }
    result <- H.liftAff (requestVolunteerDetail summary.volunteerId)
    handleAction (DetailLoaded result)
  CloseDetail ->
    H.modify_
      _
        { selectedSummary = Nothing
        , detail = Nothing
        , isDetailLoading = false
        , detailError = Nothing
        }
  DetailLoaded result -> case result of
    Left message ->
      H.modify_
        _
          { detail = Nothing
          , isDetailLoading = false
          , detailError = Just message
          }
    Right detail ->
      H.modify_
        _
          { detail = Just detail
          , isDetailLoading = false
          , detailError = Nothing
          }
  CopyTable -> do
    state <- H.get
    let
      rankedSummaries = rankSummaries state.summaries -- 拿到排序後且含PR值的資料表

      averageInteraction = classInteractionPercentage state.summaries

      html = summaryTableHtml averageInteraction rankedSummaries -- 產生HTML格式

      plainText = summaryTableTsv averageInteraction rankedSummaries -- 產生純文字格式
    copied <- H.liftAff (copySummaryTable html plainText) -- 提供兩種複製這個操作的格式
    H.modify_ _ { copyStatus = Just copied }
    void
      $ H.fork do
          H.liftAff (delay (Milliseconds 2200.0))
          handleAction ClearCopyStatus
  ClearCopyStatus -> H.modify_ _ { copyStatus = Nothing }

requestVolunteerDetail :: Int -> Aff (Either String VolunteerHourDetail)
requestVolunteerDetail volunteerId = do
  result <-
    AX.get
      ResponseFormat.string
      (apiUrl ("/api/summary/volunteer-hours/" <> show volunteerId))
  pure case result of
    Left error -> Left (AX.printError error)
    Right response -> case readJSON response.body of
      Left errors -> Left ("學生明細格式錯誤：" <> show errors)
      Right (decoded :: VolunteerDetailResponse) ->
        if decoded.success then
          Right decoded.data
        else
          Left decoded.message
