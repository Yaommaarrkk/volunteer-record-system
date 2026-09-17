CREATE SEQUENCE user_id_seq
    START WITH 1000
    INCREMENT BY 1;

CREATE TYPE user_role AS ENUM ('super_admin', 'vip_user', 'user', 'visitor');

CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'visitor',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
