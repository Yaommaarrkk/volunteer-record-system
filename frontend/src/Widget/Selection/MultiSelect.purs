module Widget.Selection.MultiSelect
  ( renderMultiSelect
  ) where

import Prelude
import Data.Array as Array
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

type MultiSelectConfig item action slots m
  = { items :: Array item
    , selectedIds :: Array Int
    , itemId :: item -> Int
    , renderBar :: H.ComponentHTML action slots m -- 選項前的橫條
    , itemRenderFunc :: item -> H.ComponentHTML action slots m
    , onToggle :: Int -> action
    , noItemsLabel :: String
    }

renderMultiSelect :: forall item action slots m. MultiSelectConfig item action slots m -> H.ComponentHTML action slots m
renderMultiSelect config =
  HH.div
    [ HP.class_ (HH.ClassName "other-students-picker") ]
    ( [ config.renderBar ]
        <> if Array.null config.items then
            [ HH.p_ [ HH.text config.noItemsLabel ] ]
          else
            map renderOption config.items
    )
  where
  renderOption item =
    let
      id = config.itemId item
    in
      HH.button
        [ HP.classes
            ( [ HH.ClassName "participant-unseated-option" ]
                <> if Array.elem id config.selectedIds then
                    [ HH.ClassName "participant-unseated-option-selected" ]
                  else
                    []
            )
        , HE.onClick \_ -> config.onToggle id
        ]
        [ config.itemRenderFunc item ]
