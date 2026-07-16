BEGIN;

ALTER TABLE activity
    ADD COLUMN sort_order INTEGER;

WITH ranked_activity AS (
    SELECT
        id,
        ROW_NUMBER() OVER (PARTITION BY default_type ORDER BY id) AS new_sort_order
    FROM activity
)
UPDATE activity
SET sort_order = ranked_activity.new_sort_order
FROM ranked_activity
WHERE activity.id = ranked_activity.id;

ALTER TABLE activity
    ALTER COLUMN sort_order SET NOT NULL,
    ADD CONSTRAINT activity_sort_order_positive CHECK (sort_order > 0);

CREATE TABLE activity_type_color (
    default_type VARCHAR(40) PRIMARY KEY CHECK (
        default_type IN ('TEACHING', 'COMPANION_READING', 'PLAY', 'DAILY_INTERACTION', 'PASSIVE')
    ),
    tag_color VARCHAR(7) NOT NULL CHECK (tag_color ~ '^#[0-9A-Fa-f]{6}$')
);

INSERT INTO activity_type_color (default_type, tag_color)
VALUES
    ('TEACHING', '#2563EB'),
    ('COMPANION_READING', '#7C3AED'),
    ('PLAY', '#EA580C'),
    ('DAILY_INTERACTION', '#059669'),
    ('PASSIVE', '#64748B');

COMMIT;
