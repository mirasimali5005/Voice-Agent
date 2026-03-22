CREATE TABLE rules (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rule_type   VARCHAR(50),
    pattern     TEXT,
    replacement TEXT,
    context     VARCHAR(255),
    mode        VARCHAR(50),
    reasoning   TEXT,
    confidence  FLOAT NOT NULL DEFAULT 1.0,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_rules_user_id ON rules (user_id);
CREATE INDEX idx_rules_rule_type ON rules (rule_type);
