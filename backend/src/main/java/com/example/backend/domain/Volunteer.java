package com.example.backend.domain;

public class Volunteer {
    private Integer id;
    private String name;
    private Integer age;
    private Seat seat;

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

    public Volunteer(Integer id, String name, Integer age, Seat seat) {
        this.id = id;
        this.name = name;
        this.age = age;
        this.seat = seat;
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

    public Seat getSeat() {
        return seat;
    }
}