package com.example.backend.domain;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

public class Volunteer {
    private Integer id;
    private String name;
    private Integer age;
    private Instant updatedAt;
    private final List<SeatAssignment> seats = new ArrayList<>();

    public static class Seat {
        private Integer row;
        private Integer col;

        public Seat(Integer row, Integer col) {
            this.row = row;
            this.col = col;
        }

        public Integer getRow() {
            return row;
        }

        public Integer getCol() {
            return col;
        }
    }

    public static class SeatAssignment {
        private final SeatPeriod period;
        private final Seat seat;

        public SeatAssignment(SeatPeriod period, Seat seat) {
            this.period = period;
            this.seat = seat;
        }

        public SeatPeriod getPeriod() {
            return period;
        }

        public Seat getSeat() {
            return seat;
        }
    }

    public Volunteer(Integer id, String name, Integer age) {
        this(id, name, age, null);
    }

    public Volunteer(Integer id, String name, Integer age, Instant updatedAt) {
        this.id = id;
        this.name = name;
        this.age = age;
        this.updatedAt = updatedAt;
    }

    public Integer getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public Integer getAge() {
        return age;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public List<SeatAssignment> getSeats() {
        return seats;
    }

    public void addSeat(SeatAssignment seatAssignment) {
        boolean periodAlreadyExists = seats.stream()
                .anyMatch(existingSeat ->
                        existingSeat.getPeriod() == seatAssignment.getPeriod()
                );

        if (periodAlreadyExists) {
            throw new IllegalArgumentException("同一個座位期間不能重複");
        }

        seats.add(seatAssignment);
    }
}
