# Data Model

## TypeScript types (`src/lib/types.ts`)

### `AttachmentKind`

```ts
type AttachmentKind = "audio" | "image" | "video" | "file";
```

---

### `Attachment`

Stored inline on the parent `Entry`. Blobs live directly in IDB — no separate object store.

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | `uid()` — random base36 + epoch |
| `kind` | `AttachmentKind` | Determines how `AttachmentView` renders |
| `blob` | `Blob` | Raw binary — image/audio/video/file |
| `mime` | `string` | MIME type string e.g. `"image/jpeg"` |
| `name` | `string?` | Original filename, optional |
| `durationMs` | `number?` | Audio only — recording duration in ms |
| `width` | `number?` | Image only — pixel width after downscale |
| `height` | `number?` | Image only — pixel height after downscale |
| `createdAt` | `number` | Epoch ms |

Images are downscaled to ≤ 1800px longest edge, JPEG 0.85 quality before being stored.

---

### `NoteBlock`

Free-text note item in the entry timeline.

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | `uid()` |
| `text` | `string` | Raw text content |
| `createdAt` | `number` | Epoch ms |

---

### `Reminder`

Notification reminder tied to an entry. Stored in a separate IDB object store.

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | `uid()` |
| `entryId` | `string` | FK → `Entry.id` (enforced in app, not IDB) |
| `at` | `number` | Epoch ms — when to fire |
| `text` | `string` | Notification body text |
| `done` | `boolean` | Set to `true` after notification fires |

---

### `Trip`

A single trip count event within a counter session.

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | `uid()` |
| `count` | `number` | Accepted tyre/trip count |
| `rejected` | `number?` | Rejected count, optional |
| `note` | `string?` | Free-text note e.g. driver name, batch # |
| `createdAt` | `number` | Epoch ms |

---

### `Entry`

The root document. Everything except reminders hangs off this.

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | `uid()` — IDB keyPath |
| `title` | `string` | Shown uppercase monospace. Defaults to `"Untitled"` |
| `tags` | `string[]` | Lowercase, no `#` prefix stored |
| `notes` | `NoteBlock[]` | Ordered by `createdAt` in timeline |
| `attachments` | `Attachment[]` | All media blobs inline |
| `trips` | `Trip[]?` | `undefined` = no counter. `[]` = counter enabled, no trips yet |
| `createdAt` | `number` | Epoch ms |
| `updatedAt` | `number` | Updated by every `updateEntry()` call |
| `dayKey` | `string` | `"YYYY-MM-DD"` — IDB index for day queries |
| `monthKey` | `string` | `"YYYY-MM"` — IDB index for month queries |
| `yearKey` | `string` | `"YYYY"` — IDB index for year queries |

**Counter detection pattern**: `Array.isArray(entry.trips)` — presence of array (even empty) means counter is enabled.

---

## IndexedDB schema (`src/lib/db.ts`)

DB name: `dispatch-diary`  
DB version: `1`

### Object store: `entries`

| Property | Value |
|---|---|
| keyPath | `"id"` |
| Indexes | `byDay` (dayKey), `byMonth` (monthKey), `byYear` (yearKey), `byUpdated` (updatedAt) |

### Object store: `reminders`

| Property | Value |
|---|---|
| keyPath | `"id"` |
| Indexes | `byEntry` (entryId), `byAt` (at) |

---

## DB API (`src/lib/db.ts`)

| Function | Signature | Notes |
|---|---|---|
| `createEntry` | `({title, tags?, withCounter?}) → Entry` | Generates all key fields, sets `trips: []` if withCounter |
| `updateEntry` | `(entry: Entry) → void` | Sets `updatedAt = Date.now()` then puts |
| `getEntry` | `(id: string) → Entry \| undefined` | Single get by id |
| `deleteEntry` | `(id: string) → void` | Deletes entry + cascades all linked reminders |
| `entriesByDay` | `(day: string) → Entry[]` | Uses `byDay` index, sorted newest first |
| `entriesByMonth` | `(month: string) → Entry[]` | Uses `byMonth` index |
| `allEntries` | `() → Entry[]` | Full table scan, sorted newest first |
| `searchEntries` | `(q: string) → Entry[]` | Client-side filter on title, tags, notes text |
| `allTags` | `() → string[]` | Aggregates unique tags across all entries, sorted |
| `entriesWithCounter` | `() → Entry[]` | Filters `allEntries()` where `Array.isArray(trips)` |
| `addReminder` | `(Omit<Reminder, 'id'\|'done'>) → Reminder` | Auto-assigns id, done=false |
| `remindersForEntry` | `(entryId: string) → Reminder[]` | Uses `byEntry` index |
| `allReminders` | `() → Reminder[]` | Full reminders scan |
| `updateReminder` | `(r: Reminder) → void` | Full put |
| `deleteReminder` | `(id: string) → void` | Single delete |

---

## Query keys (TanStack Query)

| Key | What it represents |
|---|---|
| `["entries", "day", dayKey]` | Entries for a specific day |
| `["entries", "all"]` | All entries (archive page) |
| `["entries", "counter"]` | Entries with trip counters |
| `["entry", id]` | Single entry by id |
| `["reminders", entryId]` | Reminders for a specific entry |
| `["search", q]` | Search results for query string |
| `["tags"]` | All unique tags |

`persist()` in `entry.$id.tsx` invalidates `["entry", id]`, `["entries"]` (wildcard), and `["tags"]` on every save.
