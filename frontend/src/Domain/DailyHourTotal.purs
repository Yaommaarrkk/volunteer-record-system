module Domain.DailyHourTotal
  ( DailyHourTotal
  ) where

import Data.Maybe (Maybe)

type DailyHourTotal =
  { activityDate :: String
  , totalHours :: Number
  , dailyActivityDescription :: Maybe String
  }
