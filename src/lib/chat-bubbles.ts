import type { Attachment, Entry, NoteBlock, SyncItemStatus, Trip } from "./types.ts";

export type BubbleKind = "note" | "audio" | "image" | "video" | "file" | "trip";

export interface ChatBubbleItem {
  id: string;
  kind: BubbleKind;
  text?: string;
  attachment?: Attachment;
  trip?: Trip;
  createdAt: number;
  syncStatus: SyncItemStatus;
  timeString: string;
}

export function formatBubbleTime(timestamp: number): string {
  const d = new Date(timestamp);
  const hours = d.getHours().toString().padStart(2, "0");
  const mins = d.getMinutes().toString().padStart(2, "0");
  return `${hours}:${mins}`;
}

export function entryToChatBubbles(
  entry: Entry,
  syncStatus: SyncItemStatus = "synced",
): ChatBubbleItem[] {
  const bubbles: ChatBubbleItem[] = [];

  // Notes
  for (const n of entry.notes || []) {
    bubbles.push({
      id: n.id,
      kind: "note",
      text: n.text,
      createdAt: n.createdAt,
      syncStatus,
      timeString: formatBubbleTime(n.createdAt),
    });
  }

  // Attachments
  for (const a of entry.attachments || []) {
    bubbles.push({
      id: a.id,
      kind: a.kind,
      attachment: a,
      createdAt: a.createdAt,
      syncStatus,
      timeString: formatBubbleTime(a.createdAt),
    });
  }

  // Trips
  for (const t of entry.trips || []) {
    bubbles.push({
      id: t.id,
      kind: "trip",
      trip: t,
      text: `Trip scanned: ${t.count} tyres${t.rejected ? ` (${t.rejected} rejected)` : ""}`,
      createdAt: t.createdAt,
      syncStatus,
      timeString: formatBubbleTime(t.createdAt),
    });
  }

  // Sort chronological
  return bubbles.sort((a, b) => a.createdAt - b.createdAt);
}

export interface LightboxState {
  isOpen: boolean;
  activeAttachment: Attachment | null;
  activeIndex: number;
  totalAttachments: number;
  zoomLevel: number;
}

export function createInitialLightboxState(): LightboxState {
  return {
    isOpen: false,
    activeAttachment: null,
    activeIndex: 0,
    totalAttachments: 0,
    zoomLevel: 1.0,
  };
}

export function openLightbox(attachments: Attachment[], index: number): LightboxState {
  if (!attachments || attachments.length === 0 || index < 0 || index >= attachments.length) {
    return createInitialLightboxState();
  }
  return {
    isOpen: true,
    activeAttachment: attachments[index],
    activeIndex: index,
    totalAttachments: attachments.length,
    zoomLevel: 1.0,
  };
}
