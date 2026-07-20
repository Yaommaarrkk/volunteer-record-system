module Widget.ActivityList
  ( Input
  , Output(..)
  , Slot
  , component
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String.Common as String
import Domain.Activity (Activity, activityTypeLabel)
import Domain.Volunteer (formatUpdatedAt)
import Effect.Class (class MonadEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Web.Event.Event as Event
import Web.HTML.Event.DragEvent (DragEvent)
import Web.HTML.Event.DragEvent as DragEvent
import Widget.OutsideClick as OutsideClick

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type Input =
  { activities :: Array Activity
  , isLoading :: Boolean
  , loadError :: Maybe String
  }

type State =
  { activities :: Array Activity
  , isLoading :: Boolean
  , loadError :: Maybe String
  , editingActivityId :: Maybe Int
  , editingField :: Maybe EditField
  , draftName :: String
  , draftDefaultType :: String
  , pendingDelete :: Maybe Activity
  , selectedType :: Maybe String
  , draggedActivityId :: Maybe Int
  , openColorPickerFor :: Maybe Int
  }

data EditField
  = EditingName
  | EditingDefaultType

data Action
  = Initialize
  | Receive Input
  | Retry
  | AskDelete Activity
  | CancelDelete
  | ConfirmDelete
  | ToggleActivityEdit Int
  | BeginNameEdit Activity
  | BeginTypeEdit Activity
  | SetDraftName String
  | SetDraftType String
  | SelectTypeFilter String
  | StartDragging Int
  | DragOver DragEvent
  | DropOn Int DragEvent
  | EndDragging
  | MoveToTop Int
  | MoveToBottom Int
  | ToggleColorPicker Int
  | CloseColorPicker
  | ChooseColor String String
  | CancelFieldEdit
  | SubmitName Int
  | SubmitType Int

data Output
  = RetryRequested
  | DeleteRequested Int
  | UpdateNameRequested Int String
  | UpdateTypeRequested Int String
  | ReorderRequested String (Array Int)
  | UpdateColorRequested String String

component :: forall query m. MonadEffect m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState: \input ->
        { activities: input.activities
        , isLoading: input.isLoading
        , loadError: input.loadError
        , editingActivityId: Nothing
        , editingField: Nothing
        , draftName: ""
        , draftDefaultType: "TEACHING"
        , pendingDelete: Nothing
        , selectedType: Nothing
        , draggedActivityId: Nothing
        , openColorPickerFor: Nothing
        }
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { initialize = Just Initialize
            , handleAction = handleAction
            , receive = Just <<< Receive
            }
    }

render :: forall m. State -> H.ComponentHTML Action Slots m
render state =
  HH.section
    [ HP.class_ (HH.ClassName "student-list-card") ]
    [ case state.pendingDelete of
        Nothing -> HH.text ""
        Just activity -> renderDeleteDialog activity
    , HH.div
        [ HP.class_ (HH.ClassName "list-heading") ]
        [ HH.div_
            [ HH.h2_ [ HH.text "活動清單" ]
            , HH.p_ [ HH.text "資料來源：GET /api/activities" ]
            ]
        , HH.span
            [ HP.class_ (HH.ClassName "student-count") ]
            [ HH.text
                ( show (Array.length (visibleActivities state))
                    <> " / "
                    <> show (Array.length state.activities)
                    <> " 筆活動"
                )
            ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "activity-list-filter") ]
        [ HH.label_
            [ HH.span_ [ HH.text "預設類型" ]
            , HH.select
                [ HP.value (fromMaybe "ALL" state.selectedType)
                , HE.onValueChange SelectTypeFilter
                ]
                [ activityTypeOption "ALL" "全部顯示"
                , activityTypeOption "TEACHING" "教學"
                , activityTypeOption "COMPANION_READING" "陪讀"
                , activityTypeOption "PLAY" "玩樂"
                , activityTypeOption "DAILY_INTERACTION" "日常互動"
                , activityTypeOption "PASSIVE" "被動"
                ]
            ]
        , case state.selectedType of
            Nothing -> HH.text ""
            Just _ -> HH.span_ [ HH.text "拖曳最左側把手，或使用 ⇈／⇊ 調整同類型順序" ]
        ]
    , renderActivityList state
    ]

renderActivityList :: forall m. State -> H.ComponentHTML Action Slots m
renderActivityList state
  | state.isLoading =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "正在載入活動資料…" ]
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
  | Array.null (visibleActivities state) =
      HH.div [ HP.class_ (HH.ClassName "list-status") ] [ HH.text "目前沒有符合此類型的活動資料。" ]
  | otherwise =
      HH.div
        [ HP.classes
            [ HH.ClassName "student-table-scroll"
            , HH.ClassName "activity-table-scroll"
            ]
        ]
        [ HH.table
            [ HP.classes [ HH.ClassName "student-table", HH.ClassName "activity-table" ] ]
            [ HH.thead_
                [ HH.tr_
                    ( (case state.selectedType of
                          Nothing -> []
                          Just _ -> [ HH.th_ [ HH.text "排序" ] ]
                      )
                        <> [ HH.th_ [ HH.text "編號" ]
                           , HH.th_ [ HH.text "活動名" ]
                           , HH.th_ [ HH.text "預設類型" ]
                           , HH.th_ [ HH.text "操作" ]
                           , HH.th_ [ HH.text "修改時間" ]
                           ]
                    )
                ]
            , HH.tbody_ (map (renderActivity state) (visibleActivities state))
            ]
        ]

