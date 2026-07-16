package com.example.backend.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

public class HourRecord {
    private final Integer id;
    private final Integer activityId;
    private final String activityName;
    private final ActivityType activityType;
    private final String tagColor;
    private final LocalDate activityDate;
    private final Integer volunteerId;
    private final String volunteerName;
    private final BigDecimal hours;
    private final String note;
    private final Instant createdAt;

    public HourRecord(
            Integer id,
            Integer activityId,
            String activityName,
            ActivityType activityType,
            String tagColor,
            LocalDate activityDate,
            Integer volunteerId,
            String volunteerName,
            BigDecimal hours,
            String note,
            Instant createdAt
    ) {
        this.id = id;
        this.activityId = activityId;
        this.activityName = activityName;
        this.activityType = activityType;
        this.tagColor = tagColor;
        this.activityDate = activityDate;
        this.volunteerId = volunteerId;
        this.volunteerName = volunteerName;
        this.hours = hours;
        this.note = note;
        this.createdAt = createdAt;
    }

    public Integer getId() {
        return id;
    }

    public Integer getActivityId() {
        return activityId;
    }

    public String getActivityName() {
        return activityName;
    }

    public ActivityType getActivityType() {
        return activityType;
    }

    public String getTagColor() {
        return tagColor;
    }

    public LocalDate getActivityDate() {
        return activityDate;
    }

    public Integer getVolunteerId() {
        return volunteerId;
    }

    public String getVolunteerName() {
        return volunteerName;
    }

    public BigDecimal getHours() {
        return hours;
    }

    public String getNote() {
        return note;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
