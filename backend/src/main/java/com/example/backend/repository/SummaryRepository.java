package com.example.backend.repository;

import com.example.backend.domain.DailyHourTotal;
import com.example.backend.domain.ActivityType;
import com.example.backend.domain.VolunteerHourSummary;
import com.example.backend.dto.response.ActivityRankingResponse;
import com.example.backend.dto.response.VolunteerHourDetailResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

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
                    resultSet.getBigDecimal("total_hours"),
                    resultSet.getString("daily_activity_description")
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
                hour_record.activity_date,
                SUM(hour_record.hours) AS total_hours,
                daily_activity.description AS daily_activity_description
            FROM hour_record
            LEFT JOIN daily_activity
              ON daily_activity.activity_date = hour_record.activity_date
            GROUP BY
                hour_record.activity_date,
                daily_activity.description
            ORDER BY hour_record.activity_date
            """;

        return jdbcTemplate.query(sql, DAILY_HOUR_TOTAL_ROW_MAPPER);
    }

    public List<ActivityRankingResponse> getActivityRankings() {
        String sql = """
            WITH volunteer_activity_totals AS (
                SELECT
                    hour_record.activity_type,
                    activity.id AS activity_id,
                    activity.name AS activity_name,
                    activity.sort_order,
                    volunteer.id AS volunteer_id,
                    volunteer.name AS volunteer_name,
                    SUM(hour_record.hours) AS hours
                FROM hour_record
                JOIN activity ON activity.id = hour_record.activity_id
                JOIN volunteer ON volunteer.id = hour_record.volunteer_id
                GROUP BY
                    hour_record.activity_type,
                    activity.id,
                    activity.name,
                    activity.sort_order,
                    volunteer.id,
                    volunteer.name
            ),
            ranked_volunteers AS (
                SELECT
                    *,
                    ROW_NUMBER() OVER (
                        PARTITION BY activity_type, activity_id
                        ORDER BY hours DESC, volunteer_id
                    ) AS rank_number
                FROM volunteer_activity_totals
            )
            SELECT
                activity_type,
                activity_id,
                activity_name,
                sort_order,
                volunteer_id,
                volunteer_name,
                hours
            FROM ranked_volunteers
            WHERE rank_number <= 5
            ORDER BY
                CASE activity_type
                    WHEN 'TEACHING' THEN 1
                    WHEN 'COMPANION_READING' THEN 2
                    WHEN 'PLAY' THEN 3
                    WHEN 'DAILY_INTERACTION' THEN 4
                    WHEN 'PASSIVE' THEN 5
                    ELSE 6
                END,
                sort_order,
                activity_id,
                rank_number
            """;

        List<ActivityRankingRow> rows = jdbcTemplate.query(
                sql,
                (resultSet, rowNumber) -> new ActivityRankingRow(
                        ActivityType.valueOf(resultSet.getString("activity_type")),
                        resultSet.getInt("activity_id"),
                        resultSet.getString("activity_name"),
                        resultSet.getInt("sort_order"),
                        resultSet.getInt("volunteer_id"),
                        resultSet.getString("volunteer_name"),
                        resultSet.getBigDecimal("hours")
                )
        );

        Map<Integer, ActivityRankingResponse> rankingsByActivityId = new LinkedHashMap<>();
        for (ActivityRankingRow row : rows) {
            ActivityRankingResponse ranking = rankingsByActivityId.computeIfAbsent(
                    row.activityId(),
                    activityId -> new ActivityRankingResponse(
                            row.activityType(),
                            activityId,
                            row.activityName(),
                            row.sortOrder(),
                            new ArrayList<>()
                    )
            );
            ranking.topVolunteers().add(
                    new ActivityRankingResponse.RankedVolunteer(
                            row.volunteerId(),
                            row.volunteerName(),
                            row.hours()
                    )
            );
        }

        return new ArrayList<>(rankingsByActivityId.values());
    }

    public VolunteerHourDetailResponse getVolunteerHourDetail(Integer volunteerId) {
        String activitySql = """
            SELECT
                activity.name AS activity_name,
                hour_record.activity_type,
                SUM(hour_record.hours) AS hours
            FROM hour_record
            JOIN activity ON activity.id = hour_record.activity_id
            WHERE hour_record.volunteer_id = ?
            GROUP BY activity.name, hour_record.activity_type
            ORDER BY SUM(hour_record.hours) DESC, activity.name
            """;

        List<VolunteerHourDetailResponse.ActivityHourTotal> activities =
                jdbcTemplate.query(
                        activitySql,
                        (resultSet, rowNumber) ->
                                new VolunteerHourDetailResponse.ActivityHourTotal(
                                        resultSet.getString("activity_name"),
                                        ActivityType.valueOf(resultSet.getString("activity_type")),
                                        resultSet.getBigDecimal("hours")
                                ),
                        volunteerId
                );

        String recentRecordSql = """
            SELECT
                hour_record.activity_date,
                activity.name AS activity_name,
                hour_record.activity_type,
                hour_record.hours,
                hour_record.note
            FROM hour_record
            JOIN activity ON activity.id = hour_record.activity_id
            WHERE hour_record.volunteer_id = ?
            ORDER BY hour_record.activity_date DESC, hour_record.id DESC
            LIMIT 10
            """;

        List<VolunteerHourDetailResponse.RecentHourRecord> recentRecords =
                jdbcTemplate.query(
                        recentRecordSql,
                        (resultSet, rowNumber) ->
                                new VolunteerHourDetailResponse.RecentHourRecord(
                                        resultSet.getObject("activity_date", java.time.LocalDate.class),
                                        resultSet.getString("activity_name"),
                                        ActivityType.valueOf(resultSet.getString("activity_type")),
                                        resultSet.getBigDecimal("hours"),
                                        resultSet.getString("note")
                                ),
                        volunteerId
                );

        return new VolunteerHourDetailResponse(activities, recentRecords);
    }

    private record ActivityRankingRow(
            ActivityType activityType,
            Integer activityId,
            String activityName,
            Integer sortOrder,
            Integer volunteerId,
            String volunteerName,
            java.math.BigDecimal hours
    ) {
    }
}
