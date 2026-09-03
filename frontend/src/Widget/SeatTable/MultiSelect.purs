module Widget.SeatTable.MultiSelect
  ( renderMultiSelectSeat
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Domain.Seat (Seat, SeatPeriodType)
import Domain.Volunteer (Volunteer)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Widget.SeatTable.Selection (renderEmptySeat, volunteerAtSeat, volunteerWithGrade)

renderMultiSelectSeat :: forall action slots m. SeatPeriodType -> Array Volunteer -> Array Int -> (Int -> action) -> Seat -> H.ComponentHTML action slots m
renderMultiSelectSeat period volunteers selectedIds onToggle seat = case volunteerAtSeat period seat volunteers of
  Nothing -> renderEmptySeat seat
  Just volunteer ->
    HH.button
      [ HP.classes
          ( [ HH.ClassName "seat-button" ]
              <> if Array.elem volunteer.id selectedIds then
                  [ HH.ClassName "seat-selected" ]
                else
                  []
          )
      , HE.onClick \_ -> onToggle volunteer.id
      ]
      [ HH.strong_ [ HH.text (volunteerWithGrade volunteer) ] ]
