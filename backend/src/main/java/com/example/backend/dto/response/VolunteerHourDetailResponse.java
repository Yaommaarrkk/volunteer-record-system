package com.example.backend.dto.response;

import com.example.backend.domain.ActivityType;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record VolunteerHourDetailResponse(
        List<ActivityHourTotal> activities,
        List<RecentHourRecord> recentRecords
) {
    public record ActivityHourTotal(
            String activityName,
            ActivityType activityType,
            BigDecimal hours
    ) {
    }

    public record RecentHourRecord(
            LocalDate activityDate,
            String activityName,
            ActivityType activityType,
            BigDecimal hours,
            String note
    ) {
    }
}
