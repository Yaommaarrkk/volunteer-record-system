module Domain.VolunteerHourDetail
  ( ActivityHourTotal
  , RecentHourRecord
  , VolunteerHourDetail
  ) where

type ActivityHourTotal =
  { activityName :: String
  , activityType :: String
  , hours :: Number
  }

type RecentHourRecord =
  { activityDate :: String
  , activityName :: String
  , activityType :: String
  , hours :: Number
  , note :: String
  }

type VolunteerHourDetail =
  { activities :: Array ActivityHourTotal
  , recentRecords :: Array RecentHourRecord
  }
