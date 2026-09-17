package com.example.backend.auth.dto.request;

import com.example.backend.user.domain.Role;

public record RegisterRequest(
        String username,
        String password,
        Role role
) {
}