package com.example.backend.dto.request;

import com.example.backend.domain.EducationLevel;
import com.example.backend.domain.SeatPeriod;

import java.util.List;

public record CreateVolunteerRequest(
        EducationLevel educationLevel,
        String name,
        Integer age,
        List<SeatAssignmentRequest> seats
) {
    public record SeatAssignmentRequest(
            SeatPeriod period,
            SeatRequest seat
    ) {
    }

    public record SeatRequest(
            Integer row,
            Integer col
    ) {
    }
}
