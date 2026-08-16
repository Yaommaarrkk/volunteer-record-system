package com.example.backend.repository;

import com.example.backend.dto.response.DatabaseBackupSheet;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSetMetaData;
import java.util.ArrayList;
import java.util.List;

@Repository
public class DatabaseBackupRepository {
    private final JdbcTemplate jdbcTemplate;

    public DatabaseBackupRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<DatabaseBackupSheet> getBackupSheets() {
        return List.of(
                queryTable("volunteer", "SELECT * FROM volunteer ORDER BY id"),
                queryTable(
                        "volunteer_seat",
                        "SELECT * FROM volunteer_seat ORDER BY volunteer_id, period"
                ),
                queryTable("activity", "SELECT * FROM activity ORDER BY id"),
                queryTable(
                        "activity_type_color",
                        "SELECT * FROM activity_type_color ORDER BY default_type"
                ),
                queryTable(
                        "record_setting",
                        "SELECT * FROM record_setting ORDER BY setting_id"
                ),
                queryTable("hour_record", "SELECT * FROM hour_record ORDER BY id"),
                queryTable(
                        "daily_activity",
                        "SELECT * FROM daily_activity ORDER BY activity_date"
                )
        );
    }

    private DatabaseBackupSheet queryTable(String tableName, String sql) {
        return jdbcTemplate.query(sql, resultSet -> {
            ResultSetMetaData metadata = resultSet.getMetaData(); // 拿到欄名們
            int columnCount = metadata.getColumnCount(); // 拿到欄數
            List<String> columns = new ArrayList<>(columnCount);
            // 欄名們存進陣列
            for (int column = 1; column <= columnCount; column++) {
                columns.add(metadata.getColumnLabel(column));
            }

            // 開始存資料
            List<List<Object>> rows = new ArrayList<>();
            while (resultSet.next()) {
                List<Object> row = new ArrayList<>(columnCount);
                for (int column = 1; column <= columnCount; column++) {
                    row.add(resultSet.getObject(column));
                }
                rows.add(row);
            }

            // 最後把表名、欄名們，資料，包起來回傳
            return new DatabaseBackupSheet(tableName, columns, rows);
        });
    }
}
