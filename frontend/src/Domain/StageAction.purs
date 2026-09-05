module Domain.StageAction
  ( StageAction
  ) where

import Data.Maybe (Maybe)

type StageAction action
  = { action :: action
    , btnLabel :: String
    , class_ :: Maybe String
    }
