package com.example.backend.auth.dto.response;

import java.time.Instant;
import java.time.LocalDateTime;
import com.example.backend.user.domain.User;
import com.example.backend.user.domain.Role;

public class UserDto {
    private long id;
    private String username;
    private Role role;
    private Instant createdAt;

    public UserDto(Long id, String username, Role role, Instant createdAt) {
        this.id = id;
        this.username = username;
        this.role = role;
        this.createdAt = createdAt;
    }

    public static UserDto fromUser(User user) {
        return new UserDto(
            user.getId(), 
            user.getUsername(), 
            user.getRole(), 
            user.getCreatedAt()
        );
    }

    public long getId() {
        return id;
    }

    public String getUsername() {
        return username;
    }

    public Role getRole() {
        return role;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
