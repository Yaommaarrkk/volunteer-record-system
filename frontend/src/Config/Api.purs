module Config.Api
  ( apiUrl
  ) where

import Prelude

foreign import apiBaseUrl :: String

apiUrl :: String -> String
apiUrl path = apiBaseUrl <> path
