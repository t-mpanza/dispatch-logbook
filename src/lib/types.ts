export type AttachmentKind = "audio" | "image" | "photo" | "video" | "file";
export type SyncItemStatus = "synced" | "pending" | "error";

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
  url?: string;
  dataUrl?: string;
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
  entryId?: string; // Reference to the parent entry
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
  presetKey: PresetKey;
  tripId: string;
  driverName?: string;
  reg?: string;
}

export interface LoadingSheetHeader {
  dateStr: string; // YYYY-MM-DD
  despatcherName: string; // Default: "Theolus"
  trips: LoadingSheetTrip[];
  totalTyresLoaded: number;
  totalLoadingTimeMinutes: number;
}

export interface Trip {
  id: string;
  label?: string;
  count: number;
  createdAt: number;
  note?: string;
  rejected?: number;
}

export interface Entry {
  id: string;
  title: string;
  tags: string[];
  expectedTotal?: number; // Target tyres expected (e.g. 100)
  notes: NoteBlock[];
  attachments: Attachment[];
  trips?: Trip[];
  loadingSheetTrips?: LoadingSheetTrip[]; // Daily compliance loading sheet trips
  despatcherName?: string; // e.g. "Theolus"
  createdAt: number; // epoch ms
  updatedAt: number;
  dayKey: string; // YYYY-MM-DD
  monthKey: string; // YYYY-MM
  yearKey: string; // YYYY
}
