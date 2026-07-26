package com.example.backend.dto.response;

import com.example.backend.domain.ActivityType;

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
