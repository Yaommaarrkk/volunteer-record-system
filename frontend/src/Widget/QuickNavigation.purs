module Widget.QuickNavigation where

import Prelude

import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Widget.HomeMenu as HomeMenu

type Slot id = forall query. H.Slot query Output id

type Slots :: Row Type
type Slots = ()

type State =
  { dismissed :: Boolean
  }

data Action
  = Dismiss
  | Reset

data Output = OutputUnit

component :: forall query input m. MonadAff m => H.Component query input Output m
component =
  H.mkComponent
    { initialState: \_ -> { dismissed: false }
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction }
    }

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render state =
  HH.nav
    [ HP.class_ (HH.ClassName (navigationClass state.dismissed))
    , HP.attr (HH.AttrName "aria-label") "快速頁面導覽"
    , HE.onClick \_ -> Dismiss
    , HE.onMouseEnter \_ -> Reset
    ]
    [ HH.a
        [ HP.class_ (HH.ClassName "quick-navigation-trigger")
        , HP.href "#/"
        , HP.attr (HH.AttrName "aria-label") "返回首頁並顯示快速導覽"
        ]
        [ HH.span [ HP.class_ (HH.ClassName "quick-navigation-icon") ] [ HH.text "⌂" ]
        , HH.span [ HP.class_ (HH.ClassName "quick-navigation-label") ] [ HH.text "首頁" ]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "quick-navigation-panel") ]
        [ HH.p_ [ HH.text "快速前往" ]
        , HomeMenu.view HomeMenu.Compact
        ]
    ]

navigationClass :: Boolean -> String
navigationClass dismissed =
  if dismissed then
    "quick-navigation quick-navigation-dismissed"
  else
    "quick-navigation"

handleAction
  :: forall m
   . MonadAff m
  => Action
  -> H.HalogenM State Action Slots Output m Unit
handleAction = case _ of
  Dismiss -> H.modify_ _ { dismissed = true }
  Reset -> H.modify_ _ { dismissed = false }
