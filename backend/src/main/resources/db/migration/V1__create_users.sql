CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apple_id    VARCHAR(255) UNIQUE,
    email       VARCHAR(255),
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    last_login  TIMESTAMP WITH TIME ZONE,
    preferences JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_users_apple_id ON users (apple_id);
CREATE INDEX idx_users_email ON users (email);
