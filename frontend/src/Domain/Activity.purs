module Domain.Activity
  ( Activity
  , ActivityType(..)
  , activityTypeFromApi
  , activityTypeLabel
  , activityTypeToApi
  ) where

import Prelude

data ActivityType
  = Teaching
  | CompanionReading
  | Play
  | DailyInteraction
  | Passive

derive instance eqActivityType :: Eq ActivityType

type Activity =
  { id :: Int
  , name :: String
  , defaultType :: String
  , defaultNote :: String
  , sortOrder :: Int
  , tagColor :: String
  , updatedAt :: String
  }

activityTypeToApi :: ActivityType -> String
activityTypeToApi = case _ of
  Teaching -> "TEACHING"
  CompanionReading -> "COMPANION_READING"
  Play -> "PLAY"
  DailyInteraction -> "DAILY_INTERACTION"
  Passive -> "PASSIVE"

activityTypeFromApi :: String -> ActivityType
activityTypeFromApi = case _ of
  "COMPANION_READING" -> CompanionReading
  "PLAY" -> Play
  "DAILY_INTERACTION" -> DailyInteraction
  "PASSIVE" -> Passive
  _ -> Teaching

activityTypeLabel :: String -> String
activityTypeLabel = case _ of
  "TEACHING" -> "教學"
  "COMPANION_READING" -> "陪讀"
  "PLAY" -> "玩樂"
  "DAILY_INTERACTION" -> "日常互動"
  "PASSIVE" -> "被動"
  _ -> "未知類型"
