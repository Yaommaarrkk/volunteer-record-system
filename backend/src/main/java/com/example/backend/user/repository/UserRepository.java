package com.example.backend.user.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;
import com.example.backend.user.domain.User;
import com.example.backend.user.domain.Role;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import lombok.RequiredArgsConstructor;

@Repository
@RequiredArgsConstructor
public class UserRepository {

    private final JdbcTemplate jdbcTemplate;

    public Integer nextId() {
        String sql = """
            SELECT nextval('user_id_seq')
            """;

        Long id = jdbcTemplate.queryForObject(sql, Long.class);

        if (id == null) {
            throw new IllegalStateException("無法取得使用者流水號");
        }

        return Math.toIntExact(id);
    }

    public LocalDateTime insert(User user) {
        String sql = """
            INSERT INTO users (id, username, password_hash, role)
            VALUES (?, ?, ?, ?)
            RETURNING created_at
            """;

        return jdbcTemplate.queryForObject(
            sql,
            LocalDateTime.class, // RETURNING參數型別
            user.getId(),
            user.getUsername(),
            user.getPasswordHash(),
            user.getRole().name()
        );
    }

    private static final RowMapper<User> USER_ROW_MAPPER = (rs, rowNum) ->
        new User(
            rs.getLong("id"),
            rs.getString("username"),
            rs.getString("password_hash"),
            Role.valueOf(rs.getString("role")),
            rs.getTimestamp("created_at").toInstant()
        );

    public Optional<User> findById(long id) {
        String sql = """
            SELECT id, username, password_hash, role, created_at
            FROM users
            WHERE id = ?
            """;

        List<User> users = jdbcTemplate.query(
            sql,
            USER_ROW_MAPPER,
            id
        );

        return users.stream().findFirst();
    }

    public Optional<User> findByUsername(String username) {
        String sql = """
            SELECT id, username, password_hash, role, created_at
            FROM users
            WHERE username = ?
            """;

        List<User> users = jdbcTemplate.query(
            sql,
            USER_ROW_MAPPER,
            username
        );

        return users.stream().findFirst();
    }

    public List<User> findByRole(Role role) {
        String sql = """
            SELECT id, username, password_hash, role, created_at
            FROM users
            WHERE role = ?
            """;

        List<User> users = jdbcTemplate.query(
            sql,
            USER_ROW_MAPPER,
            role
        );

        return users;
    }

    public int save(User user) {
        String sql = """
            UPDATE users
            SET password_hash = ?,
                role = ?
            WHERE id = ?
            """;

        return jdbcTemplate.update(
            sql,
            user.getPasswordHash(),
            user.getRole().name(),
            user.getId()
        );
    }

}
