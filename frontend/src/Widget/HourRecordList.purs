module Widget.HourRecordList
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.String.Common as String
import Domain.Activity (activityTypeLabel)
import Domain.HourRecord (CopiedHourRecord, HourRecord)
import Domain.Volunteer (formatUpdatedAt)
import Effect.Class (class MonadEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Web.Event.Event as Event
import Web.UIEvent.MouseEvent (MouseEvent)
import Web.UIEvent.MouseEvent as MouseEvent

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { records :: Array HourRecord
  , isLoading :: Boolean
  , loadError :: Maybe String
  }

type State =
  { records :: Array HourRecord
  , isLoading :: Boolean
  , loadError :: Maybe String
  , selectedIds :: Array Int
  , selectionAnchor :: Maybe Int
  , isDeleteDialogOpen :: Boolean
  }

data Action
  = Receive Input
  | SelectRecord Int MouseEvent
  | CopyRecord HourRecord MouseEvent
  | AskDeleteRecord Int MouseEvent
  | AskDelete
  | CancelDelete
  | ConfirmDelete
  | Retry

data Output
  = DeleteRequested (Array Int)
  | CopyRequested CopiedHourRecord
  | RetryRequested

component :: forall query m. MonadEffect m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState: \input ->
        { records: input.records
        , isLoading: input.isLoading
        , loadError: input.loadError
        , selectedIds: []
        , selectionAnchor: Nothing
        , isDeleteDialogOpen: false
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
    [ HP.class_ (HH.ClassName "student-list-card hour-record-list-card") ]
    [ if state.isDeleteDialogOpen then renderDeleteDialog (Array.length state.selectedIds)
      else HH.text ""
    , HH.div
        [ HP.class_ (HH.ClassName "list-heading") ]
        [ HH.div_
            [ HH.h2_ [ HH.text "登錄歷史" ]
            , HH.p_ [ HH.text "單擊選取；Ctrl 跳選；Shift 連續選取" ]
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "hour-record-list-actions") ]
            [ HH.span
                [ HP.class_ (HH.ClassName "student-count") ]
                [ HH.text
                    ( if Array.null state.selectedIds then
                        show (Array.length state.records) <> " 筆紀錄"
                      else
                        "已選 " <> show (Array.length state.selectedIds) <> " 筆"
                    )
                ]
            , HH.button
                [ HP.class_ (HH.ClassName "student-delete-button hour-record-batch-delete")
                , HP.disabled (Array.null state.selectedIds)
                , HE.onClick \_ -> AskDelete
                ]
                [ HH.text "刪除選取" ]
            ]
        ]
    , renderRecordList state
    ]

renderRecordList :: forall m. State -> H.ComponentHTML Action Slots m
renderRecordList state
  | state.isLoading =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在載入時數紀錄…" ]
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
  | Array.null state.records =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有時數登錄紀錄。" ]
  | otherwise =
      HH.div
        [ HP.class_ (HH.ClassName "student-table-scroll") ]
        [ HH.table
            [ HP.classes [ HH.ClassName "student-table", HH.ClassName "hour-record-table" ] ]
            [ HH.thead_
                [ HH.tr_
                    [ HH.th_ [ HH.text "" ]
                    , HH.th_ [ HH.text "日期" ]
                    , HH.th_ [ HH.text "活動名" ]
                    , HH.th_ [ HH.text "類型" ]
                    , HH.th_ [ HH.text "學生" ]
                    , HH.th_ [ HH.text "時數" ]
                    , HH.th_ [ HH.text "備註" ]
                    , HH.th_ [ HH.text "登錄時間" ]
                    , HH.th_ [ HH.text "操作" ]
                    ]
                ]
            , HH.tbody_
                (Array.mapWithIndex (renderRecord state.selectedIds) state.records)
            ]
        ]

renderRecord
  :: forall m
   . Array Int
  -> Int
  -> HourRecord
  -> H.ComponentHTML Action Slots m
renderRecord selectedIds index record =
  let
    isSelected = Array.elem record.id selectedIds
    createdAt = formatUpdatedAt record.createdAt
  in
    HH.tr
      [ HP.classes
          if isSelected then [ HH.ClassName "hour-record-row-selected" ] else []
      , HE.onClick (SelectRecord index)
      ]
      [ HH.td_
          [ HH.span
              [ HP.class_ (HH.ClassName "hour-record-selection-mark") ]
              [ HH.text if isSelected then "✓" else "" ]
          ]
      , HH.td_ [ HH.text record.activityDate ]
      , HH.td_ [ HH.strong_ [ HH.text record.activityName ] ]
      , HH.td_
          [ HH.span
              [ HP.class_ (HH.ClassName "hour-record-type-tag")
              , HP.style ("background-color: " <> record.tagColor)
              ]
              [ HH.text (activityTypeLabel record.activityType) ]
          ]
      , HH.td_ [ HH.text record.volunteerName ]
      , HH.td_ [ HH.text (show record.hours) ]
      , HH.td
          [ HP.class_ (HH.ClassName "hour-record-note-cell") ]
          [ HH.text if String.trim record.note == "" then "-" else record.note ]
      , HH.td_
          [ HH.div
              [ HP.class_ (HH.ClassName "student-updated-at") ]
              [ HH.span_ [ HH.text createdAt.date ]
              , HH.span_ [ HH.text createdAt.time ]
              ]
          ]
      , HH.td_
          [ HH.div
              [ HP.class_ (HH.ClassName "student-row-actions") ]
              [ HH.button
                  [ HP.class_ (HH.ClassName "hour-record-copy-button")
                  , HP.attr (HH.AttrName "title") "複製到上方輸入區（不含學生）"
                  , HP.attr (HH.AttrName "aria-label") "複製這筆時數資料"
                  , HE.onClick (CopyRecord record)
                  ]
                  [ HH.text "⧉" ]
              , HH.button
                  [ HP.class_ (HH.ClassName "student-delete-button")
                  , HP.attr (HH.AttrName "title") "刪除這筆時數紀錄"
                  , HE.onClick (AskDeleteRecord record.id)
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
        [ HH.h3_ [ HH.text "確定刪除時數紀錄？" ]
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
  Receive input ->
    H.modify_
      _
        { records = input.records
        , isLoading = input.isLoading
        , loadError = input.loadError
        , selectedIds = []
        , selectionAnchor = Nothing
        }
  SelectRecord index event -> do
    state <- H.get
    case Array.index state.records index of
      Nothing -> pure unit
      Just record ->
        if MouseEvent.shiftKey event then
          case state.selectionAnchor of
            Nothing ->
              H.modify_ _ { selectedIds = [ record.id ], selectionAnchor = Just index }
            Just anchor ->
              let
                start = min anchor index
                end = max anchor index
                rangeIds = map _.id (Array.slice start (end + 1) state.records)
                selectedIds =
                  if MouseEvent.ctrlKey event || MouseEvent.metaKey event then
                    Array.nub (state.selectedIds <> rangeIds)
                  else
                    rangeIds
              in
                H.modify_ _ { selectedIds = selectedIds }
        else if MouseEvent.ctrlKey event || MouseEvent.metaKey event then
          H.modify_
            _
              { selectedIds =
                  if Array.elem record.id state.selectedIds then
                    Array.filter (_ /= record.id) state.selectedIds
                  else
                    Array.snoc state.selectedIds record.id
              , selectionAnchor = Just index
              }
        else
          H.modify_ _ { selectedIds = [ record.id ], selectionAnchor = Just index }
  CopyRecord record event -> do
    H.liftEffect (Event.stopPropagation (MouseEvent.toEvent event))
    H.raise
      ( CopyRequested
          { activityId: record.activityId
          , activityType: record.activityType
          , activityDate: record.activityDate
          , hours: record.hours
          , note: record.note
          }
      )
  AskDeleteRecord id event -> do
    H.liftEffect (Event.stopPropagation (MouseEvent.toEvent event))
    H.modify_
      _
        { selectedIds = [ id ]
        , selectionAnchor = Nothing
        , isDeleteDialogOpen = true
        }
  AskDelete -> do
    state <- H.get
    if Array.null state.selectedIds then pure unit
    else H.modify_ _ { isDeleteDialogOpen = true }
  CancelDelete -> H.modify_ _ { isDeleteDialogOpen = false }
  ConfirmDelete -> do
    state <- H.get
    H.modify_ _ { isDeleteDialogOpen = false }
    if Array.null state.selectedIds then pure unit
    else H.raise (DeleteRequested state.selectedIds)
  Retry -> H.raise RetryRequested
