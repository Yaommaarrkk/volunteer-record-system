module Domain.HourRecord
  ( CopiedHourRecord
  , HourRecord
  ) where

type HourRecord =
  { id :: Int
  , activityId :: Int
  , activityName :: String
  , activityType :: String
  , tagColor :: String
  , activityDate :: String
  , volunteerId :: Int
  , volunteerName :: String
  , hours :: Number
  , note :: String
  , createdAt :: String
  }

type CopiedHourRecord =
  { activityId :: Int
  , activityType :: String
  , activityDate :: String
  , hours :: Number
  , note :: String
  }
