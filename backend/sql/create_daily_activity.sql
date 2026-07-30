BEGIN;

CREATE TABLE daily_activity (
    activity_date DATE PRIMARY KEY,
    description VARCHAR(120) NOT NULL CHECK (BTRIM(description) <> ''),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION set_daily_activity_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER daily_activity_updated_at_trigger
BEFORE UPDATE ON daily_activity
FOR EACH ROW
EXECUTE FUNCTION set_daily_activity_updated_at();

COMMIT;
