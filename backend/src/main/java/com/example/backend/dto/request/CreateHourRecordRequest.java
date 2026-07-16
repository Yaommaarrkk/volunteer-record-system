package com.example.backend.dto.request;

import com.example.backend.domain.ActivityType;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record CreateHourRecordRequest(
        Integer activityId,
        ActivityType activityType,
        LocalDate activityDate,
        BigDecimal hours,
        String note,
        List<Integer> volunteerIds
) {
}
