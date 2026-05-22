import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { BookOpen, Mail, ArrowRight, Lock } from "lucide-react";

export const Route = createFileRoute("/auth")({
  head: () => ({ meta: [{ title: "Sign In — Dispatch Diary" }] }),
  component: AuthPage,
});

function AuthPage() {
  const navigate = useNavigate();

  const [mode, setMode] = useState<"signin" | "signup">("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleAuth(e: React.FormEvent) {
    e.preventDefault();
    if (!email.trim() || !password.trim()) return;

    setLoading(true);
    setError(null);

    let authError = null;

    if (mode === "signin") {
      const { error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password: password.trim(),
      });
      authError = error;
    } else {
      const { error } = await supabase.auth.signUp({
        email: email.trim(),
        password: password.trim(),
      });
      authError = error;
    }

    setLoading(false);

    if (authError) {
      setError(authError.message);
    } else {
      navigate({ to: "/" });
    }
  }

  return (
    <div className="min-h-screen bg-background flex flex-col items-center justify-center px-6">
      {/* Logo */}
      <div className="mb-10 text-center">
        <div className="mx-auto h-16 w-16 rounded-2xl bg-[image:var(--gradient-primary)] grid place-items-center shadow-[var(--shadow-glow)] mb-4">
          <BookOpen size={28} className="text-primary-foreground" />
        </div>
        <h1 className="text-2xl font-bold tracking-tight">Dispatch Diary</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {mode === "signin"
            ? "Sign in to sync your logs across devices"
            : "Create an account to start syncing"}
        </p>
      </div>

      <form onSubmit={handleAuth} className="w-full max-w-sm space-y-4">
        <div className="rounded-2xl bg-surface border border-border p-4 space-y-4">
          {/* Email Field */}
          <div className="space-y-2">
            <label className="text-[11px] uppercase tracking-wider text-muted-foreground font-medium">
              Email address
            </label>
            <div className="flex items-center gap-3 border-b border-border pb-2">
              <Mail size={18} className="text-muted-foreground shrink-0" />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="dispatcher@company.com"
                required
                className="flex-1 bg-transparent outline-none text-sm placeholder:text-muted-foreground/60"
              />
            </div>
          </div>

          {/* Password Field */}
          <div className="space-y-2">
            <label className="text-[11px] uppercase tracking-wider text-muted-foreground font-medium">
              Password
            </label>
            <div className="flex items-center gap-3 border-b border-border pb-2">
              <Lock size={18} className="text-muted-foreground shrink-0" />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                minLength={6}
                className="flex-1 bg-transparent outline-none text-sm placeholder:text-muted-foreground/60"
              />
            </div>
          </div>

          {error && <p className="text-xs text-destructive pt-2">{error}</p>}
        </div>

        <button
          type="submit"
          disabled={loading || !email.trim() || !password.trim()}
          className="w-full h-12 rounded-2xl bg-[image:var(--gradient-primary)] text-primary-foreground font-semibold flex items-center justify-center gap-2 shadow-[var(--shadow-glow)] active:scale-95 transition-all disabled:opacity-50"
        >
          {loading ? (
            <span className="text-sm">
              {mode === "signin" ? "Signing in…" : "Creating account…"}
            </span>
          ) : (
            <>
              <span className="text-sm">
                {mode === "signin" ? "Sign In" : "Create Account"}
              </span>
              <ArrowRight size={18} />
            </>
          )}
        </button>

        {/* Toggle Mode */}
        <button
          type="button"
          onClick={() => {
            setMode(mode === "signin" ? "signup" : "signin");
            setError(null);
          }}
          className="w-full text-center text-sm text-primary hover:text-primary/80 py-2 transition-colors"
        >
          {mode === "signin"
            ? "Don't have an account? Sign up"
            : "Already have an account? Sign in"}
        </button>

        <button
          type="button"
          onClick={() => navigate({ to: "/" })}
          className="w-full text-center text-xs text-muted-foreground py-2 mt-4"
        >
          Skip — use offline only
        </button>
      </form>
    </div>
  );
}
