import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState, useRef } from "react";
import { supabase } from "@/lib/supabase";
import { BookOpen, Mail, ArrowRight, KeyRound, RefreshCw } from "lucide-react";

export const Route = createFileRoute("/auth")({
  head: () => ({ meta: [{ title: "Sign In — Dispatch Diary" }] }),
  component: AuthPage,
});

type Step = "email" | "code";

function AuthPage() {
  const navigate = useNavigate();

  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState(["", "", "", "", "", ""]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const codeRefs = useRef<(HTMLInputElement | null)[]>([]);

  // ── Step 1: send OTP ──────────────────────────────────────────────────────
  async function sendOtp() {
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
      setStep("code");
      // Focus first box after render
      setTimeout(() => codeRefs.current[0]?.focus(), 100);
    }
  }

  // ── Step 2: verify OTP ────────────────────────────────────────────────────
  async function verifyOtp() {
    const token = code.join("");
    if (token.length !== 6) return;
    setLoading(true);
    setError(null);

    const { error } = await supabase.auth.verifyOtp({
      email: email.trim(),
      token,
      type: "email",
    });

    setLoading(false);
    if (error) {
      setError("Invalid or expired code. Try again.");
      setCode(["", "", "", "", "", ""]);
      setTimeout(() => codeRefs.current[0]?.focus(), 100);
    } else {
      navigate({ to: "/" });
    }
  }

  // ── OTP digit input handling ──────────────────────────────────────────────
  function onDigitChange(index: number, value: string) {
    const digit = value.replace(/\D/g, "").slice(-1);
    const next = [...code];
    next[index] = digit;
    setCode(next);
    if (digit && index < 5) codeRefs.current[index + 1]?.focus();
    if (next.every((d) => d)) {
      // Auto-submit when all filled
      setTimeout(() => verifyOtp(), 80);
    }
  }

  function onDigitKeyDown(index: number, e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Backspace" && !code[index] && index > 0) {
      codeRefs.current[index - 1]?.focus();
    }
  }

  function onDigitPaste(e: React.ClipboardEvent) {
    const text = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
    if (text.length === 6) {
      setCode(text.split(""));
      codeRefs.current[5]?.focus();
      setTimeout(() => verifyOtp(), 80);
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
          Sign in to sync your logs across devices
        </p>
      </div>

      {step === "email" ? (
        /* ── Email step ───────────────────────────────────────────── */
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
                onKeyDown={(e) => e.key === "Enter" && sendOtp()}
                placeholder="dispatcher@company.com"
                autoFocus
                className="flex-1 bg-transparent outline-none text-sm placeholder:text-muted-foreground/60"
              />
            </div>
            {error && <p className="text-xs text-destructive">{error}</p>}
          </div>

          <button
            onClick={sendOtp}
            disabled={loading || !email.trim()}
            className="w-full h-12 rounded-2xl bg-[image:var(--gradient-primary)] text-primary-foreground font-semibold flex items-center justify-center gap-2 shadow-[var(--shadow-glow)] active:scale-95 transition-all disabled:opacity-50"
          >
            {loading ? (
              <span className="text-sm">Sending…</span>
            ) : (
              <>
                <span className="text-sm">Send Code</span>
                <ArrowRight size={18} />
              </>
            )}
          </button>

          <button
            onClick={() => navigate({ to: "/" })}
            className="w-full text-center text-xs text-muted-foreground py-2"
          >
            Skip — use offline only
          </button>
        </div>
      ) : (
        /* ── OTP code step ────────────────────────────────────────── */
        <div className="w-full max-w-sm space-y-6">
          <div className="text-center space-y-1">
            <div className="mx-auto h-12 w-12 rounded-full bg-primary/15 grid place-items-center mb-3">
              <KeyRound size={22} className="text-primary-glow" />
            </div>
            <h2 className="text-lg font-semibold">Enter the code</h2>
            <p className="text-sm text-muted-foreground">
              We emailed a 6-digit code to{" "}
              <strong className="text-foreground">{email}</strong>
            </p>
          </div>

          {/* 6-digit input boxes */}
          <div className="flex gap-2 justify-center" onPaste={onDigitPaste}>
            {code.map((digit, i) => (
              <input
                key={i}
                ref={(el) => { codeRefs.current[i] = el; }}
                type="text"
                inputMode="numeric"
                maxLength={1}
                value={digit}
                onChange={(e) => onDigitChange(i, e.target.value)}
                onKeyDown={(e) => onDigitKeyDown(i, e)}
                className={`h-14 w-11 rounded-xl border text-center text-xl font-bold bg-surface outline-none transition-all ${
                  digit
                    ? "border-primary text-foreground"
                    : "border-border text-muted-foreground"
                } focus:border-primary focus:shadow-[0_0_0_3px_oklch(0.62_0.21_275_/_0.2)]`}
              />
            ))}
          </div>

          {error && (
            <p className="text-center text-sm text-destructive">{error}</p>
          )}

          <button
            onClick={verifyOtp}
            disabled={loading || code.some((d) => !d)}
            className="w-full h-12 rounded-2xl bg-[image:var(--gradient-primary)] text-primary-foreground font-semibold flex items-center justify-center gap-2 shadow-[var(--shadow-glow)] active:scale-95 transition-all disabled:opacity-50"
          >
            {loading ? "Verifying…" : "Confirm"}
          </button>

          <div className="flex items-center justify-between text-xs text-muted-foreground">
            <button
              onClick={() => { setStep("email"); setCode(["","","","","",""]); setError(null); }}
              className="flex items-center gap-1 hover:text-foreground transition-colors"
            >
              <ArrowRight size={12} className="rotate-180" /> Change email
            </button>
            <button
              onClick={sendOtp}
              disabled={loading}
              className="flex items-center gap-1 hover:text-foreground transition-colors disabled:opacity-40"
            >
              <RefreshCw size={12} /> Resend code
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
