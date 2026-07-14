module Page.Summary where

import Prelude (Unit, pure, unit)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH

type Slot id
  = forall query. H.Slot query Output id

type Slots
  = ()

type Input
  = Unit

type State
  = Unit

data Action
  = NoOp

data Output
  = OutputUnit

component :: forall query m. MonadAff m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState: \_ -> unit
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render _ = HH.main_ []

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  NoOp -> pure unit
