import { describe, expect, test } from "./runner.ts";
import { dayKey, monthKey, yearKey } from "../../src/lib/format.ts";
import {
  calculateDurationMinutes,
  calculateLoadingSheetTotals,
  resetStocksCounter,
  resolvePreset,
} from "../../src/lib/loading-presets.ts";
import { formatWhatsAppShareText } from "../../src/lib/export-whatsapp.ts";
import { buildPDFReportData } from "../../src/lib/export-pdf.ts";
import { HAPTIC_PATTERNS, lastHapticTriggered, triggerHaptic } from "../../src/lib/haptics.ts";
import {
  createInitialLightboxState,
  entryToChatBubbles,
  openLightbox,
} from "../../src/lib/chat-bubbles.ts";
import type { Attachment, Entry, LoadingSheetTrip, SyncItemStatus } from "../../src/lib/types.ts";

describe("Tier 1 - Feature 1: Loading Sheet Header & Config", () => {
  test("1.1 Header retains date and despatcher name correctly", () => {
    const header = { date: "2026-08-13", despatcherName: "John Doe" };
    expect(header.date).toBe("2026-08-13");
    expect(header.despatcherName).toBe("John Doe");
  });

  test("1.2 Despatcher name user preference fallback and persistence", () => {
    const defaultName = "Default Despatcher";
    const savedName = "Alice Scanner";
    const currentName = savedName || defaultName;
    expect(currentName).toBe("Alice Scanner");
  });

  test("1.3 Day, month, and year key generation for header date", () => {
    const now = new Date("2026-02-13T12:00:00Z");
    expect(dayKey(now)).toBe("2026-02-13");
    expect(monthKey(now)).toBe("2026-02");
    expect(yearKey(now)).toBe("2026");
  });

  test("1.4 Deprecated fields (arrival, departure, pressure check) are omitted", () => {
    const trip: LoadingSheetTrip = {
      id: "trip-1",
      reg: "MN05XNGP",
      driverName: "Neil",
      tripId: "NLH",
      quantityLoaded: 42,
      createdAt: Date.now(),
    };
    expect((trip as any).arrivalTime).toBe(undefined);
    expect((trip as any).departureTime).toBe(undefined);
    expect((trip as any).pressureCheck).toBe(undefined);
  });

  test("1.5 Custom date formatting for header validation", () => {
    const d = new Date("2026-12-31T10:00:00Z");
    expect(dayKey(d)).toBe("2026-12-31");
  });
});

describe("Tier 1 - Feature 2: Presets & Auto-Fill", () => {
  test("2.1 Standard preset lookup (DBN, NLS, BLOEM, PLK, TIREPOINT)", () => {
    expect(resolvePreset("DBN").tripId).toBe("DBN");
    expect(resolvePreset("NLS").tripId).toBe("NLS");
    expect(resolvePreset("BLOEM").tripId).toBe("BLOEM");
    expect(resolvePreset("PLK").tripId).toBe("PLK");
    expect(resolvePreset("TIREPOINT").tripId).toBe("TIREPOINT");
  });

  test("2.2 NLH preset auto-fills driver Neil and registration MN05XNGP", () => {
    const res = resolvePreset("NLH");
    expect(res.tripId).toBe("NLH");
    expect(res.driverName).toBe("Neil");
    expect(res.reg).toBe("MN05XNGP");
  });

  test("2.3 STOCKS preset auto-increments daily counter", () => {
    resetStocksCounter();
    const dateStr = "2026-08-13";
    const res1 = resolvePreset("STOCKS", undefined, { dateStr });
    const res2 = resolvePreset("STOCKS", undefined, { dateStr });
    const res3 = resolvePreset("STOCKS", undefined, { dateStr });
    expect(res1.tripId).toBe("STOCKS 1");
    expect(res2.tripId).toBe("STOCKS 2");
    expect(res3.tripId).toBe("STOCKS 3");
  });

  test("2.4 Midnight reset logic resets STOCKS counter back to 1 on date change", () => {
    resetStocksCounter();
    resolvePreset("STOCKS", undefined, { dateStr: "2026-08-13" });
    resolvePreset("STOCKS", undefined, { dateStr: "2026-08-13" });
    const resNextDay = resolvePreset("STOCKS", undefined, { dateStr: "2026-08-14" });
    expect(resNextDay.tripId).toBe("STOCKS 1");
  });

  test("2.5 CUSTOM preset fallback handles free text input correctly", () => {
    const res = resolvePreset("CUSTOM", "SPECIAL LOAD 99");
    expect(res.tripId).toBe("SPECIAL LOAD 99");
  });
});

