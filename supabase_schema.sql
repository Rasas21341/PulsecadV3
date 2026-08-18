ALTER TABLE communities 
ADD COLUMN IF NOT EXISTS supervisor_password TEXT;

COMMENT ON COLUMN communities.supervisor_password IS 'Password required to access the community dashboard/settings.';
