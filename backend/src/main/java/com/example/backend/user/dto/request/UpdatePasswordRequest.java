package com.example.backend.user.dto.request;

public record UpdatePasswordRequest(
        String oldPassword,
        String newPassword
) {}