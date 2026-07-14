package com.example.backend.util;

import com.example.backend.dto.response.Response;

public final class ApiResponse {

    private ApiResponse() {}

    public static <T> Response<T> success(T data) {
        return new Response<>(true, "成功", data);
    }

    public static <T> Response<T> success(String message, T data) {
        return new Response<>(true, message, data);
    }

    public static <T> Response<T> fail(String message) {
        return new Response<>(false, message, null);
    }
}