visibleActivities :: State -> Array Activity
visibleActivities state =
  case state.selectedType of
    Nothing -> state.activities
    Just selectedType ->
      Array.sortBy
        (\left right -> compare left.sortOrder right.sortOrder)
        (Array.filter (\activity -> activity.defaultType == selectedType) state.activities)

renderActivity :: forall m. State -> Activity -> H.ComponentHTML Action Slots m
renderActivity state activity =
  let
    isEditing = state.editingActivityId == Just activity.id
    updatedAt = formatUpdatedAt activity.updatedAt
  in
    HH.tr
      [ HP.classes
          if state.draggedActivityId == Just activity.id then
            [ HH.ClassName "activity-row-dragging" ]
          else
            []
      , HE.onDragOver DragOver
      , HE.onDrop (DropOn activity.id)
      ]
      ( (case state.selectedType of
            Nothing -> []
            Just _ -> [ renderDragHandle activity.id ]
        )
          <> [ HH.td_ [ HH.text (show activity.id) ]
             , renderNameCell state isEditing activity
             , renderTypeCell state isEditing activity
             , HH.td_
          [ HH.div
              [ HP.class_ (HH.ClassName "student-row-actions") ]
              [ HH.button
                  [ HP.class_ (HH.ClassName "student-edit-button")
                  , HE.onClick \_ -> ToggleActivityEdit activity.id
                  ]
                  [ HH.text if isEditing then "完成" else "修改" ]
              , case state.selectedType of
                  Nothing -> HH.text ""
                  Just _ ->
                    iconButton "移到最上" "⇈" "activity-order-button" (MoveToTop activity.id)
              , case state.selectedType of
                  Nothing -> HH.text ""
                  Just _ ->
                    iconButton "移到最下" "⇊" "activity-order-button" (MoveToBottom activity.id)
              , HH.button
                  [ HP.class_ (HH.ClassName "student-delete-button")
                  , HE.onClick \_ -> AskDelete activity
                  ]
                  [ HH.text "刪除" ]
              ]
          ]
             , HH.td_
          [ HH.div
              [ HP.class_ (HH.ClassName "student-updated-at") ]
              [ HH.span_ [ HH.text updatedAt.date ]
              , HH.span_ [ HH.text updatedAt.time ]
              ]
          ]
             ]
      )

