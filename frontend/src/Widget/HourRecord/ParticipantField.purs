module Widget.HourRecord.ParticipantField
  ( ParticipantFieldConfig
  , renderParticipantField
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Domain.Seat (SeatPeriodType, seatPeriods, toApiValue)
import Domain.Volunteer (Volunteer, seatForPeriod)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Widget.SeatPicker (renderSeatPickerLayout)
import Widget.Selection.MultiSelect (renderMultiSelect)
import Widget.SeatTable.MultiSelect (renderMultiSelectSeat)
import Widget.SeatTable.Selection (volunteerWithGrade)

type ParticipantFieldConfig action
  = { volunteers :: Array Volunteer
    , selectedVolunteerIds :: Array Int
    , draftVolunteerIds :: Array Int
    , selectedSeatPeriod :: SeatPeriodType
    , isSeatPickerOpen :: Boolean
    , isOtherStudentsOpen :: Boolean
    , participantError :: Maybe String
    , selectedNames :: String
    , onToggleSeatPicker :: action
    , onSelectSeatPeriod :: String -> action
    , onToggleOtherStudents :: action
    , onToggleDraftVolunteer :: Int -> action
    , onConfirmVolunteers :: action
    , onClearDraftVolunteers :: action
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
          ( [ HH.ClassName "form-field"
            , HH.ClassName "seat-field"
            , HH.ClassName "hour-record-participant-field"
            ]
              <> if config.isSeatPickerOpen then
                  [ HH.ClassName "seat-picker-open" ]
                else
                  []
                    <> if config.participantError /= Nothing then
                        [ HH.ClassName "participant-field-error" ]
                      else
                        []
          )
      ]
      [ HH.span_ [ HH.text "參與學生" ]
      , HH.button
          [ HP.class_ (HH.ClassName "seat-picker-trigger")
          , HE.onClick \_ -> config.onToggleSeatPicker
          ]
          [ HH.span
              [ HP.class_ (HH.ClassName "selection-trigger-label")
              , HP.attr (HH.AttrName "title") config.selectedNames
              ]
              [ HH.text
                  if Array.null config.selectedVolunteerIds then
                    "選擇學生"
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
                      , HE.onClick \_ -> config.onToggleOtherStudents
                      ]
                      [ HH.span_ [ HH.text "其他學生" ]
                      , HH.span_ [ HH.text if config.isOtherStudentsOpen then "▴" else "▾" ]
                      ]
                  , if config.isOtherStudentsOpen then
                      renderMultiSelect
                        { items: volunteersWithoutSeat
                        , selectedIds: config.draftVolunteerIds
                        , itemId: _.id
                        , renderLabel: volunteerWithGrade
                        , onToggle: config.onToggleDraftVolunteer
                        }
                    else
                      HH.text ""
                  ]
              ]
          , renderSeatPickerLayout config.selectedSeatPeriod
              (Just config.onConfirmVolunteers)
              (Just config.onClearDraftVolunteers)
              "確認"
              (renderMultiSelectSeat config.selectedSeatPeriod config.volunteers config.draftVolunteerIds config.onToggleDraftVolunteer)
          ]
      ]

renderFieldError :: forall action slots m. Maybe String -> H.ComponentHTML action slots m
renderFieldError = case _ of
  Nothing -> HH.text ""
  Just message -> HH.span [ HP.class_ (HH.ClassName "form-error") ] [ HH.text message ]
