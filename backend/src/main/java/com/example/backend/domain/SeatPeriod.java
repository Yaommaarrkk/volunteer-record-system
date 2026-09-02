package com.example.backend.domain;

public enum SeatPeriod {

    YEAR_114_SECOND_SEMESTER(
            new SeatLayout(
                    new SeatPosition(1, 1),
                    new SeatPosition(5, 4)
            )
    ),

    YEAR_115_SUMMER(
            new SeatLayout(
                    new SeatPosition(1, 1),
                    new SeatPosition(5, 4)
            )
    ),

    YEAR_115_FIRST_SEMESTER(
            new SeatLayout(
                    new SeatPosition(0, 1),
                    new SeatPosition(6, 3)
            )
    );

    private final SeatLayout seatLayout;

    SeatPeriod(SeatLayout seatLayout) {
        this.seatLayout = seatLayout;
    }

    public SeatLayout seatLayout() {
        return seatLayout;
    }
}