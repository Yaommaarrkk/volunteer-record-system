module Widget.OutsideClick (outsideClickEmitter) where

import Prelude

import Effect (Effect)
import Halogen.Subscription as HS

foreign import subscribeOutsideClick
  :: String
  -> (Unit -> Effect Unit)
  -> Effect (Effect Unit)

outsideClickEmitter :: String -> HS.Emitter Unit
outsideClickEmitter selector =
  HS.makeEmitter (subscribeOutsideClick selector)
