package com.example.backend.repository;

import java.util.List;
import org.springframework.stereotype.Repository;
import com.example.backend.domain.EducationLevel;
import com.example.backend.domain.Volunteer;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

@Repository
public class VolunteerRepository {
    private final JdbcTemplate jdbcTemplate;
    private static final RowMapper<Volunteer> VOLUNTEER_ROW_MAPPER =
            (resultSet, rowNumber) -> {
                Integer seatRow = // 使用getObject 因為getInt會把null變成0
                        resultSet.getObject("seat_row", Integer.class);

                Integer seatCol =
                        resultSet.getObject("seat_col", Integer.class);

                Volunteer.Seat seat =
                        seatRow == null || seatCol == null
                                ? null
                                : new Volunteer.Seat(seatRow, seatCol);

                return new Volunteer(
                        resultSet.getInt("id"),
                        resultSet.getString("name"),
                        resultSet.getInt("age"),
                        seat
                );
            };

    public VolunteerRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

//    private final List<Volunteer> test_volunteers = List.of(
//            new Volunteer(1001, "卓辰妍", 8, new Volunteer.Seat(1, 1)),
//            new Volunteer(1002, "潘勇仁", 10, new Volunteer.Seat(1, 2)),
//            new Volunteer(2001, "潘艾琳", 13, null)
//    );
//
//    List<Volunteer> volunteer_ptr = test_volunteers;

    public List<Volunteer> getAll() {
        String sql = """
            SELECT *
            FROM volunteer
            ORDER BY seat_row, seat_col, age
            """;

        return jdbcTemplate.query(sql, VOLUNTEER_ROW_MAPPER);
    }

    public Volunteer findByName(String name) {
        // 傳變數進去 用'?'代替 變數則接在query的第三個參數
        String sql = """
            SELECT *
            FROM volunteer
            WHERE name = ?
            """;

        List<Volunteer> volunteers =
                jdbcTemplate.query(sql, VOLUNTEER_ROW_MAPPER, name);

        return volunteers.stream()
                .findFirst()
                .orElse(null);
    }

    public Integer nextId(EducationLevel educationLevel) {
        String sql = switch (educationLevel) {
            case ELEMENTARY_SCHOOL ->
                    "SELECT nextval('elementary_volunteer_id_seq')";
            case JUNIOR_HIGH_SCHOOL ->
                    "SELECT nextval('junior_high_volunteer_id_seq')";
            default -> throw new IllegalArgumentException("目前只支援國小與國中");
        };

        Long id = jdbcTemplate.queryForObject(sql, Long.class);
        if (id == null) {
            throw new IllegalStateException("無法取得學生流水號");
        }

        return Math.toIntExact(id);
    }

    public int insert(Volunteer volunteer) {
        // 傳變數進去 用'?'代替 變數則接在query的第三個參數
        String sql = """
            INSERT INTO volunteer (id, name, age, seat_row, seat_col)
            VALUES (?, ?, ?, ?, ?)
            """;

        Volunteer.Seat seat = volunteer.getSeat();
        Integer seatRow = seat == null ? null : seat.getRow();
        Integer seatCol = seat == null ? null : seat.getCol();

        return jdbcTemplate.update(
                sql,
                volunteer.getId(),
                volunteer.getName(),
                volunteer.getAge(),
                seatRow,
                seatCol
        );
    }

    public int deleteById(Integer id) {
        String sql = """
            DELETE FROM volunteer
            WHERE id = ?
            """;

        return jdbcTemplate.update(sql, id);
    }
}
