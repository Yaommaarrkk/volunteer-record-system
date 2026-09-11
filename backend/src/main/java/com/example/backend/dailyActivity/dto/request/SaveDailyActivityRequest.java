package com.example.backend.dailyActivity.dto.request;

import java.time.LocalDate;

public record SaveDailyActivityRequest(
        LocalDate activityDate,
        String description
) {
}
