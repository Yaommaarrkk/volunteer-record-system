package com.example.backend.domain;

import java.util.ArrayList;
import java.util.List;

public class Volunteer {
    private Integer id;
    private String name;
    private Integer age;
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
        this.id = id;
        this.name = name;
        this.age = age;
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

    public List<SeatAssignment> getSeats() {
        return seats;
    }

    public void addSeat(SeatAssignment seatAssignment) {
        seats.add(seatAssignment);
    }
}
