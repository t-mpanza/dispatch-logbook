// Dispatch Diary — daily report email (scheduled Edge Function).
//
// Runs Mon–Fri at 06:00 SAST (cron in supabase/config.toml) and sends the
// previous working day's dispatch summary (tyres loaded / truck count) from
// the owner's personal Gmail. GitHub cron was late, so this is the primary
// sender; the GitHub workflow remains a manual/backup trigger.
//
// Secrets (npx supabase secrets set):
//   REPORT_SENDER_EMAIL, REPORT_SENDER_APP_PASSWORD, REPORT_RECIPIENT_EMAIL

import nodemailer from "npm:nodemailer@7";

const DEFAULT_RECIPIENT = "Giz-MarieDP@att-tyres.co.za";

function previousWorkingDay(today: Date): string {
  const day = new Date(today);
  day.setUTCDate(day.getUTCDate() - 1);
  while (day.getUTCDay() === 0 || day.getUTCDay() === 6) {
    day.setUTCDate(day.getUTCDate() - 1);
  }
  return day.toISOString().slice(0, 10);
}

function jsonInt(v: unknown): number | null {
  if (v === null || v === undefined) return null;
  if (typeof v === "number") return Math.trunc(v);
  const n = Number(String(v).trim());
  return Number.isFinite(n) ? Math.trunc(n) : null;
}

function parseMetaSheet(notes: unknown): Record<string, unknown>[] | null {
  if (!Array.isArray(notes)) return null;
  for (const note of notes) {
    if (note && typeof note === "object" && (note as any).id === "__meta_sheet__") {
      try {
        const parsed = JSON.parse(String((note as any).text ?? "{}"));
        if (Array.isArray(parsed.loadingSheetTrips)) {
          return parsed.loadingSheetTrips;
        }
      } catch {
        /* tolerate */
      }
    }
  }
  return null;
}

function aggregate(entries: Record<string, unknown>[]): [number, number] {
  let tyres = 0;
  let trucks = 0;
  for (const entry of entries) {
    let trips = parseMetaSheet(entry.notes);
    if (!trips && Array.isArray(entry.trips)) {
      trips = entry.trips as Record<string, unknown>[];
    }
    if (!trips || trips.length === 0) continue;
    trucks += 1;
    for (const trip of trips) {
      const qty = jsonInt(trip.quantityLoaded ?? trip.quantity_loaded);
      if (qty !== null) {
        tyres += qty;
        continue;
      }
      const count = jsonInt(trip.count);
      const rejected = jsonInt(trip.rejected) ?? 0;
      if (count !== null) tyres += count + rejected;
    }
  }
  return [tyres, trucks];
}

Deno.serve(async (req) => {
  try {
    const sender = Deno.env.get("REPORT_SENDER_EMAIL");
    const appPassword = Deno.env.get("REPORT_SENDER_APP_PASSWORD");
    const recipient = Deno.env.get("REPORT_RECIPIENT_EMAIL") || DEFAULT_RECIPIENT;
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!sender || !appPassword || !supabaseUrl || !serviceKey) {
      const missing = [
        !sender ? "REPORT_SENDER_EMAIL" : null,
        !appPassword ? "REPORT_SENDER_APP_PASSWORD" : null,
        !supabaseUrl ? "SUPABASE_URL" : null,
        !serviceKey ? "SUPABASE_SERVICE_ROLE_KEY" : null,
      ].filter(Boolean);
      console.error(`Missing configuration secrets: ${missing.join(", ")}`);
      return new Response(`Missing configuration secrets: ${missing.join(", ")}`, {
        status: 500,
      });
    }

    // Manual trigger can pass ?date=YYYY-MM-DD
    const url = new URL(req.url);
    const forcedDate = url.searchParams.get("date");
    const reportDate = forcedDate && /^\d{4}-\d{2}-\d{2}$/.test(forcedDate)
      ? forcedDate
      : previousWorkingDay(new Date());

    const entriesRes = await fetch(
      `${supabaseUrl}/rest/v1/entries?day_key=eq.${reportDate}&deleted_at=is.null&select=notes,trips,title`,
      {
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
      },
    );
    if (!entriesRes.ok) {
      return new Response(`PostgREST error ${entriesRes.status}`, { status: 500 });
    }

    const entries = (await entriesRes.json()) as Record<string, unknown>[];
    const [tyres, trucks] = aggregate(entries);

    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 587,
      secure: false,
      auth: { user: sender, pass: appPassword },
    });

    await transporter.sendMail({
      from: `Dispatch Diary <${sender}>`,
      to: recipient,
      replyTo: sender,
      subject: `Daily Dispatch Report — ${reportDate}`,
      text: `Good Morning, Gizz.\n\nTyres Loaded: ${tyres}\nTotal Trucks: ${trucks}\n`,
    });

    console.log(
      `[daily-report] date=${reportDate} tyres=${tyres} trucks=${trucks} to=${recipient}`,
    );
    return new Response(
      JSON.stringify({ ok: true, date: reportDate, tyres, trucks }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("[daily-report] failed:", e);
    return new Response(`Error: ${e}`, { status: 500 });
  }
});
