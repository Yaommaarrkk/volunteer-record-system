package com.example.backend.dto.response;

public record Response<T>(
        boolean success,
        String message,
        T data
) {
}