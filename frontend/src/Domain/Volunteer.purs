module Domain.Volunteer
  ( Seat
  , Volunteer
  , ageToGradeLabel
  , displayVolunteer
  , getGrade
  , showSeat
  ) where

import Prelude (show, (-), (<>))
import Data.Maybe (Maybe(..))

type Seat
  = { row :: Int
    , col :: Int
    }

type Volunteer
  = { id :: Int
    , name :: String
    , age :: Int
    , seat :: Maybe Seat
    }

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
    <> showSeat volunteer.seat
    <> ")"
