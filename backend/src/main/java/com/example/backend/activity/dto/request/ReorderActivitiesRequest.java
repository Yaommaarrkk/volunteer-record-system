package com.example.backend.activity.dto.request;

import com.example.backend.activity.domain.ActivityType;

import java.util.List;

public record ReorderActivitiesRequest(
        ActivityType defaultType,
        List<Integer> activityIds
) {
}
