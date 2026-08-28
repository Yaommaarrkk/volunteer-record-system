package com.example.backend.repository;

import com.example.backend.domain.ActivityType;
import com.example.backend.domain.HourRecord;
import com.example.backend.dto.request.CreateHourRecordRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Collections;

@Repository
public class HourRecordRepository {
    private final JdbcTemplate jdbcTemplate;

    private static final RowMapper<HourRecord> HOUR_RECORD_ROW_MAPPER =
            (resultSet, rowNumber) -> new HourRecord(
                    resultSet.getInt("id"),
                    resultSet.getInt("activity_id"),
                    resultSet.getString("activity_name"),
                    ActivityType.valueOf(resultSet.getString("activity_type")),
                    resultSet.getString("tag_color"),
                    resultSet.getObject("activity_date", java.time.LocalDate.class),
                    resultSet.getInt("volunteer_id"),
                    resultSet.getString("volunteer_name"),
                    resultSet.getBigDecimal("hours"),
                    resultSet.getString("note"),
                    resultSet.getTimestamp("created_at").toInstant()
            );

    public HourRecordRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean activityExists(Integer activityId) {
        String sql = """
            SELECT EXISTS (
                SELECT 1
                FROM activity
                WHERE id = ?
            )
            """;

        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(sql, Boolean.class, activityId));
    }

    public boolean volunteersExist(List<Integer> volunteerIds) {
        String sql = """
            SELECT EXISTS (
                SELECT 1
                FROM volunteer
                WHERE id = ?
            )
            """;

        return volunteerIds.stream()
                .allMatch(id -> Boolean.TRUE.equals(
                        jdbcTemplate.queryForObject(sql, Boolean.class, id)
                ));
    }

    public List<HourRecord> getPage(List<Integer> volunteerIds, List<Integer> activityIds, int offset, int limit) {
        StringBuilder sql = new StringBuilder("""
            SELECT
                hour_record.id,
                hour_record.activity_id,
                activity.name AS activity_name,
                hour_record.activity_type,
                activity_type_color.tag_color,
                hour_record.activity_date,
                hour_record.volunteer_id,
                volunteer.name AS volunteer_name,
                hour_record.hours,
                hour_record.note,
                hour_record.created_at
            FROM hour_record
            JOIN activity ON activity.id = hour_record.activity_id
            JOIN activity_type_color
              ON activity_type_color.default_type = hour_record.activity_type
            JOIN volunteer ON volunteer.id = hour_record.volunteer_id
            """);

        List<String> conditions = new ArrayList<>(); // 不含WHERE跟AND的SQL
        List<Object> params = new ArrayList<>();

        if (!volunteerIds.isEmpty()) {
            String placeholders =
                    String.join(", ", Collections.nCopies(volunteerIds.size(), "?"));

            conditions.add("hour_record.volunteer_id IN (" + placeholders + ")");
            params.addAll(volunteerIds);
        }

        if (!activityIds.isEmpty()) {
            String placeholders =
                    String.join(", ", Collections.nCopies(activityIds.size(), "?"));

            conditions.add("hour_record.activity_id IN (" + placeholders + ")");
            params.addAll(activityIds);
        }

        if (!conditions.isEmpty()) { // 如果有需要任何filter
            sql.append(" WHERE ");
            sql.append(String.join(" AND ", conditions)); // 第一個參數是分隔符 第二個是要連接的東西
        }

        params.add(limit);
        params.add(offset);

        sql.append(" ORDER BY hour_record.created_at DESC, hour_record.id DESC ");
        sql.append(" LIMIT ? OFFSET ?");


        return jdbcTemplate.query(sql.toString(), HOUR_RECORD_ROW_MAPPER, params.toArray());
    }

    public long getCount(List<Integer> volunteerIds, List<Integer> activityIds) {
        StringBuilder sql = new StringBuilder("""
            SELECT COUNT(*)
            FROM hour_record
            """);

        List<String> conditions = new ArrayList<>(); // 不含WHERE跟AND的SQL
        List<Object> params = new ArrayList<>();

        if (!volunteerIds.isEmpty()) {
            String placeholders =
                    String.join(", ", Collections.nCopies(volunteerIds.size(), "?"));

            conditions.add("volunteer_id IN (" + placeholders + ")");
            params.addAll(volunteerIds);
        }

        if (!activityIds.isEmpty()) {
            String placeholders =
                    String.join(", ", Collections.nCopies(activityIds.size(), "?"));

            conditions.add("activity_id IN (" + placeholders + ")");
            params.addAll(activityIds);
        }

        if (!conditions.isEmpty()) { // 如果有需要任何filter
            sql.append(" WHERE ");
            sql.append(String.join(" AND ", conditions)); // 第一個參數是分隔符 第二個是要連接的東西
        }

        Long count = jdbcTemplate.queryForObject(sql.toString(), Long.class, params.toArray());
        return count == null ? 0L : count;
    }

    @Transactional
    public int insert(CreateHourRecordRequest request, List<Integer> volunteerIds) {
        String recordSql = """
            INSERT INTO hour_record (
                activity_id,
                volunteer_id,
                activity_type,
                activity_date,
                hours,
                note
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """;

        int insertedRows = 0;
        for (Integer volunteerId : volunteerIds) {
            insertedRows += jdbcTemplate.update(
                    recordSql,
                    request.activityId(),
                    volunteerId,
                    request.activityType().name(),
                    request.activityDate(),
                    request.hours(),
                    request.note() == null ? "" : request.note().trim()
            );
        }

        return insertedRows;
    }

    @Transactional
    public int deleteByIds(List<Integer> ids) {
        String existsSql = """
            SELECT EXISTS (
                SELECT 1
                FROM hour_record
                WHERE id = ?
            )
            """;

        boolean allRecordsExist = ids.stream()
                .allMatch(id -> Boolean.TRUE.equals(
                        jdbcTemplate.queryForObject(existsSql, Boolean.class, id)
                ));

        if (!allRecordsExist) {
            return -1;
        }

        String sql = """
            DELETE FROM hour_record
            WHERE id = ?
            """;

        int deletedRows = 0;
        for (Integer id : ids) {
            deletedRows += jdbcTemplate.update(sql, id);
        }

        return deletedRows;
    }
}