renderDragHandle :: forall m. Int -> H.ComponentHTML Action Slots m
renderDragHandle id =
  HH.td
    [ HP.class_ (HH.ClassName "activity-drag-cell") ]
    [ HH.span
        [ HP.class_ (HH.ClassName "activity-drag-handle")
        , HP.draggable true
        , HP.attr (HH.AttrName "role") "button"
        , HP.attr (HH.AttrName "aria-label") "拖曳活動排序"
        , HP.attr (HH.AttrName "title") "按住並上下拖曳"
        , HE.onDragStart \_ -> StartDragging id
        , HE.onDragEnd \_ -> EndDragging
        ]
        [ HH.text "⋮⋮" ]
    ]

renderNameCell :: forall m. State -> Boolean -> Activity -> H.ComponentHTML Action Slots m
renderNameCell state isEditing activity =
  HH.td_
    if isEditing && isEditingField EditingName state.editingField then
      [ HH.div
          [ HP.class_ (HH.ClassName "student-inline-editor") ]
          [ HH.input
              [ HP.class_ (HH.ClassName "student-inline-input")
              , HP.type_ HP.InputText
              , HP.value state.draftName
              , HE.onValueInput SetDraftName
              ]
          , renderEditActions "活動名" (SubmitName activity.id)
          ]
      ]
    else
      [ HH.div
          [ HP.class_ (HH.ClassName "student-editable-value") ]
          [ HH.strong_ [ HH.text activity.name ]
          , if isEditing then editIconButton "活動名" (BeginNameEdit activity)
            else HH.text ""
          ]
      ]

renderTypeCell :: forall m. State -> Boolean -> Activity -> H.ComponentHTML Action Slots m
renderTypeCell state isEditing activity =
  HH.td_
    if isEditing && isEditingField EditingDefaultType state.editingField then
      [ HH.div
          [ HP.class_ (HH.ClassName "student-inline-editor") ]
          [ HH.select
              [ HP.class_ (HH.ClassName "student-inline-input")
              , HP.value state.draftDefaultType
              , HE.onValueChange SetDraftType
              ]
              [ activityTypeOption "TEACHING" "教學"
              , activityTypeOption "COMPANION_READING" "陪讀"
              , activityTypeOption "PLAY" "玩樂"
              , activityTypeOption "DAILY_INTERACTION" "日常互動"
              , activityTypeOption "PASSIVE" "被動"
              ]
          , renderEditActions "預設類型" (SubmitType activity.id)
          ]
      ]
    else
      [ HH.div
          [ HP.class_ (HH.ClassName "student-editable-value") ]
          [ HH.div
              [ HP.class_ (HH.ClassName "activity-tag-wrapper") ]
              [ HH.button
                  [ HP.class_ (HH.ClassName "activity-type-tag")
                  , HP.style ("background-color: " <> activity.tagColor)
                  , HP.attr (HH.AttrName "aria-label") "選擇活動類型顏色"
                  , HP.attr (HH.AttrName "title") "點擊選擇顏色"
                  , HE.onClick \_ -> ToggleColorPicker activity.id
                  ]
                  [ HH.text (activityTypeLabel activity.defaultType) ]
              , if state.openColorPickerFor == Just activity.id then
                  renderColorPicker activity.defaultType activity.tagColor
                else
                  HH.text ""
              ]
          , if isEditing then editIconButton "預設類型" (BeginTypeEdit activity)
            else HH.text ""
          ]
      ]

renderColorPicker :: forall m. String -> String -> H.ComponentHTML Action Slots m
renderColorPicker defaultType selectedColor =
  HH.div
    [ HP.class_ (HH.ClassName "activity-color-picker") ]
    ( map
        (\color ->
          HH.button
            [ HP.classes
                ( [ HH.ClassName "activity-color-option" ]
                    <> if color == selectedColor then
                        [ HH.ClassName "activity-color-option-selected" ]
                      else
                        []
                )
            , HP.style ("background-color: " <> color)
            , HP.attr (HH.AttrName "aria-label") ("選擇顏色 " <> color)
            , HP.attr (HH.AttrName "title") color
            , HE.onClick \_ -> ChooseColor defaultType color
            ]
            []
        )
        tagColors
    )

