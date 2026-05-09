-- Run ONLY this in Supabase SQL Editor to add the civilians table
-- Self-contained: includes the updated_at function if not already present

-- Create the updated_at function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS civilians (
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

CREATE INDEX IF NOT EXISTS idx_civilians_server_id ON civilians(server_id);
CREATE INDEX IF NOT EXISTS idx_civilians_name ON civilians(name);
CREATE INDEX IF NOT EXISTS idx_civilians_created_by ON civilians(created_by);

ALTER TABLE civilians ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view civilians in their servers" ON civilians;
DROP POLICY IF EXISTS "Users can insert civilians in their servers" ON civilians;
DROP POLICY IF EXISTS "Users can update civilians in their servers" ON civilians;
DROP POLICY IF EXISTS "Users can delete civilians in their servers" ON civilians;

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

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_civilians_updated_at'
    ) THEN
        CREATE TRIGGER update_civilians_updated_at
            BEFORE UPDATE ON civilians
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;
