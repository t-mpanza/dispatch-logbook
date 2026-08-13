import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL ||
  "https://glxxawxuwusxwjvezugo.supabase.co";

const SUPABASE_KEY =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdseHhhd3h1d3VzeHdqdmV6dWdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzOTY5MDgsImV4cCI6MjA5NDk3MjkwOH0.PIpRoWe00_0rCtaWLege92IaZQfRzH3jlBITR5kq0cY";

const isBrowser = typeof window !== "undefined";

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: {
    persistSession: isBrowser,
    autoRefreshToken: isBrowser,
    detectSessionInUrl: isBrowser,
  },
});
