# Project: Dispatch Diary Extension

## Architecture

- **Framework & Routing**: React 19, TanStack Start & Router (file-based routing under `src/routes/`), Tailwind CSS v4.
- **Local Persistence & Offline First**: IndexedDB (`dispatch-diary` DB via `idb`) holding `entries` and `reminders`. Attachments stored locally as Blobs or downloaded on demand.
- **Cloud Synchronization**: Supabase Client (`src/lib/supabase.ts`), PostgreSQL DB (`entries`, `entry_attachments`), Supabase Storage (`attachments` bucket), Real-time channels (`supabase.channel`).
- **Media Engine**: `InAppCamera.tsx`, `image.ts` (`OffscreenCanvas` downscaler), `Lightbox.tsx`, `AttachmentView.tsx`.
- **Compliance & Exports**: Loading Sheet presets manager (`src/lib/loading-presets.ts`), Printable PDF exporter & CSS print rules (`src/lib/export-pdf.ts`), WhatsApp text formatter (`src/lib/export-whatsapp.ts`).

## Code Layout

- `src/lib/types.ts`: Extended TypeScript interfaces (`LoadingSheetTrip`, `Entry`, `Attachment`, `SyncStatus`, `PresetConfig`).
- `src/lib/db.ts`: IndexedDB store operations (`updateEntryWithoutPush`, `localUpdateEntry`, `getSettings`, `saveSettings`).
- `src/lib/sync.ts`: Supabase push/pull engine, storage upload/download, remote delete cleanup, realtime subscription management.
- `src/lib/loading-presets.ts`: Route presets (DBN, NLS, BLOEM, PLK, STOCKS daily counter, NLH auto-fill, TIREPOINT).
- `src/lib/export-pdf.ts` & `src/lib/export-whatsapp.ts`: PDF generation & WhatsApp message share formatters.
- `src/lib/haptics.ts`: Haptic feedback wrapper (`navigator.vibrate`).
- `src/components/LoadingSheet.tsx`: Digital Loading Sheet table, header (Despatcher Name, Date), presets selector, manual truck entry form, summary footer, PDF & WhatsApp export action buttons.
- `src/components/ChatBubbleLog.tsx`: WhatsApp/Telegram-style event log with chat bubble bubbles, inline media previews, and sync status badges.
- `src/components/SyncBadge.tsx`: Per-item sync status badge (`Sent` / `Synced` / `Offline saved`).

## Milestones

| #   | Name                                          | Scope                                                                                                                     | Dependencies | Status      |
| --- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------ | ----------- |
| 0   | E2E Testing Track                             | Opaque-box E2E test runner, Tiers 1-4 test cases per requirements, publish `TEST_READY.md`                                | none         | IN_PROGRESS |
| 1   | Despatch Loading Sheet Compliance System      | Header, active columns, presets (STOCKS, NLH, etc.), auto-times, manual rows, PDF report export, WhatsApp text share (R1) | none         | IN_PROGRESS |
| 2   | Multi-Device Media Sync & Storage Repair      | Fix re-push sync loop, `entry_attachments` pull/merge, fresh install restoration, storage object deletion cleanup (R3)    | M1           | PLANNED     |
| 3   | Companion PWA View & Realtime Sync            | Real-time Supabase subscriptions, per-item sync badges (`Sent`/`Synced`/`Offline saved`), PWA offline caching (R2)        | M2           | PLANNED     |
| 4   | WhatsApp/Telegram-Style UI & Tactile Feedback | Chat bubble layout for timeline, rich media gallery & lightbox, `navigator.vibrate` haptic feedback (R4)                  | M3           | PLANNED     |
| 5   | E2E Test Suite Pass & Adversarial Hardening   | Pass 100% of E2E test suite (Tiers 1-4) and Tier 5 white-box adversarial coverage hardening                               | M0, M4       | PLANNED     |

## Interface Contracts

### 1. LoadingSheetTrip & Presets Contract (`src/lib/types.ts` & `src/lib/loading-presets.ts`)

```ts
export type PresetKey = "DBN" | "NLS" | "BLOEM" | "PLK" | "STOCKS" | "NLH" | "TIREPOINT" | "CUSTOM";

export interface LoadingSheetTrip {
  id: string;
  reg: string; // Truck registration plate (e.g. "MN05XNGP")
  driverName: string; // Driver name (e.g. "Neil")
  tripId: string; // Trip ID preset or custom text (e.g. "STOCKS 1", "NLH")
  presetKey?: PresetKey;
  startTime?: number; // Epoch timestamp of 1st scan
  finishTime?: number; // Epoch timestamp of last scan
  durationMinutes?: number; // Calculated duration (finishTime - startTime) in minutes
  quantityLoaded: number; // Tyres loaded count
  rejectedCount?: number;
  note?: string;
  isManual?: boolean; // Standalone manual truck entry
  createdAt: number;
}

export interface PresetFillResult {
  driverName?: string;
  reg?: string;
  tripId: string;
}
```

### 2. Sync Engine Contract (`src/lib/sync.ts` & `src/lib/db.ts`)

```ts
export type SyncItemStatus = "offline_saved" | "syncing" | "synced" | "error";

export async function localUpdateEntry(
  entry: Entry,
  options?: { skipPush?: boolean },
): Promise<void>;
export async function pullAndMerge(): Promise<void>; // Pulls entries AND entry_attachments, fetches missing media URLs/Blobs
export async function deleteRemoteEntry(id: string): Promise<void>; // Deletes entry + attachment DB rows + storage files
export function subscribeToRealtimeSync(userId: string, onUpdate: () => void): () => void;
```

### 3. Export Engine Contract (`src/lib/export-pdf.ts` & `src/lib/export-whatsapp.ts`)

```ts
export function generatePDFReport(entry: Entry, despatcherName: string): Promise<void>;
export function formatWhatsAppShareText(entry: Entry, despatcherName: string): string;
```

### 4. Haptics Contract (`src/lib/haptics.ts`)

```ts
export function triggerHaptic(type: "light" | "medium" | "heavy" | "success" | "error"): void;
```
