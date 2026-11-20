-- Messenger moderation (App Store Guideline 1.2): users can report a message
-- and block another user. Safe to run more than once.
CREATE TABLE IF NOT EXISTS user_blocks (
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (blocker_id, blocked_id)
);

CREATE TABLE IF NOT EXISTS message_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    reporter_id UUID REFERENCES users(id) ON DELETE SET NULL,
    sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
    message_content TEXT,
    reason TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'open', -- open | resolved
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_message_reports ON message_reports(message_id, reporter_id);
CREATE INDEX IF NOT EXISTS idx_message_reports_status ON message_reports(status, created_at);
