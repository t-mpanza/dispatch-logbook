export type AttachmentKind = "audio" | "image" | "video" | "file";

export interface Attachment {
  id: string;
  kind: AttachmentKind;
  blob: Blob;
  mime: string;
  name?: string;
  durationMs?: number;
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

export interface Entry {
  id: string;
  title: string;
  tags: string[];
  notes: NoteBlock[];
  attachments: Attachment[];
  createdAt: number;
  updatedAt: number;
  // local date key YYYY-MM-DD for fast day queries
  dayKey: string;
  monthKey: string; // YYYY-MM
  yearKey: string; // YYYY
}
