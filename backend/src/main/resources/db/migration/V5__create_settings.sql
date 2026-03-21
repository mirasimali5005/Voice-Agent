CREATE TABLE settings (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key        VARCHAR(255) NOT NULL,
    value      TEXT,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_settings_user_id ON settings (user_id);
CREATE UNIQUE INDEX idx_settings_user_key ON settings (user_id, key);
