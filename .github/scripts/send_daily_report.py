#!/usr/bin/env python3
"""Daily Dispatch Report sender.

Runs inside GitHub Actions (scheduled weekdays 06:00 SAST, or manually
dispatched). Reads the previous working day's dispatch data from Supabase
and emails a two-line summary from the owner's personal email account.

Secrets (GitHub Environment `reporting`):
  REPORT_SENDER_EMAIL         - personal email address used to send
  REPORT_SENDER_APP_PASSWORD  - Gmail app password for that address
  REPORT_RECIPIENT_EMAIL      - report recipient (defaults to Giz-MarieDP)
  SUPABASE_URL                - Supabase project URL
  SUPABASE_SERVICE_ROLE_KEY   - Supabase service role key (server-side read)
"""

import datetime
import json
import os
import smtplib
import sys
import urllib.request
from email.mime.text import MIMEText

DEFAULT_RECIPIENT = "Giz-MarieDP@att-tyres.co.za"
SAST = datetime.timezone(datetime.timedelta(hours=2))


def previous_working_day(today):
    """Return the last working day (Mon-Fri) before `today` (date, SAST)."""
    day = today - datetime.timedelta(days=1)
    while day.weekday() >= 5:  # Sat=5, Sun=6 -> roll back to Friday
        day -= datetime.timedelta(days=1)
    return day


def resolve_report_date():
    env_date = os.environ.get("REPORT_DATE") or ""
    env_date = env_date.strip()
    if env_date:
        try:
            return datetime.datetime.strptime(env_date, "%Y-%m-%d").date()
        except ValueError:
            print(f"[daily-report] Invalid REPORT_DATE {env_date!r}; using "
                  "previous working day")
    now = datetime.datetime.now(SAST)
    return previous_working_day(now.date())


def fetch_entries(supabase_url, service_key, day_key):
    """Fetch live (non-tombstoned) entries for the given day via PostgREST."""
    url = (
        f"{supabase_url.rstrip('/')}/rest/v1/entries"
        f"?day_key=eq.{day_key}&deleted_at=is.null&select=notes,trips,title"
    )
    req = urllib.request.Request(
        url,
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as res:
        return json.loads(res.read().decode("utf-8"))


def parse_meta_sheet(notes_raw):
    """Extract loadingSheetTrips from the packed __meta_sheet__ note."""
    if not isinstance(notes_raw, list):
        return None
    for note in notes_raw:
        if not isinstance(note, dict):
            continue
        if note.get("id") != "__meta_sheet__":
            continue
        try:
            parsed = json.loads(note.get("text") or "{}")
        except (TypeError, ValueError):
            continue
        trips = parsed.get("loadingSheetTrips")
        if isinstance(trips, list):
            return trips
    return None


def parse_trips_column(trips_raw):
    """Fallback: parse the trips JSON column (list of trip maps)."""
    if not isinstance(trips_raw, list):
        return None
    return trips_raw


def aggregate(entries):
    tyres = 0
    trucks = 0
    for entry in entries:
        trips = parse_meta_sheet(entry.get("notes"))
        if trips is None:
            trips = parse_trips_column(entry.get("trips"))
        if not trips:
            continue
        trucks += 1
        for trip in trips:
            if not isinstance(trip, dict):
                continue
            qty = trip.get("quantityLoaded", trip.get("quantity_loaded"))
            if isinstance(qty, (int, float)):
                tyres += int(qty)
            else:
                # Counter-trip fallback: count + rejected
                count = trip.get("count")
                rejected = trip.get("rejected") or 0
                if isinstance(count, (int, float)):
                    tyres += int(count) + int(rejected)
    return tyres, trucks


def send_email(sender, app_password, recipient, subject, body):
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = f"Dispatch Diary <{sender}>"
    msg["To"] = recipient
    msg["Reply-To"] = sender

    with smtplib.SMTP("smtp.gmail.com", 587, timeout=30) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(sender, app_password)
        server.sendmail(sender, [recipient], msg.as_string())


def main():
    sender = os.environ.get("REPORT_SENDER_EMAIL")
    app_password = os.environ.get("REPORT_SENDER_APP_PASSWORD")
    recipient = (
        os.environ.get("REPORT_RECIPIENT_EMAIL") or DEFAULT_RECIPIENT
    ).strip()
    supabase_url = os.environ.get("SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    missing = [
        name
        for name, value in {
            "REPORT_SENDER_EMAIL": sender,
            "REPORT_SENDER_APP_PASSWORD": app_password,
            "SUPABASE_URL": supabase_url,
            "SUPABASE_SERVICE_ROLE_KEY": service_key,
        }.items()
        if not value
    ]
    if missing:
        print(f"[daily-report] Missing secrets: {', '.join(missing)}")
        sys.exit(1)

    report_date = resolve_report_date()
    entries = fetch_entries(supabase_url, service_key, report_date.isoformat())
    tyres, trucks = aggregate(entries)

    subject = f"Daily Dispatch Report — {report_date.isoformat()}"
    body = (
        "Good Morning, Gizz.\n\n"
        f"Tyres Loaded: {tyres}\n"
        f"Total Trucks: {trucks}\n"
    )

    print(f"[daily-report] date={report_date.isoformat()} tyres={tyres} "
          f"trucks={trucks} from={sender} to={recipient}")
    send_email(sender, app_password, recipient, subject, body)
    print("[daily-report] Email sent successfully")


if __name__ == "__main__":
    main()
