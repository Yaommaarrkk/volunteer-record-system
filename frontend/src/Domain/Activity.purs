module Domain.Activity
  ( Activity
  , ActivityType(..)
  , activityTypeFilterOptions
  , activityTypeFromApi
  , activityTypeLabel
  , activityTypeOptions
  , activityTypeToApi
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (fromMaybe)
import Data.Tuple (Tuple(..))

data ActivityType
  = Teaching
  | CompanionReading
  | Play
  | DailyInteraction
  | Passive

derive instance eqActivityType :: Eq ActivityType

activityTypeOptions :: Array (Tuple String String)
activityTypeOptions =
  [ Tuple "TEACHING" "教學"
  , Tuple "COMPANION_READING" "陪讀"
  , Tuple "PLAY" "玩樂"
  , Tuple "DAILY_INTERACTION" "日常互動"
  , Tuple "PASSIVE" "被動"
  ]

activityTypeFilterOptions :: Array (Tuple String String)
activityTypeFilterOptions =
  Array.cons (Tuple "ALL" "全部顯示") activityTypeOptions

type Activity =
  { id :: Int
  , name :: String
  , defaultType :: String
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
activityTypeLabel value =
  fromMaybe "未知類型"
    $ map
        (\(Tuple _ label) -> label)
        (Array.find (\(Tuple typeCode _) -> typeCode == value) activityTypeOptions)
