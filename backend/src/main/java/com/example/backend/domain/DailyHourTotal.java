package com.example.backend.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

public class DailyHourTotal {
    private final LocalDate activityDate;
    private final BigDecimal totalHours;

    public DailyHourTotal(LocalDate activityDate, BigDecimal totalHours) {
        this.activityDate = activityDate;
        this.totalHours = totalHours;
    }

    public LocalDate getActivityDate() {
        return activityDate;
    }

    public BigDecimal getTotalHours() {
        return totalHours;
    }
}
