module Domain.Volunteer
  ( Volunteer
  , SeatAssignment
  , ageToGradeLabel
  , displayVolunteer
  , formatUpdatedAt
  , ageToGrade
  , getGrade
  , seatForPeriod
  , showSeat
  ) where

import Prelude (class Eq, map, show, (-), (==), (<>))
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Domain.Seat as Seat

type Volunteer
  = { id :: Int
    , name :: String
    , age :: Int
    , updatedAt :: String
    , seats :: Array SeatAssignment
    }

type SeatAssignment
  = { period :: String
    , seat :: Seat.Seat
    }

foreign import formatUpdatedAt ::
  String ->
  { date :: String
  , time :: String
  }

seatForPeriod :: Seat.SeatPeriodType -> Volunteer -> Maybe Seat.Seat
seatForPeriod periodType volunteer =
  map _.seat
    (Array.find (\assignment -> assignment.period == Seat.toApiValue periodType) volunteer.seats)

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

ageToGrade :: Int -> Int
ageToGrade age = age - 6

getGrade :: Volunteer -> Int
getGrade volunteer = ageToGrade volunteer.age

showSeat :: Maybe Seat.Seat -> String
showSeat = case _ of
  Just seat -> show seat.row <> "-" <> show seat.col
  Nothing -> "-"

displayVolunteer :: Seat.SeatPeriodType -> Volunteer -> String
displayVolunteer period volunteer =
  volunteer.name
    <> " ("
    <> Seat.displayName period
    <> ", grade "
    <> show (getGrade volunteer)
    <> ", seat "
    <> showSeat (seatForPeriod period volunteer)
    <> ")"
