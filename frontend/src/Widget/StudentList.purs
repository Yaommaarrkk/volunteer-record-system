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
  , sortMode :: SortMode
  }

data SortMode
  = SortBySeat
  | SortByAge
  | SortByUpdatedAt

derive instance eqSortMode :: Eq SortMode

data Action
  = Receive Input
  | Retry
  | Delete Int
  | SelectSeatPeriod SeatPeriod
  | SelectSortMode SortMode

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
        , sortMode: SortBySeat
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
        [ HP.class_ (HH.ClassName "student-list-controls") ]
        [ HH.div
            [ HP.class_ (HH.ClassName "list-control-group") ]
            [ HH.span [ HP.class_ (HH.ClassName "list-control-title") ] [ HH.text "座位顯示" ]
            , HH.div
                [ HP.class_ (HH.ClassName "list-radio-options") ]
                [ seatPeriodRadio "114下" Year114SecondSemester state.selectedSeatPeriod
                , seatPeriodRadio "115暑假" Year115Summer state.selectedSeatPeriod
                ]
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "list-control-group") ]
            [ HH.span [ HP.class_ (HH.ClassName "list-control-title") ] [ HH.text "排序方式" ]
            , HH.div
                [ HP.class_ (HH.ClassName "list-radio-options") ]
                [ sortModeRadio "座位" SortBySeat state.sortMode
                , sortModeRadio "年齡" SortByAge state.sortMode
                , sortModeRadio "最後修改時間" SortByUpdatedAt state.sortMode
                ]
            ]
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

sortModeRadio
  :: forall m
   . String
  -> SortMode
  -> SortMode
  -> H.ComponentHTML Action Slots m
sortModeRadio label sortMode selectedSortMode =
  HH.label_
    [ HH.input
        [ HP.type_ HP.InputRadio
        , HP.name "student-list-sort-mode"
        , HP.checked (sortMode == selectedSortMode)
        , HE.onChange \_ -> SelectSortMode sortMode
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
            , HH.tbody_
                (map (renderVolunteer state.selectedSeatPeriod) (sortedVolunteers state))
            ]
        ]

sortedVolunteers :: State -> Array Volunteer
sortedVolunteers state =
  Array.sortBy (compareVolunteers state.sortMode state.selectedSeatPeriod) state.volunteers

compareVolunteers :: SortMode -> SeatPeriod -> Volunteer -> Volunteer -> Ordering
compareVolunteers sortMode period left right =
  case sortMode of
    SortBySeat ->
      withNameFallback
        (compareMaybeSeat (seatForPeriod period left) (seatForPeriod period right))
        left
        right
    SortByAge ->
      withNameFallback (compare left.age right.age) left right
    SortByUpdatedAt ->
      withNameFallback (compare right.updatedAt left.updatedAt) left right

withNameFallback :: Ordering -> Volunteer -> Volunteer -> Ordering
withNameFallback ordering left right = case ordering of
  EQ -> compare left.name right.name
  _ -> ordering

compareMaybeSeat :: Maybe { row :: Int, col :: Int } -> Maybe { row :: Int, col :: Int } -> Ordering
compareMaybeSeat left right = case left, right of
  Nothing, Nothing -> EQ
  Nothing, Just _ -> GT
  Just _, Nothing -> LT
  Just leftSeat, Just rightSeat -> case compare leftSeat.row rightSeat.row of
    EQ -> compare leftSeat.col rightSeat.col
    ordering -> ordering

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
  SelectSortMode sortMode -> H.modify_ _ { sortMode = sortMode }
