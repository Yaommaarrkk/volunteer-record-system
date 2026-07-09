module Domain.Volunteer
  ( Seat
  , Volunteer
  , displayVolunteer
  , getGrade
  , showSeat
  ) where

import Prelude (show, (-), (<>))
import Data.DateTime (DateTime)
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
    , createdAt :: DateTime
    }

getGrade :: Volunteer -> Int
getGrade volunteer = volunteer.age - 6

showSeat :: Maybe Seat -> String
showSeat = case _ of
  Just seat -> "row " <> show seat.row <> ", col " <> show seat.col
  Nothing -> "-"

displayVolunteer :: Volunteer -> String
displayVolunteer volunteer =
  volunteer.name
    <> " (grade "
    <> show (getGrade volunteer)
    <> ", seat "
    <> showSeat volunteer.seat
    <> ")"
