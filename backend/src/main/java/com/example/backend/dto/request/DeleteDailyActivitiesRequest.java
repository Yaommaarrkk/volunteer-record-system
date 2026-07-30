package com.example.backend.dto.request;

import java.time.LocalDate;
import java.util.List;

public record DeleteDailyActivitiesRequest(
        List<LocalDate> activityDates
) {
}
