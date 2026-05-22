import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = "https://glxxawxuwusxwjvezugo.supabase.co";
const SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdseHhhd3h1d3VzeHdqdmV6dWdvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTM5NjkwOCwiZXhwIjoyMDk0OTcyOTA4fQ.wT3hSxqooYZMivE72rr-VI6ayghuH_fJDJPMf4l77oI";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function run() {
  const { data, error } = await supabase.auth.admin.createUser({
    email: 'kiddow@dispatch.local',
    password: 'dispatch2026',
    email_confirm: true // bypasses email confirmation entirely
  });

  if (error) {
    console.error("Error creating user:", error.message);
  } else {
    console.log("User created successfully!");
    console.log("Email:", data.user.email);
    console.log("ID:", data.user.id);
  }
}

run();