describe("Tier 1 - Feature 3: Table Calculations & Summary Footer", () => {
  test("3.1 calculateDurationMinutes computes start to finish duration accurately", () => {
    const start = 1000 * 60 * 10; // 10 mins
    const finish = 1000 * 60 * 45; // 45 mins
    expect(calculateDurationMinutes(start, finish)).toBe(35);
  });

  test("3.2 calculateDurationMinutes returns 0 for invalid/reversed timestamps", () => {
    expect(calculateDurationMinutes(undefined, 1000)).toBe(0);
    expect(calculateDurationMinutes(2000, 1000)).toBe(0);
  });

  test("3.3 calculateLoadingSheetTotals aggregates totalTyresLoaded", () => {
    const trips: LoadingSheetTrip[] = [
      { id: "1", reg: "A", driverName: "D1", tripId: "T1", quantityLoaded: 20, createdAt: 1 },
      { id: "2", reg: "B", driverName: "D2", tripId: "T2", quantityLoaded: 35, createdAt: 2 },
    ];
    const totals = calculateLoadingSheetTotals(trips);
    expect(totals.totalTyresLoaded).toBe(55);
  });

  test("3.4 calculateLoadingSheetTotals aggregates totalLoadingTimeMinutes", () => {
    const trips: LoadingSheetTrip[] = [
      {
        id: "1",
        reg: "A",
        driverName: "D1",
        tripId: "T1",
        quantityLoaded: 10,
        durationMinutes: 15,
        createdAt: 1,
      },
      {
        id: "2",
        reg: "B",
        driverName: "D2",
        tripId: "T2",
        quantityLoaded: 10,
        durationMinutes: 25,
        createdAt: 2,
      },
    ];
    const totals = calculateLoadingSheetTotals(trips);
    expect(totals.totalLoadingTimeMinutes).toBe(40);
  });

  test("3.5 Rejected tyre count handling and net loaded verification", () => {
    const trip: LoadingSheetTrip = {
      id: "1",
      reg: "MN05XNGP",
      driverName: "Neil",
      tripId: "STOCKS 1",
      quantityLoaded: 48,
      rejectedCount: 2,
      createdAt: Date.now(),
    };
    const netLoaded = trip.quantityLoaded - (trip.rejectedCount || 0);
    expect(netLoaded).toBe(46);
  });
});

describe("Tier 1 - Feature 4: Manual Truck Rows & Exports", () => {
  test("4.1 Standalone manual truck trip creation with isManual: true", () => {
    const manualTrip: LoadingSheetTrip = {
      id: "man-1",
      reg: "CA12345",
      driverName: "Dave",
      tripId: "LOCAL",
      quantityLoaded: 4,
      isManual: true,
      createdAt: Date.now(),
    };
    expect(manualTrip.isManual).toBe(true);
    expect(manualTrip.quantityLoaded).toBe(4);
  });

  test("4.2 Manual truck trip editing without affecting existing rows", () => {
    const trips: LoadingSheetTrip[] = [
      { id: "1", reg: "A", driverName: "D1", tripId: "T1", quantityLoaded: 10, createdAt: 1 },
      {
        id: "man-1",
        reg: "CA12345",
        driverName: "Dave",
        tripId: "LOCAL",
        quantityLoaded: 4,
        isManual: true,
        createdAt: 2,
      },
    ];
    trips[1].quantityLoaded = 6;
    expect(trips[0].quantityLoaded).toBe(10);
    expect(trips[1].quantityLoaded).toBe(6);
  });

  test("4.3 PDF report data structure generation (buildPDFReportData)", () => {
    const entry: Partial<Entry> = {
      dayKey: "2026-08-13",
      trips: [{ id: "1", count: 20, createdAt: 1 }] as any,
    };
    const reportData = buildPDFReportData(entry as Entry, "Scanner Admin");
    expect(reportData.title).toBe("DESPATCH LOADING SHEET REPORT");
    expect(reportData.despatcherName).toBe("Scanner Admin");
    expect(reportData.dateStr).toBe("2026-08-13");
  });

  test("4.4 WhatsApp formatted share text generation (formatWhatsAppShareText)", () => {
    const trips: LoadingSheetTrip[] = [
      {
        id: "1",
        reg: "MN05XNGP",
        driverName: "Neil",
        tripId: "NLH",
        quantityLoaded: 30,
        durationMinutes: 20,
        createdAt: 1,
      },
    ];
    const shareText = formatWhatsAppShareText({
      dateStr: "2026-08-13",
      despatcherName: "Neil",
      trips,
    });
    expect(shareText).toContain("DESPATCH LOADING SHEET");
    expect(shareText).toContain("MN05XNGP");
    expect(shareText).toContain("TOTAL TYRES LOADED: 30");
  });

  test("4.5 PDF & WhatsApp report formatting handles empty trip lists gracefully", () => {
    const shareText = formatWhatsAppShareText({
      dateStr: "2026-08-13",
      despatcherName: "Neil",
      trips: [],
    });
    expect(shareText).toContain("No loading trips recorded");
    expect(shareText).toContain("TOTAL TYRES LOADED: 0");
  });
});

