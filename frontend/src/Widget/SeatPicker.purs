module Widget.SeatPicker
  ( renderSeatPickerLayout
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe, fromMaybe)
import Domain.Seat (PodiumDirection(..), Seat, SeatPeriodType, deltaCol, podiumDirectionForPeriod, seatsForPeriod)
import Domain.StageAction (StageAction)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

renderSeatPickerLayout :: forall action slots m. SeatPeriodType -> Array (StageAction action) -> (Seat -> H.ComponentHTML action slots m) -> H.ComponentHTML action slots m
renderSeatPickerLayout period seatStageActions renderSeat =
  HH.div
    [ HP.classes
        [ HH.ClassName "seat-layout"
        , HH.ClassName (directionClass (podiumDirectionForPeriod period))
        ]
    ]
    [ renderSeatGrid period renderSeat
    , renderSeatStage seatStageActions
    ]

-- renderStageAction: 單一確認紐or清除紐
renderStageAction :: forall action slots m. StageAction action -> H.ComponentHTML action slots m
renderStageAction stageAction =
  HH.button
    [ HP.class_ (HH.ClassName (fromMaybe "" stageAction.class_))
    , HE.onClick \_ -> stageAction.action
    ]
    [ HH.text stageAction.btnLabel ]

renderSeatStage :: forall action slots m. Array (StageAction action) -> H.ComponentHTML action slots m
renderSeatStage seatStageActions =
  HH.div
    [ HP.class_ (HH.ClassName "seat-stage") ]
    [ HH.span
        [ HP.class_ (HH.ClassName "seat-stage-lectern") ]
        [ HH.text "講台" ]
    , HH.div
        [ HP.class_ (HH.ClassName "seat-stage-actions") ]
        (map renderStageAction seatStageActions)
    ]

renderSeatGrid :: forall action slots m. SeatPeriodType -> (Seat -> H.ComponentHTML action slots m) -> H.ComponentHTML action slots m
renderSeatGrid period renderSeat =
  HH.div
    [ HP.classes
        [ HH.ClassName "seat-grid"
        , HH.ClassName
            $ if deltaCol period == 3 then
                "seat-grid-3"
              else
                ""
        ]
    ]
    (map renderSeat (seatsForPeriod period))

directionClass :: PodiumDirection -> String
directionClass = case _ of
  Top -> "seat-layout-top"
  Bottom -> "seat-layout-bottom"
  Left -> "seat-layout-left"
  Right -> "seat-layout-right"
