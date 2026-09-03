module Widget.SeatTable.Selection
  ( seatLabel
  , volunteerAtSeat
  , volunteerWithGrade
  , renderEmptySeat
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Domain.Seat (Seat, SeatPeriodType)
import Domain.Volunteer (Volunteer, getGrade, seatForPeriod)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

seatLabel :: Seat -> String
seatLabel seat = show seat.row <> "-" <> show seat.col

volunteerAtSeat :: SeatPeriodType -> Seat -> Array Volunteer -> Maybe Volunteer
volunteerAtSeat period seat = Array.find (\volunteer -> seatForPeriod period volunteer == Just seat)

volunteerWithGrade :: Volunteer -> String
volunteerWithGrade volunteer = volunteer.name <> "(" <> show (getGrade volunteer) <> ")"

renderEmptySeat :: forall action slots m. Seat -> H.ComponentHTML action slots m
renderEmptySeat seat =
  HH.button
    [ HP.classes [ HH.ClassName "seat-button", HH.ClassName "seat-empty" ]
    , HP.disabled true
    ]
    [ HH.text (seatLabel seat) ]
