package com.example.backend.dto.request;

import com.example.backend.domain.ActivityType;

import java.util.List;

public record ReorderActivitiesRequest(
        ActivityType defaultType,
        List<Integer> activityIds
) {
}