tagColors :: Array String
tagColors =
  [ "#2563EB"
  , "#7C3AED"
  , "#DB2777"
  , "#DC2626"
  , "#EA580C"
  , "#CA8A04"
  , "#059669"
  , "#0891B2"
  , "#64748B"
  ]

isEditingField :: EditField -> Maybe EditField -> Boolean
isEditingField expected = case _ of
  Just EditingName -> case expected of
    EditingName -> true
    _ -> false
  Just EditingDefaultType -> case expected of
    EditingDefaultType -> true
    _ -> false
  Nothing -> false

activityTypeOption :: forall m. String -> String -> H.ComponentHTML Action Slots m
activityTypeOption value label = HH.option [ HP.value value ] [ HH.text label ]

editIconButton :: forall m. String -> Action -> H.ComponentHTML Action Slots m
editIconButton field action =
  iconButton ("編輯" <> field) "✎" "student-field-edit-button" action

renderEditActions :: forall m. String -> Action -> H.ComponentHTML Action Slots m
renderEditActions field submitAction =
  HH.span
    [ HP.class_ (HH.ClassName "student-edit-actions") ]
    [ iconButton ("取消修改" <> field) "↻" "student-edit-cancel-button" CancelFieldEdit
    , iconButton ("送出修改" <> field) "✓" "student-edit-submit-button" submitAction
    ]

iconButton :: forall m. String -> String -> String -> Action -> H.ComponentHTML Action Slots m
iconButton label icon className action =
  HH.button
    [ HP.class_ (HH.ClassName className)
    , HP.attr (HH.AttrName "aria-label") label
    , HP.attr (HH.AttrName "title") label
    , HE.onClick \_ -> action
    ]
    [ HH.text icon ]

