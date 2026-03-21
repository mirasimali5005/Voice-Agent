CREATE TABLE contexts (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    app_name          VARCHAR(255),
    rules_for_context JSONB DEFAULT '[]'::jsonb,
    updated_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_contexts_user_id ON contexts (user_id);
CREATE INDEX idx_contexts_app_name ON contexts (app_name);
