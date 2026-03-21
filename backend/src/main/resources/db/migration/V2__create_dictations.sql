CREATE TABLE dictations (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    timestamp        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    duration_seconds INTEGER,
    raw_transcript   TEXT,
    cleaned_text     TEXT,
    was_pasted       BOOLEAN DEFAULT false,
    context          VARCHAR(255),
    mode             VARCHAR(50),
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_dictations_user_id ON dictations (user_id);
CREATE INDEX idx_dictations_timestamp ON dictations (timestamp);
