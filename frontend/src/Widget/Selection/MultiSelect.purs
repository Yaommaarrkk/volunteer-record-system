module Widget.Selection.MultiSelect
  ( renderMultiSelect
  ) where

import Prelude
import Data.Array as Array
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

type MultiSelectConfig item action
  = { items :: Array item
    , selectedIds :: Array Int
    , itemId :: item -> Int
    , renderLabel :: item -> String
    , onToggle :: Int -> action
    }

renderMultiSelect :: forall item action slots m. MultiSelectConfig item action -> H.ComponentHTML action slots m
renderMultiSelect config =
  HH.div
    [ HP.class_ (HH.ClassName "other-students-picker") ]
    if Array.null config.items then
      [ HH.p_ [ HH.text "沒有其他學生" ] ]
    else
      map renderOption config.items
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
        [ HH.text (config.renderLabel item) ]