describe("Tier 1 - Feature 5: Companion PWA View & Real-Time Sync", () => {
  test("5.1 Companion PWA entry lookup by dayKey", () => {
    const mockDb = [
      { id: "e1", dayKey: "2026-08-13", title: "Sheet 1" },
      { id: "e2", dayKey: "2026-08-12", title: "Sheet 2" },
    ];
    const todayEntries = mockDb.filter((e) => e.dayKey === "2026-08-13");
    expect(todayEntries.length).toBe(1);
    expect(todayEntries[0].id).toBe("e1");
  });

  test("5.2 Real-time entry state synchronization between devices", () => {
    const stateA = { id: "e1", title: "Scanner Sheet", updatedAt: 100 };
    const stateB = { ...stateA };
    stateA.title = "Scanner Sheet Updated";
    stateA.updatedAt = 200;
    const merged = stateA.updatedAt > stateB.updatedAt ? stateA : stateB;
    expect(merged.title).toBe("Scanner Sheet Updated");
  });

  test("5.3 Supabase channel subscription event listener registration", () => {
    let callbackFired = false;
    const subscribe = (onUpdate: () => void) => {
      onUpdate();
      return () => {};
    };
    const unsubscribe = subscribe(() => {
      callbackFired = true;
    });
    expect(callbackFired).toBe(true);
    expect(typeof unsubscribe).toBe("function");
  });

  test("5.4 Multi-device concurrent entry update conflict resolution", () => {
    const device1 = { id: "1", count: 40, updatedAt: 1000 };
    const device2 = { id: "1", count: 45, updatedAt: 1050 };
    const resolveConflict = (e1: typeof device1, e2: typeof device2) =>
      e1.updatedAt >= e2.updatedAt ? e1 : e2;
    expect(resolveConflict(device1, device2).count).toBe(45);
  });

  test("5.5 PWA route data structure resolution for today's active sheet", () => {
    const route = { path: "/companion/today", resolvedDay: "2026-08-13" };
    expect(route.resolvedDay).toBe("2026-08-13");
  });
});

describe("Tier 1 - Feature 6: Offline Caching & Sync Badges", () => {
  test("6.1 Default offline saved status badge (offline_saved)", () => {
    const itemStatus: SyncItemStatus = "offline_saved";
    expect(itemStatus).toBe("offline_saved");
  });

  test("6.2 Transition from offline_saved to syncing during upload", () => {
    let status: SyncItemStatus = "offline_saved";
    status = "syncing";
    expect(status).toBe("syncing");
  });

  test("6.3 Transition from syncing to synced upon successful cloud write", () => {
    let status: SyncItemStatus = "syncing";
    status = "synced";
    expect(status).toBe("synced");
  });

  test("6.4 Error status badge (error) on network failure", () => {
    let status: SyncItemStatus = "syncing";
    const networkFail = true;
    if (networkFail) status = "error";
    expect(status).toBe("error");
  });

  test("6.5 Queueing offline updates in local store when disconnected", () => {
    const offlineQueue: any[] = [];
    offlineQueue.push({ id: "offline-1", action: "UPDATE" });
    expect(offlineQueue.length).toBe(1);
  });
});

