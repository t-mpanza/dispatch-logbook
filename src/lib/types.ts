export type AttachmentKind = "audio" | "image" | "video" | "file";

export interface Attachment {
  id: string;
  kind: AttachmentKind;
  blob?: Blob;
  mime: string;
  name?: string;
  caption?: string;
  durationMs?: number;
  width?: number;
  height?: number;
  storagePath?: string;
  downloadUrl?: string;
  createdAt: number;
}

export interface NoteBlock {
  id: string;
  text: string;
  createdAt: number;
}

export interface Reminder {
  id: string;
  entryId: string;
  at: number; // epoch ms
  text: string;
  done: boolean;
}

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
  presetKey?: PresetKey;
  driverName?: string;
  reg?: string;
  tripId: string;
}

export interface Trip {
  id: string;
  count: number;
  rejected?: number;
  note?: string;
  createdAt: number;
}

export interface Entry {
  id: string;
  title: string;
  tags: string[];
  notes: NoteBlock[];
  attachments: Attachment[];
  trips?: Trip[];
  loadingSheetTrips?: LoadingSheetTrip[];
  expectedTotal?: number; // invoice tyre count for progress tracking
  createdAt: number;
  updatedAt: number;
  // local date key YYYY-MM-DD for fast day queries
  dayKey: string;
  monthKey: string; // YYYY-MM
  yearKey: string; // YYYY
}

export type SyncItemStatus = "offline_saved" | "syncing" | "synced" | "error";

export interface LoadingSheetHeader {
  date: string; // YYYY-MM-DD
  despatcherName: string;
}
