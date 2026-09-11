package com.example.backend.activity.dto.request;

import com.example.backend.activity.domain.ActivityType;

public record UpdateActivityTypeRequest(ActivityType defaultType) {
}
