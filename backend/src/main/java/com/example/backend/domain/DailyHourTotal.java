package com.example.backend.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

public class DailyHourTotal {
    private final LocalDate activityDate;
    private final BigDecimal totalHours;
    private final String dailyActivityDescription;

    public DailyHourTotal(
            LocalDate activityDate,
            BigDecimal totalHours,
            String dailyActivityDescription
    ) {
        this.activityDate = activityDate;
        this.totalHours = totalHours;
        this.dailyActivityDescription = dailyActivityDescription;
    }

    public LocalDate getActivityDate() {
        return activityDate;
    }

    public BigDecimal getTotalHours() {
        return totalHours;
    }

    public String getDailyActivityDescription() {
        return dailyActivityDescription;
    }
}
