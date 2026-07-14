module Domain.Volunteer
  ( Seat
  , SeatAssignment
  , SeatPeriod(..)
  , Volunteer
  , ageToGradeLabel
  , displayVolunteer
  , getGrade
  , seatForPeriod
  , seatPeriodToApi
  , showSeat
  ) where

import Prelude (class Eq, map, show, (-), (==), (<>))
import Data.Array as Array
import Data.Maybe (Maybe(..))

type Seat
  = { row :: Int
    , col :: Int
    }

type SeatAssignment
  = { period :: String
    , seat :: Seat
    }

data SeatPeriod
  = Year114SecondSemester
  | Year115Summer

derive instance eqSeatPeriod :: Eq SeatPeriod

type Volunteer
  = { id :: Int
    , name :: String
    , age :: Int
    , updatedAt :: String
    , seats :: Array SeatAssignment
    }

seatPeriodToApi :: SeatPeriod -> String
seatPeriodToApi = case _ of
  Year114SecondSemester -> "YEAR_114_SECOND_SEMESTER"
  Year115Summer -> "YEAR_115_SUMMER"

seatForPeriod :: SeatPeriod -> Volunteer -> Maybe Seat
seatForPeriod period volunteer =
  map _.seat
    (Array.find (\assignment -> assignment.period == seatPeriodToApi period) volunteer.seats)

ageToGradeLabel :: Int -> String
ageToGradeLabel = case _ of
  5 -> "中班"
  6 -> "大班"
  7 -> "一年級"
  8 -> "二年級"
  9 -> "三年級"
  10 -> "四年級"
  11 -> "五年級"
  12 -> "六年級"
  13 -> "國一"
  14 -> "國二"
  15 -> "國三"
  _ -> "未知年級"

getGrade :: Volunteer -> Int
getGrade volunteer = volunteer.age - 6

showSeat :: Maybe Seat -> String
showSeat = case _ of
  Just seat -> show seat.row <> "-" <> show seat.col
  Nothing -> "-"

displayVolunteer :: Volunteer -> String
displayVolunteer volunteer =
  volunteer.name
    <> " (grade "
    <> show (getGrade volunteer)
    <> ", seat "
    <> showSeat (seatForPeriod Year114SecondSemester volunteer)
    <> ")"
