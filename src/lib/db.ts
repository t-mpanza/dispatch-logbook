import { openDB, type IDBPDatabase } from "idb";
import type { Entry, Reminder } from "./types";
import { dayKey, monthKey, uid, yearKey } from "./format";

const DB_NAME = "dispatch-diary";
const DB_VERSION = 1;

let dbp: Promise<IDBPDatabase> | null = null;

function getDB() {
  if (typeof indexedDB === "undefined") {
    throw new Error("IndexedDB not available");
  }
  if (!dbp) {
    dbp = openDB(DB_NAME, DB_VERSION, {
      upgrade(db) {
        if (!db.objectStoreNames.contains("entries")) {
          const s = db.createObjectStore("entries", { keyPath: "id" });
          s.createIndex("byDay", "dayKey");
          s.createIndex("byMonth", "monthKey");
          s.createIndex("byYear", "yearKey");
          s.createIndex("byUpdated", "updatedAt");
        }
        if (!db.objectStoreNames.contains("reminders")) {
          const r = db.createObjectStore("reminders", { keyPath: "id" });
          r.createIndex("byEntry", "entryId");
          r.createIndex("byAt", "at");
        }
      },
    });
  }
  return dbp;
}

export async function createEntry(input: {
  title: string;
  tags?: string[];
  withCounter?: boolean;
}): Promise<Entry> {
  const now = Date.now();
  const d = new Date(now);
  const entry: Entry = {
    id: uid(),
    title: input.title.trim() || "Untitled",
    tags: input.tags ?? [],
    notes: [],
    attachments: [],
    trips: input.withCounter ? [] : undefined,
    createdAt: now,
    updatedAt: now,
    dayKey: dayKey(d),
    monthKey: monthKey(d),
    yearKey: yearKey(d),
  };
  const db = await getDB();
  await db.put("entries", entry);
  return entry;
}

export async function entriesWithCounter(): Promise<Entry[]> {
  const all = await allEntries();
  return all.filter((e) => Array.isArray(e.trips));
}

export async function updateEntry(entry: Entry) {
  entry.updatedAt = Date.now();
  const db = await getDB();
  await db.put("entries", entry);
}

export async function getEntry(id: string): Promise<Entry | undefined> {
  const db = await getDB();
  return db.get("entries", id);
}

export async function deleteEntry(id: string) {
  const db = await getDB();
  await db.delete("entries", id);
  // cascade reminders
  const keys = await db.getAllKeysFromIndex("reminders", "byEntry", id);
  const tx = db.transaction("reminders", "readwrite");
  await Promise.all(keys.map((k) => tx.store.delete(k)));
  await tx.done;
}

export async function entriesByDay(day: string): Promise<Entry[]> {
  const db = await getDB();
  const list = await db.getAllFromIndex("entries", "byDay", day);
  return list.sort((a, b) => b.createdAt - a.createdAt);
}

export async function entriesByMonth(month: string): Promise<Entry[]> {
  const db = await getDB();
  return db.getAllFromIndex("entries", "byMonth", month);
}

export async function allEntries(): Promise<Entry[]> {
  const db = await getDB();
  const list = await db.getAll("entries");
  return list.sort((a, b) => b.createdAt - a.createdAt);
}

export async function searchEntries(q: string): Promise<Entry[]> {
  const all = await allEntries();
  const needle = q.toLowerCase().trim();
  if (!needle) return all;
  return all.filter((e) => {
    if (e.title.toLowerCase().includes(needle)) return true;
    if (e.tags.some((t) => t.toLowerCase().includes(needle))) return true;
    if (e.notes.some((n) => n.text.toLowerCase().includes(needle))) return true;
    return false;
  });
}

export async function allTags(): Promise<string[]> {
  const all = await allEntries();
  const set = new Set<string>();
  all.forEach((e) => e.tags.forEach((t) => set.add(t)));
  return Array.from(set).sort();
}

// Reminders
export async function addReminder(r: Omit<Reminder, "id" | "done">): Promise<Reminder> {
  const rem: Reminder = { ...r, id: uid(), done: false };
  const db = await getDB();
  await db.put("reminders", rem);
  return rem;
}

export async function remindersForEntry(entryId: string): Promise<Reminder[]> {
  const db = await getDB();
  return db.getAllFromIndex("reminders", "byEntry", entryId);
}

export async function allReminders(): Promise<Reminder[]> {
  const db = await getDB();
  return db.getAll("reminders");
}

export async function updateReminder(r: Reminder) {
  const db = await getDB();
  await db.put("reminders", r);
}

export async function deleteReminder(id: string) {
  const db = await getDB();
  await db.delete("reminders", id);
}
