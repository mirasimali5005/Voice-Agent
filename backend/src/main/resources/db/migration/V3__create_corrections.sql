CREATE TABLE corrections (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    before_text TEXT,
    after_text  TEXT,
    context     VARCHAR(255),
    mode        VARCHAR(50),
    count       INTEGER NOT NULL DEFAULT 1,
    auto_rule   BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_corrections_user_id ON corrections (user_id);
