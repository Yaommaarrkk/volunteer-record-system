ALTER TABLE volunteer
ADD COLUMN birthday_month SMALLINT CHECK (birthday_month BETWEEN 1 AND 12),
ADD COLUMN birthday_day SMALLINT CHECK (birthday_day BETWEEN 1 AND 31);
