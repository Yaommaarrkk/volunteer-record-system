package com.example.backend.dto.request;

import com.example.backend.domain.ActivityType;

public record UpdateActivityTypeRequest(ActivityType defaultType) {
}
