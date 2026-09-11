package com.example.backend.dailyActivity.domain;

import java.time.Instant;
import java.time.LocalDate;

public record DailyActivity(
        LocalDate activityDate,
        String description,
        Instant updatedAt
) {
}
