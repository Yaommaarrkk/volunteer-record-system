package com.example.backend.domain;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class VolunteerTest {

    @Test
    void addSeat_shouldStoreSeatAssignment() {
        // Arrange：準備
        Volunteer volunteer = new Volunteer(1001, "王小明", 7);

        Volunteer.Seat seat = new Volunteer.Seat(1, 2);

        Volunteer.SeatAssignment assignment =
                new Volunteer.SeatAssignment(
                        SeatPeriod.YEAR_114_SECOND_SEMESTER,
                        seat
                );

        // Act：執行
        volunteer.addSeat(assignment);

        // Assert：檢查
        assertEquals(1, volunteer.getSeats().size());
        assertEquals(1, volunteer.getSeats().getFirst().getSeat().getRow());
        assertEquals(2, volunteer.getSeats().getFirst().getSeat().getCol());
    }

    @Test
    void addSeat_shouldStoreDifferentSeatPeriods() {
        // Arrange
        Volunteer volunteer = new Volunteer(1001, "王小明", 7);

        Volunteer.SeatAssignment semesterSeat =
                new Volunteer.SeatAssignment(
                        SeatPeriod.YEAR_114_SECOND_SEMESTER,
                        new Volunteer.Seat(1, 2)
                );

        Volunteer.SeatAssignment summerSeat =
                new Volunteer.SeatAssignment(
                        SeatPeriod.YEAR_115_SUMMER,
                        new Volunteer.Seat(3, 4)
                );

        // Act
        volunteer.addSeat(semesterSeat);
        volunteer.addSeat(summerSeat);

        // Assert
        assertEquals(2, volunteer.getSeats().size());

        assertEquals(
                SeatPeriod.YEAR_114_SECOND_SEMESTER,
                volunteer.getSeats().getFirst().getPeriod()
        );

        assertEquals(
                SeatPeriod.YEAR_115_SUMMER,
                volunteer.getSeats().getLast().getPeriod()
        );
    }
    
    @Test
    void addSeat_samePeriod_shouldThrowException() {
        // Arrange
        Volunteer volunteer = new Volunteer(1001, "王小明", 7);

        Volunteer.SeatAssignment firstSeat =
                new Volunteer.SeatAssignment(
                        SeatPeriod.YEAR_114_SECOND_SEMESTER,
                        new Volunteer.Seat(1, 2)
                );

        Volunteer.SeatAssignment duplicatePeriodSeat =
                new Volunteer.SeatAssignment(
                        SeatPeriod.YEAR_114_SECOND_SEMESTER,
                        new Volunteer.Seat(3, 4)
                );

        volunteer.addSeat(firstSeat);

        // Act
        IllegalArgumentException error =
                assertThrows(
                        IllegalArgumentException.class,
                        () -> volunteer.addSeat(duplicatePeriodSeat)
                );

        // Assert
        assertEquals(
                "同一個座位期間不能重複",
                error.getMessage()
        );

        assertEquals(1, volunteer.getSeats().size());
    }
}
