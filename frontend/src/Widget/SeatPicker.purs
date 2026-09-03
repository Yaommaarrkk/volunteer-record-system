module Widget.SeatPicker
  ( renderSeatPickerLayout
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe)
import Domain.Seat (PodiumDirection(..), Seat, SeatPeriodType, deltaCol, podiumDirectionForPeriod, seatsForPeriod)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

renderSeatPickerLayout :: forall action slots m. SeatPeriodType -> Maybe action -> Maybe action -> String -> (Seat -> H.ComponentHTML action slots m) -> H.ComponentHTML action slots m
renderSeatPickerLayout period confirmAction clearAction confirmLabel renderSeat =
  HH.div
    [ HP.classes
        [ HH.ClassName "seat-layout"
        , HH.ClassName (directionClass (podiumDirectionForPeriod period))
        ]
    ]
    [ renderSeatGrid period renderSeat
    , renderSeatStage period confirmAction clearAction confirmLabel
    ]

renderStageAction :: forall action slots m. String -> String -> action -> H.ComponentHTML action slots m
renderStageAction className label action =
  HH.button
    [ HP.class_ (HH.ClassName className)
    , HE.onClick \_ -> action
    ]
    [ HH.text label ]

renderSeatStage :: forall action slots m. SeatPeriodType -> Maybe action -> Maybe action -> String -> H.ComponentHTML action slots m
renderSeatStage period confirmAction clearAction confirmLabel =
  HH.div
    [ HP.class_ (HH.ClassName "seat-stage") ]
    [ HH.span
        [ HP.class_ (HH.ClassName "seat-stage-button") ]
        [ HH.text "講台" ]
    , HH.div
        [ HP.class_ (HH.ClassName "seat-stage-actions") ]
        ( Array.catMaybes
            [ map (renderStageAction "seat-confirm-button" confirmLabel) confirmAction
            , map (renderStageAction "seat-clear-button" "清除") clearAction
            ]
        )
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
