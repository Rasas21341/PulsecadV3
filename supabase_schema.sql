-- Pulse CAD Database Schema (Safe for fresh or existing)
-- Run this in your Supabase SQL Editor

-- Drop tables with CASCADE (removes all dependent triggers, indexes, policies)
DROP TABLE IF EXISTS civilians CASCADE;
DROP TABLE IF EXISTS access_keys CASCADE;
DROP TABLE IF EXISTS servers CASCADE;
DROP TABLE IF EXISTS user_credits CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Drop standalone functions
DROP FUNCTION IF EXISTS handle_new_user_credits() CASCADE;
DROP FUNCTION IF EXISTS generate_server_invite_code() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user_profile() CASCADE;

-- IMPORTANT: Drop any triggers on auth.users that could cause "Database error saving new user"
-- These are common trigger names from old schemas
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP TRIGGER IF EXISTS create_user_credits_on_signup ON auth.users CASCADE;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users CASCADE;
DROP TRIGGER IF EXISTS create_credits_for_new_user ON auth.users CASCADE;

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

CREATE POLICY "Users can insert own credits on signup"
    ON user_credits FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Profiles Table (mirrors auth.users for public viewing)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT DEFAULT 'user',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_created_at ON profiles(created_at);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view profiles"
    ON profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can insert own profile on signup"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

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
    credits_amount INTEGER DEFAULT 0,
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

-- Police Tickets Table
CREATE TABLE police_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    civilian_id UUID REFERENCES civilians(id) ON DELETE CASCADE,
    server_id UUID REFERENCES servers(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'open',
    created_by UUID REFERENCES auth.users(id),
    officer_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_police_tickets_civilian_id ON police_tickets(civilian_id);
CREATE INDEX idx_police_tickets_server_id ON police_tickets(server_id);

ALTER TABLE police_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view police tickets in their servers"
    ON police_tickets FOR SELECT
    USING (
        server_id IN (
            SELECT s.id FROM servers s 
            WHERE s.owner_id = auth.uid() 
            OR s.members @> ARRAY[auth.uid()]
        )
    );

CREATE POLICY "Users can insert police tickets in their servers"
    ON police_tickets FOR INSERT
    WITH CHECK (
        server_id IN (
            SELECT s.id FROM servers s 
            WHERE s.owner_id = auth.uid() 
            OR s.members @> ARRAY[auth.uid()]
        )
    );

CREATE POLICY "Users can update police tickets in their servers"
    ON police_tickets FOR UPDATE
    USING (
        server_id IN (
            SELECT s.id FROM servers s 
            WHERE s.owner_id = auth.uid() 
            OR s.members @> ARRAY[auth.uid()]
        )
    );

CREATE TRIGGER update_police_tickets_updated_at
    BEFORE UPDATE ON police_tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Duty Records Table (Clock In/Out)
CREATE TABLE duty_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    server_id UUID REFERENCES servers(id) ON DELETE CASCADE,
    officer_name TEXT,
    callsign TEXT,
    rank TEXT,
    clock_in TIMESTAMPTZ DEFAULT NOW(),
    clock_out TIMESTAMPTZ,
    is_on_duty BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_duty_records_user_id ON duty_records(user_id);
CREATE INDEX idx_duty_records_server_id ON duty_records(server_id);

ALTER TABLE duty_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view duty records in their servers"
    ON duty_records FOR SELECT
    USING (
        server_id IN (
            SELECT s.id FROM servers s 
            WHERE s.owner_id = auth.uid() 
            OR s.members @> ARRAY[auth.uid()]
        )
    );

CREATE POLICY "Users can insert duty records"
    ON duty_records FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Users can update own duty records"
    ON duty_records FOR UPDATE
    USING (auth.uid() = user_id);

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

-- Support Tickets Table
CREATE TABLE support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    email TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_support_tickets_user_id ON support_tickets(user_id);
CREATE INDEX idx_support_tickets_status ON support_tickets(status);

ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view tickets"
    ON support_tickets FOR SELECT
    USING (true);

CREATE POLICY "Anyone can create tickets"
    ON support_tickets FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Users can update own tickets"
    ON support_tickets FOR UPDATE
    USING (true);

-- Ticket Messages Table
CREATE TABLE ticket_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID REFERENCES support_tickets(id) ON DELETE CASCADE,
    user_id UUID,
    message TEXT NOT NULL,
    is_support BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ticket_messages_ticket_id ON ticket_messages(ticket_id);

ALTER TABLE ticket_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view messages"
    ON ticket_messages FOR SELECT
    USING (true);

CREATE POLICY "Anyone can message tickets"
    ON ticket_messages FOR INSERT
    WITH CHECK (true);

CREATE TRIGGER update_support_tickets_updated_at
    BEFORE UPDATE ON support_tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- NOTE: user_credits is now created in login.html after signup, not via trigger
-- This avoids "Database error saving new user" caused by auth.users triggers
