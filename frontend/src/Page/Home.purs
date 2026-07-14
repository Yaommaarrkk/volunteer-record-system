module Page.Home where

import Prelude (Unit, pure, unit)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

type Slot id
  = forall query. H.Slot query Output id

type Slots
  = ()

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
    [ HH.section
        [ HP.class_ (HH.ClassName "home-menu")
        , HP.attr (HH.AttrName "aria-label") "志工時數紀錄系統功能選單"
        ]
        [ HH.div
            [ HP.class_ (HH.ClassName "home-block home-block-stacked") ]
            [ menuButton "#/master-data/students" "修改學生資料"
            , menuButton "#/master-data/activities" "修改活動資料"
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "home-block") ]
            [ menuButton "#/records" "輸入時數條" ]
        , HH.div
            [ HP.class_ (HH.ClassName "home-block") ]
            [ menuButton "#/summary" "查看資料庫" ]
        ]
    ]

menuButton :: forall action slots m. String -> String -> H.ComponentHTML action slots m
menuButton target label =
  HH.a
    [ HP.class_ (HH.ClassName "home-button")
    , HP.href target
    ]
    [ HH.text label ]

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handleAction = case _ of
  NoOp -> pure unit
