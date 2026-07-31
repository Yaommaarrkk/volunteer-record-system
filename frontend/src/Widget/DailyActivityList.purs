module Widget.DailyActivityList
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.String.Common as String
import Domain.DailyActivity (DailyActivity)
import Effect (Effect)
import Effect.Class (class MonadEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import Web.Event.Event as Event
import Web.UIEvent.MouseEvent (MouseEvent)
import Web.UIEvent.MouseEvent as MouseEvent

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { activities :: Array DailyActivity
  , totalActivities :: Int
  , isLoading :: Boolean
  , isLoadingMore :: Boolean
  , hasMore :: Boolean
  , loadError :: Maybe String
  }

type State =
  { activities :: Array DailyActivity
  , totalActivities :: Int
  , isLoading :: Boolean
  , isLoadingMore :: Boolean
  , hasMore :: Boolean
  , loadError :: Maybe String
  , selectedDates :: Array String
  , selectionAnchor :: Maybe Int
  , isDeleteDialogOpen :: Boolean
  }

data Action
  = Initialize
  | Receive Input
  | ViewportChanged
  | SelectActivity Int MouseEvent
  | ToggleActivity String Int MouseEvent
  | CopyActivityDescription String MouseEvent
  | AskDeleteActivity String MouseEvent
  | AskDelete
  | CancelDelete
  | ConfirmDelete
  | Retry

data Output
  = CopyRequested String
  | DeleteRequested (Array String)
  | LoadMoreRequested
  | RetryRequested

foreign import subscribeWindowScroll
  :: (Unit -> Effect Unit)
  -> Effect (Effect Unit)

foreign import isLoadMoreSentinelVisible :: Effect Boolean
foreign import formatActivityDate :: String -> String

component :: forall query m. MonadEffect m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState: \input ->
        { activities: input.activities
        , totalActivities: input.totalActivities
        , isLoading: input.isLoading
        , isLoadingMore: input.isLoadingMore
        , hasMore: input.hasMore
        , loadError: input.loadError
        , selectedDates: []
        , selectionAnchor: Nothing
        , isDeleteDialogOpen: false
        }
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { initialize = Just Initialize
            , receive = Just <<< Receive
            , handleAction = handleAction
            }
    }

render :: forall m. State -> H.ComponentHTML Action Slots m
render state =
  HH.section
    [ HP.class_ (HH.ClassName "student-list-card daily-activity-list-card") ]
    [ if state.isDeleteDialogOpen then renderDeleteDialog (Array.length state.selectedDates)
      else HH.text ""
    , HH.div
        [ HP.class_ (HH.ClassName "list-heading") ]
        [ HH.div_
            [ HH.h2_ [ HH.text "登錄歷史" ]
            , HH.p_ [ HH.text "點左側方框可多選；Ctrl 跳選；Shift 連續選取" ]
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "hour-record-list-actions") ]
            [ HH.span
                [ HP.class_ (HH.ClassName "student-count") ]
                [ HH.text
                    if Array.null state.selectedDates then
                      show (Array.length state.activities)
                        <> " / "
                        <> show state.totalActivities
                        <> " 筆紀錄"
                    else
                      "已選 " <> show (Array.length state.selectedDates) <> " 筆"
                ]
            , HH.button
                [ HP.class_ (HH.ClassName "student-delete-button hour-record-batch-delete")
                , HP.disabled (Array.null state.selectedDates)
                , HE.onClick \_ -> AskDelete
                ]
                [ HH.text "刪除選取" ]
            ]
        ]
    , renderContent state
    , HH.div
        [ HP.class_ (HH.ClassName "hour-record-load-more daily-activity-load-more")
        , HP.attr (HH.AttrName "data-daily-activity-load-more") ""
        ]
        [ HH.text
            if state.isLoadingMore then "正在載入更多紀錄…"
            else if state.hasMore then "繼續往下捲動以載入更多"
            else if Array.null state.activities then ""
            else "已載入全部紀錄"
        ]
    ]

renderContent :: forall m. State -> H.ComponentHTML Action Slots m
renderContent state
  | state.isLoading =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在載入當日活動…" ]
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
  | Array.null state.activities =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前還沒有當日活動紀錄。" ]
  | otherwise =
      HH.div
        [ HP.class_ (HH.ClassName "student-table-scroll") ]
        [ HH.table
            [ HP.class_ (HH.ClassName "student-table daily-activity-table") ]
            [ HH.thead_
                [ HH.tr_
                    [ HH.th_ [ HH.text "" ]
                    , HH.th_ [ HH.text "日期" ]
                    , HH.th_ [ HH.text "當日主要活動" ]
                    , HH.th_ [ HH.text "操作" ]
                    ]
                ]
            , HH.tbody_
                (Array.mapWithIndex (renderActivity state.selectedDates) state.activities)
            ]
        ]

renderActivity
  :: forall m
   . Array String
  -> Int
  -> DailyActivity
  -> H.ComponentHTML Action Slots m
