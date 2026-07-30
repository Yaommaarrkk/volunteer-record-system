package com.example.backend.dto.request;

import java.time.LocalDate;

public record SaveDailyActivityRequest(
        LocalDate activityDate,
        String description
) {
}