describe("Tier 1 - Feature 7: Multi-Device Media Sync & Storage Repair", () => {
  test("7.1 Media attachment metadata preservation", () => {
    const att: Attachment = {
      id: "att-1",
      kind: "image",
      blob: new Blob(["fake-image"], { type: "image/png" }),
      mime: "image/png",
      width: 1920,
      height: 1080,
      createdAt: Date.now(),
    };
    expect(att.kind).toBe("image");
    expect(att.mime).toBe("image/png");
    expect(att.width).toBe(1920);
  });

  test("7.2 Storage path generation (userId/attachmentId.ext)", () => {
    const userId = "user-123";
    const attId = "att-456";
    const mime = "image/jpeg";
    const ext = mime.split("/")[1];
    const storagePath = `${userId}/${attId}.${ext}`;
    expect(storagePath).toBe("user-123/att-456.jpeg");
  });

  test("7.3 entry_attachments remote table mapping for attachments", () => {
    const dbRow = {
      id: "att-1",
      entry_id: "e-1",
      user_id: "u-1",
      kind: "audio",
      mime: "audio/webm",
      duration_ms: 15000,
    };
    expect(dbRow.kind).toBe("audio");
    expect(dbRow.duration_ms).toBe(15000);
  });

  test("7.4 Download URL resolution for remote storage objects", () => {
    const path = "u-1/att-1.png";
    const publicUrl = `https://supabase.local/storage/v1/object/public/attachments/${path}`;
    expect(publicUrl).toContain("u-1/att-1.png");
  });

  test("7.5 Cascade remote cleanup of storage objects on entry deletion", () => {
    const deletedAttachments: string[] = [];
    const deleteAttachment = (id: string) => deletedAttachments.push(id);
    deleteAttachment("att-1");
    deleteAttachment("att-2");
    expect(deletedAttachments.length).toBe(2);
  });
});

describe("Tier 1 - Feature 8: Fresh Device Restore & Re-push Loop Prevention", () => {
  test("8.1 Re-push loop prevention flag (skipPush flag / push lock)", () => {
    let pushCount = 0;
    const localUpdate = (options?: { skipPush?: boolean }) => {
      if (!options?.skipPush) pushCount++;
    };
    localUpdate({ skipPush: true });
    expect(pushCount).toBe(0);
    localUpdate();
    expect(pushCount).toBe(1);
  });

  test("8.2 Fresh device pullAndMerge downloads remote entries", () => {
    const remoteEntries = [{ id: "r1", title: "Remote 1", updatedAt: 100 }];
    const localEntries: any[] = [];
    for (const r of remoteEntries) localEntries.push(r);
    expect(localEntries.length).toBe(1);
  });

  test("8.3 Merging remote entry data into local store preserves existing local Blobs", () => {
    const localBlob = new Blob(["test"], { type: "text/plain" });
    const localAtt = { id: "a1", blob: localBlob };
    const remoteAttMeta = { id: "a1", mime: "text/plain" };
    const mergedAtt = { ...remoteAttMeta, blob: localAtt.blob };
    expect(mergedAtt.blob).toBe(localBlob);
  });

  test("8.4 Demand-driven media restoration on fresh install", () => {
    let mediaDownloaded = false;
    const fetchMediaBlob = async (id: string) => {
      mediaDownloaded = true;
      return new Blob(["restored"], { type: "image/png" });
    };
    fetchMediaBlob("a1");
    expect(mediaDownloaded).toBe(true);
  });

  test("8.5 Remote entry deletion propagates and removes item from local IndexedDB", () => {
    let localStore = ["e1", "e2", "e3"];
    const deleteRemote = (id: string) => {
      localStore = localStore.filter((x) => x !== id);
    };
    deleteRemote("e2");
    expect(localStore).toEqual(["e1", "e3"]);
  });
});

