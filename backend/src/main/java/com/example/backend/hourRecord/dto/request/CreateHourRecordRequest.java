package com.example.backend.hourRecord.dto.request;

import com.example.backend.activity.domain.ActivityType;

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
