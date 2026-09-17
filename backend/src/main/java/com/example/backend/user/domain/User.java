package com.example.backend.user.domain;

import java.time.Instant;

public class User {
    private long id;
    private String username;
    private String passwordHash;
    private Role role;
    private Instant createdAt; // 後端存台灣時間 DB存不分時區

    public User(long id, String username, String passwordHash, Role role) {
        this(id, username, passwordHash, role, null);
    }

    public User(long id, String username, String passwordHash, Role role, Instant createdAt) {
        this.id = id;
        this.username = username;
        this.passwordHash = passwordHash;
        this.role = role;
        this.createdAt = createdAt;
    }

    public long getId() {
        return id;
    }

    public String getUsername() {
        return username;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public Role getRole() {
        return role;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }
}
