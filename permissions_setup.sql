-- Pulse CAD Staff Permissions Setup
-- Run this once in your Supabase SQL Editor

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS suspended BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_manage_keys BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_manage_servers BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_manage_users BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_manage_staff BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_manage_support BOOLEAN DEFAULT FALSE;

DROP POLICY IF EXISTS "Users can update profiles" ON profiles;
DROP POLICY IF EXISTS "Users can delete profiles" ON profiles;

CREATE POLICY "Users can update profiles" ON profiles FOR UPDATE USING (true);
CREATE POLICY "Users can delete profiles" ON profiles FOR DELETE USING (true);

UPDATE profiles SET role = 'master_admin', can_manage_keys = true, can_manage_servers = true, can_manage_users = true, can_manage_staff = true, can_manage_support = true WHERE email = 'ryanmasterson2026@gmail.com';
