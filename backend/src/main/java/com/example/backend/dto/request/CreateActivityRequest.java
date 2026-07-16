package com.example.backend.dto.request;

import com.example.backend.domain.ActivityType;

public record CreateActivityRequest(
        String name,
        ActivityType defaultType
) {
}