renderActivity selectedDates index activity =
  let
    isSelected = Array.elem activity.activityDate selectedDates
  in
    HH.tr
      [ HP.classes
          if isSelected then [ HH.ClassName "hour-record-row-selected" ] else []
      , HE.onClick (SelectActivity index)
      ]
      [ HH.td_
          [ HH.button
              [ HP.class_ (HH.ClassName "hour-record-selection-mark")
              , HP.attr (HH.AttrName "role") "checkbox"
              , HP.attr (HH.AttrName "aria-checked") (if isSelected then "true" else "false")
              , HP.attr (HH.AttrName "aria-label") (if isSelected then "取消選取這筆紀錄" else "選取這筆紀錄")
              , HE.onClick (ToggleActivity activity.activityDate index)
              ]
              [ HH.text if isSelected then "✓" else "" ]
          ]
      , HH.td_ [ HH.text (formatActivityDate activity.activityDate) ]
      , HH.td_ [ HH.text activity.description ]
      , HH.td_
          [ HH.div
              [ HP.class_ (HH.ClassName "daily-activity-actions") ]
              [ HH.button
                  [ HP.class_ (HH.ClassName "daily-activity-copy-button")
                  , HP.attr (HH.AttrName "title") "複製當日主要活動到上方輸入欄"
                  , HE.onClick (CopyActivityDescription activity.description)
                  ]
                  [ HH.text "複製" ]
              , HH.button
                  [ HP.class_ (HH.ClassName "student-delete-button")
                  , HP.attr (HH.AttrName "title") "刪除這筆當日活動"
                  , HE.onClick (AskDeleteActivity activity.activityDate)
                  ]
                  [ HH.text "刪除" ]
              ]
          ]
      ]

renderDeleteDialog :: forall m. Int -> H.ComponentHTML Action Slots m
renderDeleteDialog selectedCount =
  HH.div_
    [ HH.div [ HP.class_ (HH.ClassName "delete-confirm-backdrop") ] []
    , HH.div
        [ HP.class_ (HH.ClassName "delete-confirm-dialog")
        , HP.attr (HH.AttrName "role") "dialog"
        , HP.attr (HH.AttrName "aria-modal") "true"
        ]
        [ HH.h3_ [ HH.text "確定刪除當日活動？" ]
        , HH.p_ [ HH.text ("即將刪除選取的 " <> show selectedCount <> " 筆紀錄，刪除後無法復原。") ]
        , HH.div
            [ HP.class_ (HH.ClassName "delete-confirm-actions") ]
            [ HH.button
                [ HP.class_ (HH.ClassName "delete-confirm-cancel")
                , HE.onClick \_ -> CancelDelete
                ]
                [ HH.text "取消" ]
            , HH.button
                [ HP.class_ (HH.ClassName "delete-confirm-submit")
                , HE.onClick \_ -> ConfirmDelete
                ]
                [ HH.text "確定刪除" ]
            ]
        ]
    ]

handleAction
  :: forall m
   . MonadEffect m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Initialize ->
    void
      $ H.subscribe
      $ ViewportChanged
      <$ HS.makeEmitter subscribeWindowScroll
  Receive input ->
    H.modify_
      \state ->
        state
          { activities = input.activities
          , totalActivities = input.totalActivities
          , isLoading = input.isLoading
          , isLoadingMore = input.isLoadingMore
          , hasMore = input.hasMore
          , loadError = input.loadError
          , selectedDates =
              Array.filter
                (\activityDate ->
                  Array.any
                    (\activity -> activity.activityDate == activityDate)
                    input.activities
                )
                state.selectedDates
          }
  ViewportChanged -> do
    state <- H.get
    when (state.hasMore && not state.isLoading && not state.isLoadingMore) do
      isVisible <- H.liftEffect isLoadMoreSentinelVisible
      when isVisible do
        H.modify_ _ { isLoadingMore = true }
        H.raise LoadMoreRequested
  SelectActivity index event -> do
    state <- H.get
    case Array.index state.activities index of
      Nothing -> pure unit
      Just activity ->
        if MouseEvent.shiftKey event then
          case state.selectionAnchor of
            Nothing ->
              H.modify_
                _
                  { selectedDates = [ activity.activityDate ]
                  , selectionAnchor = Just index
                  }
            Just anchor ->
              let
                start = min anchor index
                end = max anchor index
                rangeDates =
                  map _.activityDate
                    (Array.slice start (end + 1) state.activities)
                selectedDates =
                  if MouseEvent.ctrlKey event || MouseEvent.metaKey event then
                    Array.nub (state.selectedDates <> rangeDates)
                  else
                    rangeDates
              in
                H.modify_ _ { selectedDates = selectedDates }
        else if MouseEvent.ctrlKey event || MouseEvent.metaKey event then
          H.modify_
            _
              { selectedDates =
                  if Array.elem activity.activityDate state.selectedDates then
                    Array.filter (_ /= activity.activityDate) state.selectedDates
                  else
                    Array.snoc state.selectedDates activity.activityDate
              , selectionAnchor = Just index
              }
        else
          H.modify_
            _
              { selectedDates = [ activity.activityDate ]
              , selectionAnchor = Just index
              }
  ToggleActivity activityDate index event -> do
    H.liftEffect (Event.stopPropagation (MouseEvent.toEvent event))
    H.modify_ \state ->
      state
        { selectedDates =
            if Array.elem activityDate state.selectedDates then
              Array.filter (_ /= activityDate) state.selectedDates
            else
              Array.snoc state.selectedDates activityDate
        , selectionAnchor = Just index
        }
  CopyActivityDescription description event -> do
    H.liftEffect (Event.stopPropagation (MouseEvent.toEvent event))
    H.raise (CopyRequested (String.trim description))
  AskDeleteActivity activityDate event -> do
    H.liftEffect (Event.stopPropagation (MouseEvent.toEvent event))
    H.modify_
      _
        { selectedDates = [ activityDate ]
        , selectionAnchor = Nothing
        , isDeleteDialogOpen = true
        }
  AskDelete -> do
    state <- H.get
    unless (Array.null state.selectedDates)
      $ H.modify_ _ { isDeleteDialogOpen = true }
  CancelDelete -> H.modify_ _ { isDeleteDialogOpen = false }
  ConfirmDelete -> do
    state <- H.get
    H.modify_ _ { isDeleteDialogOpen = false }
    unless (Array.null state.selectedDates)
      $ H.raise (DeleteRequested state.selectedDates)
  Retry -> H.raise RetryRequested
