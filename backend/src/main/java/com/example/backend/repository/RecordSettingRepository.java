package com.example.backend.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class RecordSettingRepository {
    private final JdbcTemplate jdbcTemplate;

    public RecordSettingRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Integer getDefaultYear() {
        String sql = """
            SELECT default_year
            FROM record_setting
            WHERE setting_id = 1
            """;

        return jdbcTemplate.queryForObject(sql, Integer.class);
    }

    public int updateDefaultYear(Integer year) {
        String sql = """
            UPDATE record_setting
            SET default_year = ?
            WHERE setting_id = 1
            """;

        return jdbcTemplate.update(sql, year);
    }
}
