BEGIN;

CREATE TABLE volunteer_seat (
    volunteer_id INTEGER NOT NULL REFERENCES volunteer(id) ON DELETE CASCADE,
    period VARCHAR(40) NOT NULL,
    seat_row INTEGER NOT NULL CHECK (seat_row BETWEEN 1 AND 5),
    seat_col INTEGER NOT NULL CHECK (seat_col BETWEEN 1 AND 4),
    PRIMARY KEY (volunteer_id, period)
);

INSERT INTO volunteer_seat (volunteer_id, period, seat_row, seat_col)
SELECT id, 'YEAR_114_SECOND_SEMESTER', seat_row, seat_col
FROM volunteer
WHERE seat_row IS NOT NULL AND seat_col IS NOT NULL;

ALTER TABLE volunteer
    DROP COLUMN seat_row,
    DROP COLUMN seat_col;

COMMIT;
