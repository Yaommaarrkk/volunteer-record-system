BEGIN;

ALTER TABLE activity
    DROP CONSTRAINT activity_default_type_check;

ALTER TABLE activity
    ADD CONSTRAINT activity_default_type_check CHECK (
        default_type IN ('TEACHING', 'COMPANION_READING', 'PLAY', 'DAILY_INTERACTION', 'PASSIVE')
    );

COMMIT;
