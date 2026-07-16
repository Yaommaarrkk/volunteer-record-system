BEGIN;

ALTER TABLE activity
    DROP COLUMN IF EXISTS default_note;

COMMIT;
