module Widget.HourRecord.ParticipantField
  ( ParticipantFieldConfig
  , renderParticipantField
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Domain.Seat (SeatPeriodType, seatPeriods, toApiValue)
import Domain.Volunteer (Volunteer, seatForPeriod)
import Domain.StageAction (StageAction)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Widget.SeatPicker (renderSeatPickerLayout)
import Widget.Selection.MultiSelect (renderMultiSelect)
import Widget.SeatTable.MultiSelect (renderMultiSelectSeat)
import Widget.SeatTable.Selection (volunteerWithGrade)

type ParticipantFieldConfig action
  = { selectionTriggerLabel :: String
    , volunteers :: Array Volunteer
    , selectedParticipantIds :: Array Int
    , draftParticipantIds :: Array Int
    , selectedSeatPeriod :: SeatPeriodType
    , isSeatPickerOpen :: Boolean
    , isOtherStudentsOpen :: Boolean
    , participantError :: Maybe String
    , selectedNames :: String
    , onToggleSeatPicker :: action
    , onSelectSeatPeriod :: String -> action
    , onToggleOtherParticipants :: action
    , onToggleDraftParticipants :: Int -> action
    , seatStageActions :: Array (StageAction action)
    }

renderParticipantField :: forall action slots m. ParticipantFieldConfig action -> H.ComponentHTML action slots m
renderParticipantField config =
  let
    volunteersWithoutSeat =
      config.volunteers
        # Array.filter
            ( \volunteer -> case seatForPeriod config.selectedSeatPeriod volunteer of
                Nothing -> true
                Just _ -> false
            )

    seatPeriodOption period =
      HH.option
        [ HP.value period.apiValue ]
        [ HH.text period.displayName ]
  in
    HH.div
      [ HP.classes
          if config.isSeatPickerOpen then
            [ HH.ClassName "seat-picker-open" ]
          else
            []
              <> if config.participantError /= Nothing then
                  [ HH.ClassName "students-field-error" ] -- 只會生效於.student-form-card
                else
                  []
      ]
      [ HH.button
          [ HP.class_ (HH.ClassName "seat-picker-trigger")
          , HE.onClick \_ -> config.onToggleSeatPicker
          ]
          [ HH.span
              [ HP.class_ (HH.ClassName "selection-trigger-label")
              , HP.attr (HH.AttrName "title") config.selectedNames
              ]
              [ HH.text
                  if Array.null config.selectedParticipantIds then
                    config.selectionTriggerLabel
                  else
                    config.selectedNames
              ]
          ]
      , renderFieldError config.participantError
      , HH.div
          [ HP.class_ (HH.ClassName "seat-picker hour-record-seat-picker") ]
          [ HH.label
              [ HP.class_ (HH.ClassName "seat-bar") ]
              [ HH.div
                  [ HP.class_ (HH.ClassName "seat-period-select") ]
                  [ HH.span_ [ HH.text "選學期" ]
                  , HH.select
                      [ HP.value (toApiValue config.selectedSeatPeriod)
                      , HE.onValueChange config.onSelectSeatPeriod
                      ]
                      (map seatPeriodOption seatPeriods)
                  ]
              , HH.div
                  [ HP.class_ (HH.ClassName "participant-unseated-dropdown") ]
                  [ HH.button
                      [ HP.class_ (HH.ClassName "participant-unseated-trigger")
                      , HE.onClick \_ -> config.onToggleOtherParticipants
                      ]
                      [ HH.span_ [ HH.text "其他學生" ]
                      , HH.span_ [ HH.text if config.isOtherStudentsOpen then "▴" else "▾" ]
                      ]
                  , if config.isOtherStudentsOpen then
                      renderMultiSelect
                        { items: volunteersWithoutSeat
                        , selectedIds: config.draftParticipantIds
                        , itemId: _.id
                        , renderLabel: volunteerWithGrade
                        , onToggle: config.onToggleDraftParticipants
                        }
                    else
                      HH.text ""
                  ]
              ]
          , renderSeatPickerLayout
              config.selectedSeatPeriod
              config.seatStageActions
              (renderMultiSelectSeat config.selectedSeatPeriod config.volunteers config.draftParticipantIds config.onToggleDraftParticipants)
          ]
      ]

renderFieldError :: forall action slots m. Maybe String -> H.ComponentHTML action slots m
renderFieldError = case _ of
  Nothing -> HH.text ""
  Just message -> HH.span [ HP.class_ (HH.ClassName "form-error") ] [ HH.text message ]
