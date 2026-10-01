package com.example.backend.student.dto.request;

public record UpdateVolunteerBirthdayRequest(
        Integer birthdayMonth,
        Integer birthdayDay
) {
}
