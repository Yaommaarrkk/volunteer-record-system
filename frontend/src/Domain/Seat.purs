module Domain.Seat
  ( Seat
  , SeatPeriodType(..)
  , SeatPeriod
  , SeatLayout
  , PodiumDirection
  , seatPeriods
  , findSeatPeriod
  , toApiValue
  , fromApiValue
  , fromApiValue_
  , displayName
  , seatsForLayout
  , seatsForPeriod
  , deltaRow
  , deltaCol
  ) where

import Prelude
import Partial.Unsafe (unsafeCrashWith)
import Data.Array as Array
import Data.Maybe (Maybe(..))

type Seat
  = { row :: Int
    , col :: Int
    }

type SeatPeriod
  = { periodType :: SeatPeriodType
    , apiValue :: String
    , displayName :: String
    , seatLayout :: SeatLayout
    }

data SeatPeriodType
  = Year114SecondSemester
  | Year115Summer
  | Year115FirstSemester

derive instance eqSeatPeriodType :: Eq SeatPeriodType

data PodiumDirection
  = Top
  | Bottom
  | Left
  | Right

type SeatLayout
  = { podiumDirection :: PodiumDirection
    , minSeat :: Seat
    , maxSeat :: Seat
    }

seatPeriods :: Array SeatPeriod
seatPeriods =
  [ { periodType: Year114SecondSemester
    , apiValue: "YEAR_114_SECOND_SEMESTER"
    , displayName: "114下"
    , seatLayout:
        { podiumDirection: Top
        , minSeat: { row: 1, col: 1 }
        , maxSeat: { row: 5, col: 4 }
        }
    }
  , { periodType: Year115Summer
    , apiValue: "YEAR_115_SUMMER"
    , displayName: "115暑假"
    , seatLayout:
        { podiumDirection: Top
        , minSeat: { row: 1, col: 1 }
        , maxSeat: { row: 5, col: 4 }
        }
    }
  , { periodType: Year115FirstSemester
    , apiValue: "YEAR_115_FIRST_SEMESTER"
    , displayName: "115上"
    , seatLayout:
        { podiumDirection: Left
        , minSeat: { row: 0, col: 1 }
        , maxSeat: { row: 6, col: 3 }
        }
    }
  ]

findSeatPeriod :: SeatPeriodType -> Maybe SeatPeriod
findSeatPeriod periodType = Array.find (\period -> period.periodType == periodType) seatPeriods

toApiValue :: SeatPeriodType -> String
toApiValue periodType = case findSeatPeriod periodType of
  Just period -> period.apiValue
  Nothing -> unsafeCrashWith "Unknown SeatPeriodType"

fromApiValue :: String -> Maybe SeatPeriodType
fromApiValue apiValue =
  map _.periodType
    $ Array.find (\period -> period.apiValue == apiValue) seatPeriods

fromApiValue_ :: String -> SeatPeriodType
fromApiValue_ apiValue = case fromApiValue apiValue of
  Just periodType -> periodType
  Nothing -> Year114SecondSemester

displayName :: SeatPeriodType -> String
displayName periodType = case Array.find (\period -> period.periodType == periodType) seatPeriods of
  Just period -> period.displayName
  Nothing -> unsafeCrashWith "Unknown SeatPeriodType"

seatsForLayout :: SeatLayout -> Array Seat
seatsForLayout layout = do
  row <- Array.range layout.minSeat.row layout.maxSeat.row
  col <- Array.range layout.minSeat.col layout.maxSeat.col
  pure { row, col }

seatsForPeriod :: SeatPeriodType -> Array Seat
seatsForPeriod periodType = case findSeatPeriod periodType of
  Just period -> seatsForLayout period.seatLayout
  Nothing -> []

deltaRow :: SeatPeriodType -> Int
deltaRow periodType = case findSeatPeriod periodType of
  Just period -> period.seatLayout.maxSeat.row - period.seatLayout.minSeat.row + 1
  Nothing -> 0

deltaCol :: SeatPeriodType -> Int
deltaCol periodType = case findSeatPeriod periodType of
  Just period -> period.seatLayout.maxSeat.col - period.seatLayout.minSeat.col + 1
  Nothing -> 0
