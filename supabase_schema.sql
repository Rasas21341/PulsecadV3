-- Pulse CAD Database Schema (Safe for fresh or existing)
-- Run this in your Supabase SQL Editor

-- Drop tables with CASCADE (removes all dependent triggers, indexes, policies)
DROP TABLE IF EXISTS civilians CASCADE;
DROP TABLE IF EXISTS access_keys CASCADE;
DROP TABLE IF EXISTS servers CASCADE;
DROP TABLE IF EXISTS user_credits CASCADE;

-- Drop standalone functions
DROP FUNCTION IF EXISTS handle_new_user_credits() CASCADE;
DROP FUNCTION IF EXISTS generate_server_invite_code() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- User Credits Table
CREATE TABLE user_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    credits INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_credits_user_id ON user_credits(user_id);

ALTER TABLE user_credits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own credits"
    ON user_credits FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own credits"
    ON user_credits FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert credits"
    ON user_credits FOR INSERT
    WITH CHECK (true);

-- Servers Table
CREATE TABLE servers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    invite_code TEXT UNIQUE,
    erlc_server_id TEXT,
    members UUID[] DEFAULT '{}',
    suspended BOOLEAN DEFAULT FALSE,
    suspended_by UUID REFERENCES auth.users(id),
    suspended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_servers_owner_id ON servers(owner_id);
CREATE INDEX idx_servers_invite_code ON servers(invite_code);

ALTER TABLE servers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view servers they own or are members of"
    ON servers FOR SELECT
    USING (auth.uid() = owner_id OR (members @> ARRAY[auth.uid()] AND suspended = false));

CREATE POLICY "Users can create servers"
    ON servers FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update their own servers"
    ON servers FOR UPDATE
    USING (auth.uid() = owner_id);

-- Access Keys Table
CREATE TABLE access_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    server_name TEXT NOT NULL,
    key_type TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    redeemed BOOLEAN DEFAULT FALSE,
    redeemed_by UUID REFERENCES auth.users(id),
    redeemed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_access_keys_key ON access_keys(key);
CREATE INDEX idx_access_keys_created_by ON access_keys(created_by);
CREATE INDEX idx_access_keys_redeemed ON access_keys(redeemed);

ALTER TABLE access_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own keys"
    ON access_keys FOR SELECT
    USING (auth.uid() = created_by);

CREATE POLICY "Users can create keys"
    ON access_keys FOR INSERT
    WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update own keys"
    ON access_keys FOR UPDATE
    USING (auth.uid() = created_by);

CREATE POLICY "Anyone can redeem available keys"
    ON access_keys FOR UPDATE
    USING (redeemed = false);

-- Civilians Table
CREATE TABLE civilians (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    dob TEXT,
    phone TEXT,
    address TEXT,
    occupation TEXT,
    notes TEXT,
    server_id UUID REFERENCES servers(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_civilians_server_id ON civilians(server_id);
CREATE INDEX idx_civilians_name ON civilians(name);
CREATE INDEX idx_civilians_created_by ON civilians(created_by);

ALTER TABLE civilians ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view civilians in their servers"
    ON civilians FOR SELECT
    USING (
        server_id IN (
            SELECT s.id FROM servers s 
            WHERE s.owner_id = auth.uid() 
            OR s.members @> ARRAY[auth.uid()]
        )
    );

CREATE POLICY "Users can insert civilians in their servers"
    ON civilians FOR INSERT
    WITH CHECK (
        server_id IN (
            SELECT s.id FROM servers s 
            WHERE s.owner_id = auth.uid() 
            OR s.members @> ARRAY[auth.uid()]
        )
    );

CREATE POLICY "Users can update civilians in their servers"
    ON civilians FOR UPDATE
    USING (
        server_id IN (
            SELECT s.id FROM servers s 
            WHERE s.owner_id = auth.uid() 
            OR s.members @> ARRAY[auth.uid()]
        )
    );

CREATE POLICY "Users can delete civilians in their servers"
    ON civilians FOR DELETE
    USING (
        server_id IN (
            SELECT s.id FROM servers s 
            WHERE s.owner_id = auth.uid() 
            OR s.members @> ARRAY[auth.uid()]
        )
    );

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_credits_updated_at
    BEFORE UPDATE ON user_credits
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_servers_updated_at
    BEFORE UPDATE ON servers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_access_keys_updated_at
    BEFORE UPDATE ON access_keys
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_civilians_updated_at
    BEFORE UPDATE ON civilians
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Server invite code generator
CREATE OR REPLACE FUNCTION generate_server_invite_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.invite_code IS NULL THEN
        NEW.invite_code = 'PULSE-' || UPPER(SUBSTRING(MD5(NEW.id::TEXT || RANDOM()::TEXT) FROM 1 FOR 8));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_server_invite_code
    BEFORE INSERT ON servers
    FOR EACH ROW
    EXECUTE FUNCTION generate_server_invite_code();

-- NOTE: user_credits is now created in login.html after signup, not via trigger
-- This avoids "Database error saving new user" caused by auth.users triggers
