// Initialize Supabase client
const supabaseUrl = 'https://xoebglqhettacddmcpcw.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhvZWJnbHFoZXR0YWNkZG1jcGN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1MDQ2NzEsImV4cCI6MjA5MzA4MDY3MX0.fjgUSxziKcwcvrhgoDgl3WmxABuibPGWb45iVyBCmGY';
export const supabase = window.supabase.createClient(supabaseUrl, supabaseKey);