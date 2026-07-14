module Widget.HomeMenu where

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

data MenuSize
  = Full
  | Compact

view :: forall action slots m. MenuSize -> HH.ComponentHTML action slots m
view size =
  HH.section
    [ HP.class_ (HH.ClassName (menuClass size))
    , HP.attr (HH.AttrName "aria-label") "志工時數紀錄系統功能選單"
    ]
    [ HH.div
        [ HP.class_ (HH.ClassName "home-block home-block-stacked") ]
        [ menuButton size "#/master-data/students" "修改學生資料" "修改學" "生資料"
        , menuButton size "#/master-data/activities" "修改活動資料" "修改活" "動資料"
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "home-block") ]
        [ menuButton size "#/records" "輸入時數條" "輸入" "時數條" ]
    , HH.div
        [ HP.class_ (HH.ClassName "home-block") ]
        [ menuButton size "#/summary" "查看資料庫" "查看" "資料庫" ]
    ]

menuClass :: MenuSize -> String
menuClass = case _ of
  Full -> "home-menu"
  Compact -> "home-menu home-menu-compact"

menuButton
  :: forall action slots m
   . MenuSize
  -> String
  -> String
  -> String
  -> String
  -> HH.ComponentHTML action slots m
menuButton size target fullLabel firstLine secondLine =
  HH.a
    [ HP.class_ (HH.ClassName "home-button")
    , HP.href target
    ]
    (buttonLabel size fullLabel firstLine secondLine)

buttonLabel
  :: forall action slots m
   . MenuSize
  -> String
  -> String
  -> String
  -> Array (HH.ComponentHTML action slots m)
buttonLabel size fullLabel firstLine secondLine = case size of
  Full -> [ HH.text fullLabel ]
  Compact ->
    [ HH.span
        [ HP.class_ (HH.ClassName "compact-menu-label") ]
        [ HH.span_ [ HH.text firstLine ]
        , HH.span_ [ HH.text secondLine ]
        ]
    ]
