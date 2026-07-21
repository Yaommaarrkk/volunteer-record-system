module Domain.DailyHourTotal
  ( DailyHourTotal
  ) where

type DailyHourTotal =
  { activityDate :: String
  , totalHours :: Number
  }
