module Domain.VolunteerHourSummary
  ( VolunteerHourSummary
  ) where

import Data.Maybe (Maybe)

type VolunteerHourSummary =
  { volunteerId :: Int
  , volunteerName :: String
  , age :: Int
  , seatRow :: Maybe Int
  , seatCol :: Maybe Int
  , teachingHours :: Number
  , virtueHours :: Number
  , interactionHours :: Number
  , passiveHours :: Number
  , dailyInteractionHours :: Number
  , totalHours :: Number
  }
