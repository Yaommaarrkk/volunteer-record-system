BEGIN;

ALTER TABLE volunteer
    ADD COLUMN updated_at TIMESTAMPTZ;

UPDATE volunteer
SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP);

ALTER TABLE volunteer
    ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP,
    ALTER COLUMN updated_at SET NOT NULL;

CREATE OR REPLACE FUNCTION set_volunteer_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER volunteer_updated_at_trigger
BEFORE UPDATE ON volunteer
FOR EACH ROW
EXECUTE FUNCTION set_volunteer_updated_at();

CREATE OR REPLACE FUNCTION touch_volunteer_after_seat_change()
RETURNS TRIGGER AS $$
DECLARE
    changed_volunteer_id INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        changed_volunteer_id := OLD.volunteer_id;
    ELSE
        changed_volunteer_id := NEW.volunteer_id;
    END IF;

    UPDATE volunteer
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = changed_volunteer_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER volunteer_seat_updated_at_trigger
AFTER INSERT OR UPDATE OR DELETE ON volunteer_seat
FOR EACH ROW
EXECUTE FUNCTION touch_volunteer_after_seat_change();

COMMIT;
