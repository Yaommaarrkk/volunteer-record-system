package com.example.backend.student.dto.response;

public class VolunteerResponse {

    private boolean success;
    private String message;

    public VolunteerResponse(boolean success, String message) {
        this.success = success;
        this.message = message;
    }

    public boolean isSuccess() {
        return success;
    }

    public String getMessage() {
        return message;
    }
}
