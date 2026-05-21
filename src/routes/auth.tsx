import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { BookOpen, Mail, ArrowRight, CheckCircle } from "lucide-react";

export const Route = createFileRoute("/auth")({
  head: () => ({ meta: [{ title: "Sign In — Dispatch Diary" }] }),
  component: AuthPage,
});

function AuthPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function sendMagicLink() {
    if (!email.trim()) return;
    setLoading(true);
    setError(null);
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: { shouldCreateUser: true },
    });
    setLoading(false);
    if (error) {
      setError(error.message);
    } else {
      setSent(true);
    }
  }

  async function skipSignIn() {
    navigate({ to: "/" });
  }

  return (
    <div className="min-h-screen bg-background flex flex-col items-center justify-center px-6">
      {/* Logo */}
      <div className="mb-8 text-center">
        <div className="mx-auto h-16 w-16 rounded-2xl bg-[image:var(--gradient-primary)] grid place-items-center shadow-[var(--shadow-glow)] mb-4">
          <BookOpen size={28} className="text-primary-foreground" />
        </div>
        <h1 className="text-2xl font-bold tracking-tight">Dispatch Diary</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Sign in to sync your logs across devices
        </p>
      </div>

      {sent ? (
        /* Success state */
        <div className="w-full max-w-sm text-center space-y-4">
          <div className="mx-auto h-14 w-14 rounded-full bg-primary/20 grid place-items-center">
            <CheckCircle size={28} className="text-primary-glow" />
          </div>
          <h2 className="text-lg font-semibold">Check your inbox</h2>
          <p className="text-sm text-muted-foreground">
            We sent a magic link to <strong className="text-foreground">{email}</strong>.
            Tap it to sign in — no password needed.
          </p>
          <button
            onClick={skipSignIn}
            className="mt-4 text-xs text-muted-foreground underline underline-offset-4"
          >
            Continue offline for now
          </button>
        </div>
      ) : (
        /* Input form */
        <div className="w-full max-w-sm space-y-4">
          <div className="rounded-2xl bg-surface border border-border p-4 space-y-3">
            <label className="text-[11px] uppercase tracking-wider text-muted-foreground font-medium">
              Email address
            </label>
            <div className="flex items-center gap-3 border-b border-border pb-2">
              <Mail size={18} className="text-muted-foreground shrink-0" />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && sendMagicLink()}
                placeholder="dispatcher@company.com"
                autoFocus
                className="flex-1 bg-transparent outline-none text-sm placeholder:text-muted-foreground/60"
              />
            </div>

            {error && (
              <p className="text-xs text-destructive">{error}</p>
            )}
          </div>

          <button
            onClick={sendMagicLink}
            disabled={loading || !email.trim()}
            className="w-full h-12 rounded-2xl bg-[image:var(--gradient-primary)] text-primary-foreground font-semibold flex items-center justify-center gap-2 shadow-[var(--shadow-glow)] active:scale-95 transition-all disabled:opacity-50"
          >
            {loading ? (
              <span className="text-sm">Sending…</span>
            ) : (
              <>
                <span className="text-sm">Send Magic Link</span>
                <ArrowRight size={18} />
              </>
            )}
          </button>

          <button
            onClick={skipSignIn}
            className="w-full text-center text-xs text-muted-foreground py-2"
          >
            Skip — use offline only
          </button>
        </div>
      )}
    </div>
  );
}
