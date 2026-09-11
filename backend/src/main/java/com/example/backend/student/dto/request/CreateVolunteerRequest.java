package com.example.backend.student.dto.request;

import com.example.backend.student.domain.EducationLevel;
import com.example.backend.student.domain.SeatPeriod;

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
