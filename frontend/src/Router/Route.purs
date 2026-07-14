module Router.Route where

import Prelude hiding ((/))
import Data.Either (Either)
import Data.Generic.Rep (class Generic)
import Routing.Duplex
  ( RouteDuplex'
  , default
  , parse
  , print
  , root
  , segment
  )
import Routing.Duplex.Generic as G
import Routing.Duplex.Generic.Syntax ((/))
import Routing.Duplex.Parser (RouteError)
import Data.Show.Generic (genericShow)
import Control.Alternative ((<|>))
import Routing.Match (Match, lit, int, str, end)
import Routing.Hash (matches)

data Route
  = Home
  | MasterData MasterDataType
  | Records
  | Summary
  | NotFound String

derive instance genericRoute :: Generic Route _

derive instance eqRoute :: Eq Route

instance showRoute :: Show Route where
  show = genericShow

data MasterDataType
  = Students
  | Activities

derive instance genericMasterDataType :: Generic MasterDataType _

derive instance eqMasterDataType :: Eq MasterDataType

instance showMasterDataType :: Show MasterDataType where
  show = genericShow

masterDataTypeCodec :: RouteDuplex' MasterDataType
masterDataTypeCodec =
  G.sum
    { "Students": "students" / G.noArgs
    , "Activities": "activities" / G.noArgs
    }

routeCodec :: RouteDuplex' Route
routeCodec =
  root
    $ G.sum
        { "Home": G.noArgs
        , "MasterData": "master-data" / masterDataTypeCodec
        , "Records": "records" / G.noArgs
        , "Summary": "summary" / G.noArgs
        , "NotFound": "not-found" / segment
        }

parseRoute :: String -> Either RouteError Route
parseRoute = parse routeCodec

routeToUrl :: Route -> String
routeToUrl = print routeCodec
