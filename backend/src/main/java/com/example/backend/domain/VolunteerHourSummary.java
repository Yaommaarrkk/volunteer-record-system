package com.example.backend.domain;

import java.math.BigDecimal;

public class VolunteerHourSummary {
    private final Integer volunteerId;
    private final String volunteerName;
    private final Integer age;
    private final Integer seatRow;
    private final Integer seatCol;
    private final BigDecimal teachingHours;
    private final BigDecimal virtueHours;
    private final BigDecimal interactionHours;
    private final BigDecimal passiveHours;
    private final BigDecimal dailyInteractionHours;
    private final BigDecimal totalHours;

    public VolunteerHourSummary(
            Integer volunteerId,
            String volunteerName,
            Integer age,
            Integer seatRow,
            Integer seatCol,
            BigDecimal teachingHours,
            BigDecimal virtueHours,
            BigDecimal interactionHours,
            BigDecimal passiveHours,
            BigDecimal dailyInteractionHours,
            BigDecimal totalHours
    ) {
        this.volunteerId = volunteerId;
        this.volunteerName = volunteerName;
        this.age = age;
        this.seatRow = seatRow;
        this.seatCol = seatCol;
        this.teachingHours = teachingHours;
        this.virtueHours = virtueHours;
        this.interactionHours = interactionHours;
        this.passiveHours = passiveHours;
        this.dailyInteractionHours = dailyInteractionHours;
        this.totalHours = totalHours;
    }

    public Integer getVolunteerId() {
        return volunteerId;
    }

    public String getVolunteerName() {
        return volunteerName;
    }

    public Integer getAge() {
        return age;
    }

    public Integer getSeatRow() {
        return seatRow;
    }

    public Integer getSeatCol() {
        return seatCol;
    }

    public BigDecimal getTeachingHours() {
        return teachingHours;
    }

    public BigDecimal getVirtueHours() {
        return virtueHours;
    }

    public BigDecimal getInteractionHours() {
        return interactionHours;
    }

    public BigDecimal getPassiveHours() {
        return passiveHours;
    }

    public BigDecimal getDailyInteractionHours() {
        return dailyInteractionHours;
    }

    public BigDecimal getTotalHours() {
        return totalHours;
    }
}
