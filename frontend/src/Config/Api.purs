module Config.Api
  ( apiUrl
  ) where

import Prelude

apiBaseUrl :: String
apiBaseUrl = "http://127.0.0.1:8080"

apiUrl :: String -> String
apiUrl path = apiBaseUrl <> path