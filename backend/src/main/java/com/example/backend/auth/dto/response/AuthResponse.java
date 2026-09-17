package com.example.backend.auth.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class AuthResponse {

    private boolean success;
    private String message;
    private UserDto userDto;

    public AuthResponse(boolean success, String message, UserDto userDto) {
        this.success = success;
        this.message = message;
        this.userDto = userDto;
    }

    public static AuthResponse from(String message, UserDto userDto) {
        return new AuthResponse(true, message, userDto);
    }

    public static AuthResponse fromError(String errMsg) {
        return new AuthResponse(false, errMsg, null);
    }
    
    public boolean isSuccess() {
        return success;
    }

    public String getMessage() {
        return message;
    }

    public UserDto getUserDto() {
        return userDto;
    }
}
