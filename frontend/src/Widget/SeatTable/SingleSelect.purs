module Widget.SeatTable.SingleSelect
  ( renderSingleSelectSeat
  ) where

import Prelude
import Data.Maybe (Maybe(..))
import Domain.Seat (Seat)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Widget.SeatTable.Selection (seatLabel)

renderSingleSelectSeat :: forall action slots m. Maybe Seat -> (Seat -> action) -> Seat -> H.ComponentHTML action slots m
renderSingleSelectSeat selectedSeat onSelect seat =
  HH.button
    [ HP.classes
        ( [ HH.ClassName "seat-button" ]
            <> if selectedSeat == Just seat then
                [ HH.ClassName "seat-button-selected" ]
              else
                []
        )
    , HE.onClick \_ -> onSelect seat
    ]
    [ HH.text (seatLabel seat) ]
