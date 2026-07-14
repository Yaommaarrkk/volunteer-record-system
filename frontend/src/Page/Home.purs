module Page.Home where

import Prelude (Unit, pure, unit)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Widget.HomeMenu as HomeMenu

type Slot id
  = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

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
    , render: \_ -> view
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

-- Home 只負責顯示各功能入口；實際頁面會由 Router 接手。
view :: forall action slots m. H.ComponentHTML action slots m
view =
  HH.main
    [ HP.class_ (HH.ClassName "home") ]
    [ HomeMenu.view HomeMenu.Full ]

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handleAction = case _ of
  NoOp -> pure unit
