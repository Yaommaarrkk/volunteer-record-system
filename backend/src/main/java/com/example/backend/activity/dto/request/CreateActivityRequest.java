package com.example.backend.activity.dto.request;

import com.example.backend.activity.domain.ActivityType;

public record CreateActivityRequest(
        String name,
        ActivityType defaultType
) {
}
