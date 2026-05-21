# Routes

All routes are file-based under `src/routes/`. TanStack Router auto-generates `routeTree.gen.ts` from them.

---

## `__root.tsx` — Root layout

**Path**: all routes  
**Component**: `RootShell` (HTML document shell) + `RootComponent` (client wrapper)

### What it does
- Renders `<html>`, `<head>`, `<body>`, `<Scripts>`
- Sets global `<head>` meta: charset, viewport, title, description, theme-color, OG/Twitter tags, PWA meta
- Links: stylesheet, manifest, icon, apple-touch-icon
- `RootComponent`: wraps everything in `<QueryClientProvider>`, registers the Service Worker on mount
- Provides 404 and error boundary components

### SW registration
```ts
navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`)
```
Uses `BASE_URL` to handle both GitHub Pages (`/dispatch-logbook/`) and root deployments.

---

## `index.tsx` — Today

**Path**: `/`  
**Query**: `["entries", "day", todayKey]` → `entriesByDay(today)`

### What it does
- Shows today's date as a large heading
- Lists entries via `<EntryListItem>`
- "Yesterday" shortcut link → `/day/YYYY-MM-DD`
- FAB (fixed bottom-right) → `/entry/new`
- Empty state with `<EmptyState>` component (inline)
- Uses `<AppShell>` (bottom nav included)

---

## `entry.new.tsx` — New entry

**Path**: `/entry/new`  
**Query**: `["tags"]` → `allTags()` for tag autocomplete

### What it does
- Title input (monospace uppercase, autofocus)
- Tags input via `<TagsInput>`
- Quick templates: 7 presets that pre-fill title + tags (some enable counter)
- Trip counter toggle checkbox
- "Create" button → calls `createEntry()` then navigates to `/entry/:id`
- No `<AppShell>` — standalone header with back button

### State
| State | Type | Notes |
|---|---|---|
| `title` | string | |
| `tags` | string[] | |
| `withCounter` | boolean | Whether to initialise trips array |
| `saving` | boolean | Disables button during creation |

---

## `entry.$id.tsx` — Entry detail

**Path**: `/entry/:id`  
**Queries**: `["entry", id]`, `["reminders", id]`, `["tags"]`

### What it does
This is the heaviest route. Acts as both viewer and editor.

- Sticky header: back button, date/time label, delete button
- Title: inline editable `<input>`, saves on `onBlur`
- Tags: `<TagsInput>`, saves immediately on change
- Capture bar: `<CaptureBar>` or `<VoiceRecorder>` (toggled)
- Trip counter: `<CounterPanel>` if `entry.trips` is an array; otherwise a "Add trip counter" button
- Quick note textarea: typed note + "Add note" button
- Reminders section: shows existing, inline `<ReminderForm>` to add new
- Timeline: unified sorted list of notes + attachments + trips, rendered chronologically
- `<Lightbox>` overlay for image zoom

### `persist()` pattern
All mutations go through a single helper:
```ts
async function persist(updater: (e: Entry) => Entry) {
  const next = updater({ ...entry });
  await updateEntry(next);
  qc.invalidateQueries(["entry", id]);
  qc.invalidateQueries(["entries"]);
  qc.invalidateQueries(["tags"]);
}
```

### State
| State | Type | Notes |
|---|---|---|
| `title` | string | Local edit buffer, saves on blur |
| `tags` | string[] | Local buffer, saves immediately on change |
| `recording` | boolean | Toggles CaptureBar ↔ VoiceRecorder |
| `noteDraft` | string | Quick note textarea |
| `showReminder` | boolean | Shows/hides ReminderForm |
| `lightboxId` | string\|null | Image id to open in lightbox |

---

## `counter.tsx` — Trip count sessions

**Path**: `/counter`  
**Query**: `["entries", "counter"]` → `entriesWithCounter()`

### What it does
- Lists all entries that have `trips` array (counter sessions)
- Each card shows title, date/time, total accepted count, trip count
- "Start new count session" button → creates entry with preset title `"Tyre count – HH:mm"`, tags `["tyres","count"]`, `withCounter: true`, navigates to `/entry/:id`
- Uses `<AppShell>`

---

## `search.tsx` — Search

**Path**: `/search`  
**Queries**: `["search", q]` → `searchEntries(q)`, `["tags"]` → `allTags()`

### What it does
- Autofocused search input
- Searches title, tags, and note text (client-side, full scan)
- Shows all tags as clickable chips (tap to set as search query)
- Results list via `<EntryListItem>`
- Uses `<AppShell>`

---

## `archive.tsx` — Archive

**Path**: `/archive`  
**Query**: `["entries", "all"]` → `allEntries()`

### What it does
- Groups all entries: Year → Month → Week → Day
- Nested `<details>` disclosure (Year expands Month; Month expands Weeks; Week expands Days)
- Most recent month auto-opened (`open={m === y.months[0]}`)
- Day rows link to `/day/:date`
- Entry count badges at month and day level
- Grouping done client-side in `groupEntries()` — pure function, no memoisation currently (**perf gap**)
- Uses `<AppShell>`

### Grouping keys
- Week number via `getWeek(d, { weekStartsOn: 1 })` (Monday-based ISO weeks)
- Week label: `"Week N · D MMM – D MMM"`

---

## `day.$date.tsx` — Day drilldown

**Path**: `/day/:date`  
**Query**: `["entries", "day", date]` → `entriesByDay(date)`

### What it does
- Shows all entries for a specific date
- Sticky header: back to `/archive`, date label, prev/next day buttons
- No FAB — use Today or entry.new for creation
- No `<AppShell>` — standalone layout
- Date parsing with `date-fns` `parseISO`; graceful fallback if parse fails
