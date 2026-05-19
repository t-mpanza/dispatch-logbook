import { allReminders, updateReminder } from "./db";
import type { Reminder } from "./types";

const scheduled = new Map<string, ReturnType<typeof setTimeout>>();

export async function requestNotificationPermission(): Promise<NotificationPermission> {
  if (typeof Notification === "undefined") return "denied";
  if (Notification.permission === "default") {
    return await Notification.requestPermission();
  }
  return Notification.permission;
}

function fire(r: Reminder) {
  if (typeof Notification !== "undefined" && Notification.permission === "granted") {
    try {
      new Notification("Dispatch Diary", { body: r.text, tag: r.id });
    } catch {
      // no-op
    }
  }
  r.done = true;
  void updateReminder(r);
}

export async function rescheduleAll() {
  if (typeof window === "undefined") return;
  // clear existing
  scheduled.forEach((t) => clearTimeout(t));
  scheduled.clear();

  const list = await allReminders();
  const now = Date.now();
  for (const r of list) {
    if (r.done) continue;
    const delay = r.at - now;
    if (delay <= 0) {
      fire(r);
    } else if (delay < 1000 * 60 * 60 * 24) {
      // only schedule within next 24h (browser timer accuracy)
      const t = setTimeout(() => fire(r), delay);
      scheduled.set(r.id, t);
    }
  }
}
