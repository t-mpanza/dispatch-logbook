# Library Modules (`src/lib/`)

---

## `types.ts`

Core TypeScript interfaces. See [DATA_MODEL.md](./DATA_MODEL.md) for full field reference.

Exports: `AttachmentKind`, `Attachment`, `NoteBlock`, `Reminder`, `Trip`, `Entry`

---

## `db.ts`

IndexedDB layer via the `idb` library. Singleton DB connection via module-level `dbp` promise.

```ts
const DB_NAME = "dispatch-diary";
const DB_VERSION = 1;
```

**Singleton pattern**: `dbp` is set once on first call to `getDB()`. If IndexedDB is unavailable (SSR/server-side), it throws immediately — protected by `typeof indexedDB === "undefined"` check.

See [DATA_MODEL.md → DB API](./DATA_MODEL.md#db-api-srclibdbts) for full function table.

**Important**: `deleteEntry` cascades to reminders using a multi-key transaction:
```ts
const keys = await db.getAllKeysFromIndex("reminders", "byEntry", id);
const tx = db.transaction("reminders", "readwrite");
await Promise.all(keys.map(k => tx.store.delete(k)));
await tx.done;
```

**`searchEntries`**: Full in-memory scan. Searches `title`, `tags[]`, and `notes[].text`. Case-insensitive. Returns all entries if query is empty.

---

## `format.ts`

Pure formatting utilities. All functions accept `Date | number` (epoch ms).

| Export | Signature | Output example |
|---|---|---|
| `dayKey` | `(d) => string` | `"2026-05-21"` |
| `monthKey` | `(d) => string` | `"2026-05"` |
| `yearKey` | `(d) => string` | `"2026"` |
| `fmtTime` | `(d) => string` | `"14:35"` |
| `fmtDayLabel` | `(d) => string` | `"Thursday, 21 May"` |
| `fmtShortDay` | `(d) => string` | `"Thu 21"` |
| `fmtMonth` | `(d) => string` | `"May 2026"` |
| `weekRangeLabel` | `(d: Date) => string` | `"19 May – 25 May"` |
| `weekNumber` | `(d: Date) => number` | ISO week number, Monday-start |
| `uid` | `() => string` | `"abc123xyz"` — random base36 + epoch base36 |
| `formatDuration` | `(ms: number) => string` | `"2:07"` — M:SS |
| `formatBytes` | `(n: number) => string` | `"1.4 MB"` / `"340 KB"` / `"512 B"` |

Uses `date-fns` v4 for all date formatting. Week start: Monday (`weekStartsOn: 1`).

---

## `image.ts`

Image processing utilities to prevent memory crashes on mobile when storing large camera photos.

### `downscaleImage(file: File | Blob, name?: string): Promise<Blob>`

| Constant | Value |
|---|---|
| `MAX_EDGE` | `1800` px |
| `QUALITY` | `0.85` JPEG |

**Algorithm**:
1. Skip files < 600 KB (already small enough)
2. `createImageBitmap()` to decode
3. Calculate scale factor: `min(1, 1800 / max(width, height))`
4. Use `OffscreenCanvas` if available, else regular `<canvas>`
5. Export as `image/jpeg`
6. If result is larger than source (rare), return original
7. Always closes the `ImageBitmap` (`bmp.close?.()`)

### `getImageDimensions(blob: Blob): Promise<{width, height} | null>`

Decodes blob via `createImageBitmap`, extracts dimensions, closes bitmap. Returns `null` on failure.

---

## `reminders.ts`

Client-side notification scheduling using `setTimeout`. Not push-based — requires the tab to be open.

### `requestNotificationPermission(): Promise<NotificationPermission>`

Requests browser notification permission if not already granted/denied. No-ops if Notification API unavailable.

### `rescheduleAll(): Promise<void>`

Called on every `AppShell` mount and after any reminder is created.

1. Clears all existing `setTimeout` handles from the `scheduled` Map
2. Fetches all reminders from IDB
3. For each pending reminder:
   - If `at` is in the past → fires immediately
   - If within next 24h → schedules `setTimeout`
   - If beyond 24h → skips (browser timer accuracy degrades)
4. `fire(r)`: shows `new Notification("Dispatch Diary", { body: r.text, tag: r.id })`, sets `r.done = true`, calls `updateReminder(r)`

**Limitation**: Reminders only work while the tab is open. No Service Worker push or Background Sync.

---

## `templates.ts`

Quick-fill entry templates for the new entry form.

```ts
interface QuickTemplate {
  label: string;       // Button label in UI
  title: string;       // Pre-filled entry title (user appends identifier)
  tags: string[];      // Pre-filled tags
  withCounter?: boolean; // Whether to enable trip counter
}
```

### Templates

| Label | Title prefix | Tags | Counter |
|---|---|---|---|
| Tyre count | `"Tyre count – "` | tyres, count | ✓ |
| Tyre issue | `"Tyre issue – "` | tyres, urgent | |
| Driver issue | `"Driver – "` | driver | |
| Invoice mismatch | `"Invoice mismatch – "` | invoice | |
| Missing stock | `"Missing stock – "` | stock | |
| Loading delay | `"Loading delay – Bay "` | loading, dispatch | |
| Damage report | `"Damage – "` | damage, urgent | |

Applying a template merges its tags with existing tags (`Set` dedup) and sets title.

---

## `error-capture.ts`

Out-of-band error capture for the Cloudflare Workers SSR context. h3 (the underlying HTTP framework used by TanStack Start) swallows in-handler throws into generic 500 JSON responses, losing the original error object.

This module:
1. Attaches global `error` and `unhandledrejection` listeners
2. Records the most recent error with a timestamp
3. Exports `consumeLastCapturedError()` — read-once, TTL 5 seconds

Used by `server.ts` to recover the original error when it detects an h3 swallowed 500.

---

## `error-page.ts`

Returns a minimal inline HTML string for the fallback error page. Light theme (not Midnight Indigo) because it must render without any CSS bundle.

```ts
export function renderErrorPage(): string
```

Used by both `server.ts` and `start.ts`.

---

## `utils.ts`

```ts
export function cn(...inputs: ClassValue[]): string
```

Standard `clsx` + `tailwind-merge` helper. Used by shadcn/ui components in `src/components/ui/`.
