module Router where

import Prelude (Unit, bind, pure, unit)
import Effect (Effect)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Halogen.VDom.Driver (runUI)

data Route
  = Home
  | MasterData
  | Records
  | Summary
  | NotFound

type State
  = { route :: Route
    }

data Action
  = NoOp

data Output
  = OutputUnit

initialState :: State
initialState =
  { route: Home
  }

component :: forall query input m. MonadAff m => H.Component query input Output m
component =
  H.mkComponent
    { initialState: \_ -> initialState
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

render :: forall m. MonadAff m => State -> H.ComponentHTML Action () m
render state =
  HH.main
    [ HP.class_ (HH.ClassName "app-shell") ]
    [ HH.h1_ [ HH.text (routeTitle state.route) ]
    , HH.p_
        [ HH.text "PureScript + Halogen frontend shell is ready." ]
    ]

routeTitle :: Route -> String
routeTitle = case _ of
  Home -> "Home"
  MasterData -> "Master Data"
  Records -> "Records"
  Summary -> "Summary"
  NotFound -> "404"

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handleAction = case _ of
  NoOp -> pure unit

main :: Effect Unit
main =
  HA.runHalogenAff do
    body <- HA.awaitBody
    runUI component unit body
