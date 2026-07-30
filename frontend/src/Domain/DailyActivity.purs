module Domain.DailyActivity
  ( DailyActivity
  ) where

type DailyActivity =
  { activityDate :: String
  , description :: String
  , updatedAt :: String
  }
