package com.example.backend.repository;

import com.example.backend.domain.Activity;
import com.example.backend.domain.ActivityType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;

@Repository
public class ActivityRepository {
    private final JdbcTemplate jdbcTemplate;

    private static final RowMapper<Activity> ACTIVITY_ROW_MAPPER =
            (resultSet, rowNumber) -> new Activity(
                    resultSet.getInt("id"),
                    resultSet.getString("name"),
                    ActivityType.valueOf(resultSet.getString("default_type")),
                    resultSet.getInt("sort_order"),
                    resultSet.getString("tag_color"),
                    resultSet.getTimestamp("updated_at").toInstant()
            );

    public ActivityRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Activity> getAll() {
        String sql = """
            SELECT
                activity.id,
                activity.name,
                activity.default_type,
                activity.sort_order,
                activity_type_color.tag_color,
                activity.updated_at
            FROM activity
            JOIN activity_type_color
              ON activity_type_color.default_type = activity.default_type
            ORDER BY activity.default_type, activity.sort_order, activity.id
            """;

        return jdbcTemplate.query(sql, ACTIVITY_ROW_MAPPER);
    }

    public int insert(String name, ActivityType defaultType) {
        String sql = """
            INSERT INTO activity (name, default_type, sort_order)
            VALUES (
                ?,
                ?,
                (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM activity WHERE default_type = ?)
            )
            """;

        return jdbcTemplate.update(
                sql,
                name,
                defaultType.name(),
                defaultType.name()
        );
    }

    @Transactional
    public int deleteById(Integer id) {
        ActivityType defaultType = findTypeById(id);
        if (defaultType == null) {
            return 0;
        }

        String sql = """
            DELETE FROM activity
            WHERE id = ?
            """;

        int deletedRows = jdbcTemplate.update(sql, id);
        normalizeOrder(defaultType);
        return deletedRows;
    }

    public int updateName(Integer id, String name) {
        String sql = """
            UPDATE activity
            SET name = ?
            WHERE id = ?
            """;

        return jdbcTemplate.update(sql, name, id);
    }

    @Transactional
    public int updateDefaultType(Integer id, ActivityType defaultType) {
        ActivityType oldType = findTypeById(id);
        if (oldType == null) {
            return 0;
        }

        if (oldType == defaultType) {
            return 1;
        }

        String sql = """
            UPDATE activity
            SET
                default_type = ?,
                sort_order = (
                    SELECT COALESCE(MAX(sort_order), 0) + 1
                    FROM activity
                    WHERE default_type = ?
                )
            WHERE id = ?
            """;

        int updatedRows = jdbcTemplate.update(
                sql,
                defaultType.name(),
                defaultType.name(),
                id
        );
        normalizeOrder(oldType);
        return updatedRows;
    }

    @Transactional
    public boolean reorder(ActivityType defaultType, List<Integer> orderedIds) {
        String selectSql = """
            SELECT id
            FROM activity
            WHERE default_type = ?
            ORDER BY sort_order, id
            """;

        List<Integer> currentIds = jdbcTemplate.queryForList(
                selectSql,
                Integer.class,
                defaultType.name()
        );

        if (orderedIds == null
                || currentIds.size() != orderedIds.size()
                || !new HashSet<>(currentIds).equals(new HashSet<>(orderedIds))) {
            return false;
        }

        String updateSql = """
            UPDATE activity
            SET sort_order = ?
            WHERE id = ? AND default_type = ?
            """;

        for (int index = 0; index < orderedIds.size(); index++) {
            jdbcTemplate.update(
                    updateSql,
                    index + 1,
                    orderedIds.get(index),
                    defaultType.name()
            );
        }

        return true;
    }

    public int updateTypeColor(ActivityType defaultType, String tagColor) {
        String sql = """
            UPDATE activity_type_color
            SET tag_color = ?
            WHERE default_type = ?
            """;

        return jdbcTemplate.update(sql, tagColor, defaultType.name());
    }

    private ActivityType findTypeById(Integer id) {
        String sql = """
            SELECT default_type
            FROM activity
            WHERE id = ?
            """;

        List<String> types = jdbcTemplate.queryForList(sql, String.class, id);
        if (types.isEmpty()) {
            return null;
        }

        return ActivityType.valueOf(types.getFirst());
    }

    private void normalizeOrder(ActivityType defaultType) {
        String sql = """
            WITH ranked_activity AS (
                SELECT
                    id,
                    ROW_NUMBER() OVER (ORDER BY sort_order, id) AS new_sort_order
                FROM activity
                WHERE default_type = ?
            )
            UPDATE activity
            SET sort_order = ranked_activity.new_sort_order
            FROM ranked_activity
            WHERE activity.id = ranked_activity.id
            """;

        jdbcTemplate.update(sql, defaultType.name());
    }
}
