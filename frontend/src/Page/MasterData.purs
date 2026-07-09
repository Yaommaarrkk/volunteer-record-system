module Page.MasterData where

import Prelude (Unit, pure, unit)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

type State
  = {}

data Action
  = NoOp

data Output
  = OutputUnit

initialState :: State
initialState = {}

component :: forall query input m. MonadAff m => H.Component query input Output m
component =
  H.mkComponent
    { initialState: \_ -> initialState
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

render :: forall m. MonadAff m => State -> H.ComponentHTML Action () m
render _ =
  HH.section
    [ HP.class_ (HH.ClassName "workspace") ]
    [ HH.h2_ [ HH.text "Master Data" ]
    , HH.p_ [ HH.text "Volunteer master data page is ready for list and form wiring." ]
    ]

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handleAction = case _ of
  NoOp -> pure unit
