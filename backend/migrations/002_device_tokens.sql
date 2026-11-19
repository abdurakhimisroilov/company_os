-- Push notification device registrations. Safe to run more than once.
CREATE TABLE IF NOT EXISTS device_tokens (
    token VARCHAR(255) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform VARCHAR(20) NOT NULL,          -- ios | android
    environment VARCHAR(20) NOT NULL DEFAULT 'production', -- production | sandbox (APNs)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);
