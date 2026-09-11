package com.example.backend.summary.dto.response;

import com.example.backend.activity.domain.ActivityType;

import java.math.BigDecimal;
import java.util.List;

public record ActivityRankingResponse(
        ActivityType activityType,
        Integer activityId,
        String activityName,
        Integer sortOrder,
        List<RankedVolunteer> topVolunteers
) {
    public record RankedVolunteer(
            Integer volunteerId,
            String volunteerName,
            BigDecimal hours
    ) {
    }
}
