package com.example.backend.domain;

public record SeatLayout(
        SeatPosition minSeat,
        SeatPosition maxSeat
) {
    public boolean contains(Integer row, Integer col) {
        return row != null
                && col != null
                && row >= minSeat.row()
                && row <= maxSeat.row()
                && col >= minSeat.col()
                && col <= maxSeat.col();
    }
}