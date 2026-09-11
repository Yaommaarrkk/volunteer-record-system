package com.example.backend.common.dto.response;

public record Response<T>(
        boolean success,
        String message,
        T data
) {
}