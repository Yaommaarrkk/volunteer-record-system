module Router.Router where

import Prelude
import Data.Maybe (Maybe(..))
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Aff.Class (class MonadAff)
import Type.Proxy (Proxy(..))
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.Subscription as HS
import Halogen.VDom.Driver (runUI)
import Page.Home as HomePage
import Page.MasterData as MasterDataPage
import Page.Records as RecordsPage
import Page.Summary as SummaryPage
import Router.Route (Route(..), parseRoute)
import Routing.Hash (hashes)

_home = Proxy :: Proxy "homeSlot"

_masterData = Proxy :: Proxy "masterDataSlot"

_records = Proxy :: Proxy "recordsSlot"

_summary = Proxy :: Proxy "summarySlot"

type Slots
  = ( homeSlot :: HomePage.Slot Unit
    , masterDataSlot :: MasterDataPage.Slot Unit
    , recordsSlot :: RecordsPage.Slot Unit
    , summarySlot :: SummaryPage.Slot Unit
    )

type State
  = { route :: Route
    }

data Action
  = Initialize
  | RouteChanged Route

data Output
  = OutputUnit

initialState :: State
initialState =
  { route: Home
  }

component :: forall query input m. MonadAff m => H.Component query input Output m
component =
  H.mkComponent
    { initialState: \_ -> initialState
    , render
    , eval:
        H.mkEval
          H.defaultEval
            { initialize = Just Initialize
            , handleAction = handleAction
            }
    }

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render state = case state.route of
  Home -> HH.slot_ _home unit HomePage.component unit
  MasterData masterDataType -> HH.slot_ _masterData unit MasterDataPage.component masterDataType
  Records -> HH.slot_ _records unit RecordsPage.component unit
  Summary -> HH.slot_ _summary unit SummaryPage.component unit
  NotFound str -> HH.div_ [ HH.text ("404 Not Found: " <> str) ]

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action Slots Output m Unit
handleAction action = case action of
  Initialize -> do
    void $ H.subscribe
      $ HS.makeEmitter \emit ->
          -- 流程：matchesWith偵測到網址改變
          --   -> 用parseRoute解析網址(新舊URL -> 新舊Route)
          --   -> 新舊Route作為兩個參數傳入後交由emit行動
          -- matchesWith :: 解析網址器 -> 得到新舊route後的行為 -> Effect (Effect Unit)
          -- matchesWith :: (RouteDuplex' Route) -> (Route -> Route -> Effect Unit) -> Effect (Effect Unit)
          -- emit: 通知halogen
          -- 後來把matchesWith改成hashes
          -- 才可以錯誤處理 而不是讓matchesWith把Either當Foldable
          hashes \_ newHash -> case parseRoute newHash of
            Left _ -> emit (RouteChanged (NotFound newHash))
            Right route -> emit (RouteChanged route)
  RouteChanged route -> H.modify_ _ { route = route }

main :: Effect Unit
main = do
  -- logShow $ parseRoute "/"
  -- logShow $ parseRoute "/master-data/students"
  -- logShow $ parseRoute "/master-data/activities"
  -- logShow $ parseRoute "/records"
  -- logShow $ parseRoute "/something-invalid"
  -- logShow $ routeToUrl Home
  -- logShow $ routeToUrl (MasterData Students)
  -- logShow $ routeToUrl Summary
  HA.runHalogenAff do
    body <- HA.awaitBody
    runUI component unit body
