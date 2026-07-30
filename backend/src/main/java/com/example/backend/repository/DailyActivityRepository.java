package com.example.backend.repository;

import com.example.backend.domain.DailyActivity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Repository
public class DailyActivityRepository {
    private final JdbcTemplate jdbcTemplate;

    private static final RowMapper<DailyActivity> DAILY_ACTIVITY_ROW_MAPPER =
            (resultSet, rowNumber) -> new DailyActivity(
                    resultSet.getObject("activity_date", LocalDate.class),
                    resultSet.getString("description"),
                    resultSet.getTimestamp("updated_at").toInstant()
            );

    public DailyActivityRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<DailyActivity> getPage(int offset, int limit) {
        String sql = """
            SELECT
                activity_date,
                description,
                updated_at
            FROM daily_activity
            ORDER BY activity_date DESC
            LIMIT ?
            OFFSET ?
            """;

        return jdbcTemplate.query(sql, DAILY_ACTIVITY_ROW_MAPPER, limit, offset);
    }

    public long getCount() {
        Long count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM daily_activity",
                Long.class
        );
        return count == null ? 0L : count;
    }

    public int save(LocalDate activityDate, String description) {
        String sql = """
            INSERT INTO daily_activity (activity_date, description)
            VALUES (?, ?)
            ON CONFLICT (activity_date)
            DO UPDATE SET description = EXCLUDED.description
            """;

        return jdbcTemplate.update(sql, activityDate, description);
    }

    @Transactional
    public int deleteByDates(List<LocalDate> activityDates) {
        String existsSql = """
            SELECT EXISTS (
                SELECT 1
                FROM daily_activity
                WHERE activity_date = ?
            )
            """;

        boolean allActivitiesExist = activityDates.stream()
                .allMatch(activityDate -> Boolean.TRUE.equals(
                        jdbcTemplate.queryForObject(existsSql, Boolean.class, activityDate)
                ));
        if (!allActivitiesExist) {
            return -1;
        }

        int deletedRows = 0;
        for (LocalDate activityDate : activityDates) {
            deletedRows += jdbcTemplate.update(
                    "DELETE FROM daily_activity WHERE activity_date = ?",
                    activityDate
            );
        }
        return deletedRows;
    }
}
