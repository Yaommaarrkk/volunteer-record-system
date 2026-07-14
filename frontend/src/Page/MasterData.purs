module Page.MasterData where

import Prelude
import Effect.Aff.Class (class MonadAff)
import Data.Maybe (Maybe(..))
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Router.Route (Route(..), MasterDataType(..))

type Slot id
  = forall query. H.Slot query Output id

type Slots
  = ()

type Input
  = MasterDataType

type State
  = { masterDataType :: MasterDataType
    }

data Action
  = Receive Input
  | NoOp

data Output
  = OutputUnit

initialState :: Input -> State
initialState input = { masterDataType: input }

component :: forall query m. MonadAff m => H.Component query Input Output m
component =
  H.mkComponent
    { initialState
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { handleAction = handleAction
            , receive = Just <<< Receive
            }
    }

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render state =
  HH.main_
    [ HH.h1_
        [ HH.text case state.masterDataType of
            Students -> "修改學生資料"
            Activities -> "修改活動資料"
        ]
    ]

handleAction = case _ of
  Receive masterDataType -> H.modify_ _ { masterDataType = masterDataType }
  NoOp -> pure unit