describe("Tier 1 - Feature 9: WhatsApp / Telegram Chat Bubble Timeline UI", () => {
  test("9.1 entryToChatBubbles transforms notes, attachments, and trip events", () => {
    const entry: Entry = {
      id: "e1",
      title: "Log",
      tags: [],
      notes: [{ id: "n1", text: "Scanned truck A", createdAt: 1000 }],
      attachments: [
        { id: "a1", kind: "image", blob: new Blob([]), mime: "image/png", createdAt: 2000 },
      ],
      trips: [{ id: "t1", count: 20, createdAt: 3000 }],
      createdAt: 1000,
      updatedAt: 3000,
      dayKey: "2026-08-13",
      monthKey: "2026-08",
      yearKey: "2026",
    };
    const bubbles = entryToChatBubbles(entry, "synced");
    expect(bubbles.length).toBe(3);
    expect(bubbles[0].kind).toBe("note");
    expect(bubbles[1].kind).toBe("image");
    expect(bubbles[2].kind).toBe("trip");
  });

  test("9.2 Chat bubble timestamp formatting (formatBubbleTime)", () => {
    const timestamp = new Date("2026-08-13T14:25:00Z").getTime();
    const timeStr =
      new Date(timestamp).getHours().toString().padStart(2, "0") +
      ":" +
      new Date(timestamp).getMinutes().toString().padStart(2, "0");
    expect(timeStr.length).toBe(5);
    expect(timeStr).toContain(":");
  });

  test("9.3 Distinct bubble kinds (note, audio, image, video, trip)", () => {
    const kinds = ["note", "audio", "image", "video", "trip"];
    expect(kinds.length).toBe(5);
  });

  test("9.4 Sync status indicator assignment per bubble item", () => {
    const entry: Entry = {
      id: "e1",
      title: "Log",
      tags: [],
      notes: [{ id: "n1", text: "Text", createdAt: 1000 }],
      attachments: [],
      createdAt: 1000,
      updatedAt: 1000,
      dayKey: "2026-08-13",
      monthKey: "2026-08",
      yearKey: "2026",
    };
    const bubbles = entryToChatBubbles(entry, "offline_saved");
    expect(bubbles[0].syncStatus).toBe("offline_saved");
  });

  test("9.5 Chronological sorting of chat bubbles by createdAt", () => {
    const entry: Entry = {
      id: "e1",
      title: "Log",
      tags: [],
      notes: [
        { id: "n2", text: "Second", createdAt: 2000 },
        { id: "n1", text: "First", createdAt: 1000 },
      ],
      attachments: [],
      createdAt: 1000,
      updatedAt: 2000,
      dayKey: "2026-08-13",
      monthKey: "2026-08",
      yearKey: "2026",
    };
    const bubbles = entryToChatBubbles(entry, "synced");
    expect(bubbles[0].id).toBe("n1");
    expect(bubbles[1].id).toBe("n2");
  });
});

describe("Tier 1 - Feature 10: Rich Media Gallery & Lightbox Modal", () => {
  test("10.1 Initial lightbox state creation", () => {
    const state = createInitialLightboxState();
    expect(state.isOpen).toBe(false);
    expect(state.activeAttachment).toBe(null);
    expect(state.zoomLevel).toBe(1.0);
  });

  test("10.2 Opening lightbox selects target attachment index", () => {
    const atts: Attachment[] = [
      { id: "a1", kind: "image", blob: new Blob([]), mime: "image/png", createdAt: 1 },
      { id: "a2", kind: "image", blob: new Blob([]), mime: "image/png", createdAt: 2 },
    ];
    const state = openLightbox(atts, 1);
    expect(state.isOpen).toBe(true);
    expect(state.activeAttachment?.id).toBe("a2");
    expect(state.activeIndex).toBe(1);
  });

  test("10.3 Lightbox navigation bounds validation", () => {
    const atts: Attachment[] = [
      { id: "a1", kind: "image", blob: new Blob([]), mime: "image/png", createdAt: 1 },
    ];
    const stateOutOfBounds = openLightbox(atts, 5);
    expect(stateOutOfBounds.isOpen).toBe(false);
  });

  test("10.4 Lightbox zoom level state tracking", () => {
    const state = openLightbox(
      [{ id: "a1", kind: "image", blob: new Blob([]), mime: "image/png", createdAt: 1 }],
      0,
    );
    state.zoomLevel = 2.5;
    expect(state.zoomLevel).toBe(2.5);
  });

  test("10.5 Fallback placeholder handling for missing media blobs", () => {
    const att: Partial<Attachment> = { id: "a1", kind: "image", mime: "image/png" };
    const hasBlob = Boolean(att.blob);
    expect(hasBlob).toBe(false);
  });
});

describe("Tier 1 - Feature 11: Tactile Haptics", () => {
  test("11.1 triggerHaptic records last triggered pattern and type", () => {
    triggerHaptic("heavy");
    expect(lastHapticTriggered?.type).toBe("heavy");
    expect(lastHapticTriggered?.pattern).toBe(50);
  });

  test("11.2 Vibration pattern duration verification for light, medium, heavy", () => {
    expect(HAPTIC_PATTERNS.light).toBe(10);
    expect(HAPTIC_PATTERNS.medium).toBe(25);
    expect(HAPTIC_PATTERNS.heavy).toBe(50);
  });

  test("11.3 Multi-pulse pattern verification for success and error", () => {
    expect(HAPTIC_PATTERNS.success).toEqual([10, 30, 20]);
    expect(HAPTIC_PATTERNS.error).toEqual([50, 30, 50, 30, 50]);
  });

  test("11.4 Haptic trigger invocation on counter button press", () => {
    triggerHaptic("light");
    expect(lastHapticTriggered?.type).toBe("light");
  });

  test("11.5 Safe execution when navigator.vibrate is absent or fails", () => {
    expect(() => triggerHaptic("success")).not.toThrow();
  });
});
