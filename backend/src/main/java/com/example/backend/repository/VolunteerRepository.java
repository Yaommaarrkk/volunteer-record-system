package com.example.backend.repository;

import java.util.List;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;
import com.example.backend.domain.EducationLevel;
import com.example.backend.domain.SeatPeriod;
import com.example.backend.domain.Volunteer;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

@Repository
public class VolunteerRepository {
    private final JdbcTemplate jdbcTemplate;
    private static final RowMapper<Volunteer> VOLUNTEER_ROW_MAPPER =
            (resultSet, rowNumber) -> {
                return new Volunteer(
                        resultSet.getInt("id"),
                        resultSet.getString("name"),
                        resultSet.getInt("age")
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
            ORDER BY age, name
            """;

        List<Volunteer> volunteers = jdbcTemplate.query(sql, VOLUNTEER_ROW_MAPPER);
        volunteers.forEach(this::loadSeats);
        return volunteers;
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

        Volunteer volunteer = volunteers.stream()
                .findFirst()
                .orElse(null);

        if (volunteer != null) {
            loadSeats(volunteer);
        }
        return volunteer;
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

    @Transactional
    public int insert(Volunteer volunteer) {
        // 傳變數進去 用'?'代替 變數則接在query的第三個參數
        String sql = """
            INSERT INTO volunteer (id, name, age)
            VALUES (?, ?, ?)
            """;

        int insertedRows = jdbcTemplate.update(
                sql,
                volunteer.getId(),
                volunteer.getName(),
                volunteer.getAge()
        );

        String seatSql = """
            INSERT INTO volunteer_seat (volunteer_id, period, seat_row, seat_col)
            VALUES (?, ?, ?, ?)
            """;

        for (Volunteer.SeatAssignment assignment : volunteer.getSeats()) {
            jdbcTemplate.update(
                    seatSql,
                    volunteer.getId(),
                    assignment.getPeriod().name(),
                    assignment.getSeat().getRow(),
                    assignment.getSeat().getCol()
            );
        }

        return insertedRows;
    }

    private void loadSeats(Volunteer volunteer) {
        String sql = """
            SELECT period, seat_row, seat_col
            FROM volunteer_seat
            WHERE volunteer_id = ?
            ORDER BY period
            """;

        jdbcTemplate.query(sql, resultSet -> {
            Integer seatRow = // 使用getObject 因為getInt會把null變成0
                    resultSet.getObject("seat_row", Integer.class);

            Integer seatCol =
                    resultSet.getObject("seat_col", Integer.class);

            volunteer.addSeat(
                    new Volunteer.SeatAssignment(
                            SeatPeriod.valueOf(resultSet.getString("period")),
                            new Volunteer.Seat(seatRow, seatCol)
                    )
            );
        }, volunteer.getId());
    }

    public int deleteById(Integer id) {
        String sql = """
            DELETE FROM volunteer
            WHERE id = ?
            """;

        return jdbcTemplate.update(sql, id);
    }
}
