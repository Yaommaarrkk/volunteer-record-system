package com.example.backend.dto.request;

import com.example.backend.domain.EducationLevel;

public record CreateVolunteerRequest(
        EducationLevel educationLevel,
        String name,
        Integer age,
        SeatRequest seat
) {
    public record SeatRequest(
            Integer row,
            Integer col
    ) {
    }
}
