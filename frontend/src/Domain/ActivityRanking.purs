module Domain.ActivityRanking
  ( ActivityRanking
  , RankedVolunteer
  ) where

type RankedVolunteer =
  { volunteerId :: Int
  , volunteerName :: String
  , hours :: Number
  }

type ActivityRanking =
  { activityType :: String
  , activityId :: Int
  , activityName :: String
  , sortOrder :: Int
  , topVolunteers :: Array RankedVolunteer
  }
