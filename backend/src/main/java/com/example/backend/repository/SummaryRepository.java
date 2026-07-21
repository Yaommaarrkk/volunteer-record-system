package com.example.backend.repository;

import com.example.backend.domain.DailyHourTotal;
import com.example.backend.domain.VolunteerHourSummary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class SummaryRepository {
    private final JdbcTemplate jdbcTemplate;

    private static final RowMapper<VolunteerHourSummary> VOLUNTEER_HOUR_SUMMARY_ROW_MAPPER =
            (resultSet, rowNumber) -> new VolunteerHourSummary(
                    resultSet.getInt("volunteer_id"),
                    resultSet.getString("volunteer_name"),
                    resultSet.getInt("age"),
                    (Integer) resultSet.getObject("seat_row"),
                    (Integer) resultSet.getObject("seat_col"),
                    resultSet.getBigDecimal("teaching_hours"),
                    resultSet.getBigDecimal("virtue_hours"),
                    resultSet.getBigDecimal("interaction_hours"),
                    resultSet.getBigDecimal("passive_hours"),
                    resultSet.getBigDecimal("daily_interaction_hours"),
                    resultSet.getBigDecimal("total_hours")
            );

    private static final RowMapper<DailyHourTotal> DAILY_HOUR_TOTAL_ROW_MAPPER =
            (resultSet, rowNumber) -> new DailyHourTotal(
                    resultSet.getObject("activity_date", java.time.LocalDate.class),
                    resultSet.getBigDecimal("total_hours")
            );

    public SummaryRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<VolunteerHourSummary> getVolunteerHourSummaries() {
        String sql = """
            SELECT
                volunteer.id AS volunteer_id,
                volunteer.name AS volunteer_name,
                volunteer.age,
                volunteer_seat.seat_row,
                volunteer_seat.seat_col,
                COALESCE(SUM(CASE
                    WHEN hour_record.activity_type = 'TEACHING'
                     AND activity.name NOT IN ('品格教育', '討論', '深聊')
                    THEN hour_record.hours ELSE 0
                END), 0) AS teaching_hours,
                COALESCE(SUM(CASE
                    WHEN activity.name IN ('品格教育', '討論', '深聊')
                    THEN hour_record.hours ELSE 0
                END), 0) AS virtue_hours,
                COALESCE(SUM(CASE
                    WHEN hour_record.activity_type IN (
                        'COMPANION_READING',
                        'PLAY',
                        'DAILY_INTERACTION'
                    )
                    THEN hour_record.hours ELSE 0
                END), 0) AS interaction_hours,
                COALESCE(SUM(CASE
                    WHEN hour_record.activity_type = 'PASSIVE'
                     AND activity.name <> '旁聽訓話'
                    THEN hour_record.hours ELSE 0
                END), 0) AS passive_hours,
                COALESCE(SUM(CASE
                    WHEN hour_record.activity_type = 'DAILY_INTERACTION'
                    THEN hour_record.hours ELSE 0
                END), 0) AS daily_interaction_hours,
                COALESCE(SUM(hour_record.hours), 0) AS total_hours
            FROM volunteer
            LEFT JOIN volunteer_seat
              ON volunteer_seat.volunteer_id = volunteer.id
             AND volunteer_seat.period = 'YEAR_114_SECOND_SEMESTER'
            LEFT JOIN hour_record
              ON hour_record.volunteer_id = volunteer.id
            LEFT JOIN activity
              ON activity.id = hour_record.activity_id
            GROUP BY
                volunteer.id,
                volunteer.name,
                volunteer.age,
                volunteer_seat.seat_row,
                volunteer_seat.seat_col
            ORDER BY
                CASE
                    WHEN volunteer_seat.seat_row IS NULL
                      OR volunteer_seat.seat_col IS NULL THEN 1
                    ELSE 0
                END,
                volunteer_seat.seat_row,
                volunteer_seat.seat_col,
                volunteer.id
            """;

        return jdbcTemplate.query(sql, VOLUNTEER_HOUR_SUMMARY_ROW_MAPPER);
    }

    public List<DailyHourTotal> getDailyHourTotals() {
        String sql = """
            SELECT
                activity_date,
                SUM(hours) AS total_hours
            FROM hour_record
            GROUP BY activity_date
            ORDER BY activity_date
            """;

        return jdbcTemplate.query(sql, DAILY_HOUR_TOTAL_ROW_MAPPER);
    }
}