renderDeleteDialog :: forall m. Activity -> H.ComponentHTML Action Slots m
renderDeleteDialog activity =
  HH.div_
    [ HH.div [ HP.class_ (HH.ClassName "delete-confirm-backdrop") ] []
    , HH.div
        [ HP.class_ (HH.ClassName "delete-confirm-dialog")
        , HP.attr (HH.AttrName "role") "dialog"
        , HP.attr (HH.AttrName "aria-modal") "true"
        , HP.attr (HH.AttrName "aria-labelledby") "delete-activity-confirm-title"
        ]
        [ HH.h3
            [ HP.id "delete-activity-confirm-title" ]
            [ HH.text "確定要刪除活動？" ]
        , HH.p_ [ HH.text ("即將刪除「" <> activity.name <> "」（編號 " <> show activity.id <> "）。") ]
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
  Initialize -> void $ H.subscribe (CloseColorPicker <$ OutsideClick.outsideClickEmitter ".activity-tag-wrapper")
  Receive input ->
    H.modify_
      _
        { activities = input.activities
        , isLoading = input.isLoading
        , loadError = input.loadError
        }
  Retry -> H.raise RetryRequested
  AskDelete activity -> H.modify_ _ { pendingDelete = Just activity, editingField = Nothing }
  CancelDelete -> H.modify_ _ { pendingDelete = Nothing }
  ConfirmDelete -> do
    state <- H.get
    case state.pendingDelete of
      Nothing -> pure unit
      Just activity -> do
        H.modify_ _ { pendingDelete = Nothing }
        H.raise (DeleteRequested activity.id)
  ToggleActivityEdit id ->
    H.modify_ \state ->
      if state.editingActivityId == Just id then
        state { editingActivityId = Nothing, editingField = Nothing }
      else
        state { editingActivityId = Just id, editingField = Nothing }
  BeginNameEdit activity ->
    H.modify_
      _
        { editingActivityId = Just activity.id
        , editingField = Just EditingName
        , draftName = activity.name
        }
  BeginTypeEdit activity ->
    H.modify_
      _
        { editingActivityId = Just activity.id
        , editingField = Just EditingDefaultType
        , draftDefaultType = activity.defaultType
        }
  SetDraftName name -> H.modify_ _ { draftName = name }
  SetDraftType defaultType -> H.modify_ _ { draftDefaultType = defaultType }
  SelectTypeFilter value ->
    H.modify_
      _
        { selectedType = if value == "ALL" then Nothing else Just value
        , editingActivityId = Nothing
        , editingField = Nothing
        , draggedActivityId = Nothing
        , openColorPickerFor = Nothing
        }
  StartDragging id -> H.modify_ _ { draggedActivityId = Just id, openColorPickerFor = Nothing }
  DragOver event -> H.liftEffect (Event.preventDefault (DragEvent.toEvent event))
  DropOn targetId event -> do
    H.liftEffect (Event.preventDefault (DragEvent.toEvent event))
    state <- H.get
    case state.selectedType, state.draggedActivityId of
      Just selectedType, Just draggedId -> do
        let currentIds = map _.id (visibleActivities state)
        let reorderedIds = moveId draggedId targetId currentIds
        H.modify_ _ { draggedActivityId = Nothing }
        when (reorderedIds /= currentIds)
          $ H.raise (ReorderRequested selectedType reorderedIds)
      _, _ -> H.modify_ _ { draggedActivityId = Nothing }
  EndDragging -> H.modify_ _ { draggedActivityId = Nothing }
  MoveToTop id -> do
    state <- H.get
    case state.selectedType of
      Nothing -> pure unit
      Just selectedType ->
        H.raise
          ( ReorderRequested selectedType
              ([ id ] <> Array.filter (_ /= id) (map _.id (visibleActivities state)))
          )
  MoveToBottom id -> do
    state <- H.get
    case state.selectedType of
      Nothing -> pure unit
      Just selectedType ->
        H.raise
          ( ReorderRequested selectedType
              (Array.filter (_ /= id) (map _.id (visibleActivities state)) <> [ id ])
          )
  ToggleColorPicker id ->
    H.modify_ \state ->
      state
        { openColorPickerFor =
            if state.openColorPickerFor == Just id then Nothing
            else Just id
        , editingField = Nothing
        }
  CloseColorPicker -> H.modify_ _ { openColorPickerFor = Nothing }
  ChooseColor defaultType color -> do
    H.modify_ _ { openColorPickerFor = Nothing }
    H.raise (UpdateColorRequested defaultType color)
  CancelFieldEdit -> H.modify_ _ { editingField = Nothing, openColorPickerFor = Nothing }
  SubmitName id -> do
    state <- H.get
    H.raise (UpdateNameRequested id (String.trim state.draftName))
    H.modify_ _ { editingField = Nothing }
  SubmitType id -> do
    state <- H.get
    H.raise (UpdateTypeRequested id state.draftDefaultType)
    H.modify_ _ { editingField = Nothing }
moveId :: Int -> Int -> Array Int -> Array Int
moveId draggedId targetId ids
  | draggedId == targetId = ids
  | otherwise =
      case Array.elemIndex draggedId ids, Array.elemIndex targetId ids of
        Just draggedIndex, Just targetIndex ->
          let
            withoutDragged = Array.filter (_ /= draggedId) ids
            targetIndexWithoutDragged = fromMaybe 0 (Array.elemIndex targetId withoutDragged)
            insertionIndex =
              if draggedIndex < targetIndex then targetIndexWithoutDragged + 1
              else targetIndexWithoutDragged
          in
            fromMaybe ids (Array.insertAt insertionIndex draggedId withoutDragged)
        _, _ -> ids
