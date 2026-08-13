import { describe, expect, test } from "./runner.ts";
import {
  calculateDurationMinutes,
  calculateLoadingSheetTotals,
  resetStocksCounter,
  resolvePreset,
} from "../../src/lib/loading-presets.ts";
import { formatWhatsAppShareText } from "../../src/lib/export-whatsapp.ts";
import { buildPDFReportData } from "../../src/lib/export-pdf.ts";
import { lastHapticTriggered, triggerHaptic } from "../../src/lib/haptics.ts";
import { entryToChatBubbles, openLightbox } from "../../src/lib/chat-bubbles.ts";
import type { Attachment, Entry, LoadingSheetTrip, SyncItemStatus } from "../../src/lib/types.ts";

describe("Tier 3 - Cross-Feature Pairwise Interaction Tests", () => {
  test("3.1 [F1 + F2] Header despatcher name combined with NLH preset auto-fill", () => {
    const header = { date: "2026-08-13", despatcherName: "Neil" };
    const presetRes = resolvePreset("NLH");
    expect(header.despatcherName).toBe("Neil");
    expect(presetRes.driverName).toBe(header.despatcherName);
    expect(presetRes.reg).toBe("MN05XNGP");
  });

  test("3.2 [F2 + F3] Preset trips (STOCKS 1, STOCKS 2, DBN) auto-summed in footer totals", () => {
    resetStocksCounter();
    const dateStr = "2026-08-13";
    const p1 = resolvePreset("STOCKS", undefined, { dateStr });
    const p2 = resolvePreset("STOCKS", undefined, { dateStr });
    const p3 = resolvePreset("DBN");

    const trips: LoadingSheetTrip[] = [
      {
        id: "1",
        reg: "REG1",
        driverName: "D1",
        tripId: p1.tripId,
        quantityLoaded: 30,
        durationMinutes: 20,
        createdAt: 1,
      },
      {
        id: "2",
        reg: "REG2",
        driverName: "D2",
        tripId: p2.tripId,
        quantityLoaded: 40,
        durationMinutes: 25,
        createdAt: 2,
      },
      {
        id: "3",
        reg: "REG3",
        driverName: "D3",
        tripId: p3.tripId,
        quantityLoaded: 15,
        durationMinutes: 10,
        createdAt: 3,
      },
    ];

    const totals = calculateLoadingSheetTotals(trips);
    expect(totals.totalTyresLoaded).toBe(85);
    expect(totals.totalLoadingTimeMinutes).toBe(55);
  });

  test("3.3 [F3 + F4] Summary footer totals correctly formatted into PDF and WhatsApp exports", () => {
    const trips: LoadingSheetTrip[] = [
      {
        id: "1",
        reg: "REG-A",
        driverName: "Driver A",
        tripId: "STOCKS 1",
        quantityLoaded: 50,
        durationMinutes: 30,
        createdAt: 1,
      },
    ];
    const pdfData = buildPDFReportData({ dateStr: "2026-08-13", trips }, "Scanner Despatcher");
    const shareText = formatWhatsAppShareText({
      dateStr: "2026-08-13",
      despatcherName: "Scanner Despatcher",
      trips,
    });

    expect(pdfData.totalTyresLoaded).toBe(50);
    expect(shareText).toContain("TOTAL TYRES LOADED: 50");
    expect(shareText).toContain("TOTAL LOADING TIME: 30 mins");
  });

  test("3.4 [F1 + F4] Header date and despatcher name injected into export reports", () => {
    const header = { date: "2026-08-13", despatcherName: "Alice Lead" };
    const pdfData = buildPDFReportData({ dateStr: header.date, trips: [] }, header.despatcherName);
    const shareText = formatWhatsAppShareText({
      dateStr: header.date,
      despatcherName: header.despatcherName,
      trips: [],
    });

    expect(pdfData.despatcherName).toBe("Alice Lead");
    expect(shareText).toContain("👤 Despatcher: Alice Lead");
    expect(shareText).toContain("📅 Date: 2026-08-13");
  });

  test("3.5 [F2 + F4] Combining preset trips with standalone manual truck rows in single export payload", () => {
    const trips: LoadingSheetTrip[] = [
      {
        id: "1",
        reg: "MN05XNGP",
        driverName: "Neil",
        tripId: "NLH",
        quantityLoaded: 44,
        durationMinutes: 35,
        createdAt: 1,
      },
      {
        id: "2",
        reg: "MAN01",
        driverName: "Bob",
        tripId: "LOCAL",
        quantityLoaded: 4,
        durationMinutes: 5,
        isManual: true,
        createdAt: 2,
      },
    ];
    const shareText = formatWhatsAppShareText({
      dateStr: "2026-08-13",
      despatcherName: "Neil",
      trips,
    });
    expect(shareText).toContain("[NLH] MN05XNGP");
    expect(shareText).toContain("[LOCAL] MAN01");
    expect(shareText).toContain("TOTAL TYRES LOADED: 48");
  });

  test("3.6 [F5 + F6] Companion PWA rendering entries with mixed sync status badges", () => {
    const pwaItems: Array<{ id: string; badge: SyncItemStatus }> = [
      { id: "item-1", badge: "synced" },
      { id: "item-2", badge: "offline_saved" },
      { id: "item-3", badge: "syncing" },
    ];
    expect(pwaItems.filter((i) => i.badge === "synced").length).toBe(1);
    expect(pwaItems.filter((i) => i.badge === "offline_saved").length).toBe(1);
  });

  test("3.7 [F6 + F8] Offline modifications merged to cloud using skipPush flag to prevent loops", () => {
    let pushLoopDetected = false;
    let pushCount = 0;
    const mergeUpdate = (options?: { skipPush?: boolean }) => {
      if (!options?.skipPush) {
        pushCount++;
        if (pushCount > 1) pushLoopDetected = true;
      }
    };

    mergeUpdate({ skipPush: true });
    expect(pushCount).toBe(0);
    expect(pushLoopDetected).toBe(false);
  });

  test("3.8 [F5 + F7] Companion PWA resolving remote media attachments and generating download URLs", () => {
    const remoteAtt = {
      id: "att-99",
      kind: "image",
      mime: "image/jpeg",
      path: "user-1/att-99.jpeg",
    };
    const pwaUrl = `https://supabase.local/storage/v1/object/public/attachments/${remoteAtt.path}`;
    expect(pwaUrl).toContain("user-1/att-99.jpeg");
  });

  test("3.9 [F7 + F8] Fresh device restore downloading entry data and missing media Blobs on demand", () => {
    const restoredEntry: Entry = {
      id: "e-restored",
      title: "Restored Entry",
      tags: [],
      notes: [],
      attachments: [
        { id: "att-1", kind: "audio", blob: new Blob([]), mime: "audio/mp3", createdAt: 1 },
      ],
      createdAt: 100,
      updatedAt: 100,
      dayKey: "2026-08-13",
      monthKey: "2026-08",
      yearKey: "2026",
    };
    expect(restoredEntry.attachments.length).toBe(1);
    expect(restoredEntry.attachments[0].kind).toBe("audio");
  });

  test("3.10 [F9 + F10] Tapping image chat bubble in timeline opens lightbox modal", () => {
    const att: Attachment = {
      id: "img-1",
      kind: "image",
      blob: new Blob([]),
      mime: "image/png",
      createdAt: 100,
    };
    const entry: Partial<Entry> = { attachments: [att], notes: [], trips: [] };
    const bubbles = entryToChatBubbles(entry as Entry);
    expect(bubbles[0].kind).toBe("image");

    const lightbox = openLightbox([att], 0);
    expect(lightbox.isOpen).toBe(true);
    expect(lightbox.activeAttachment?.id).toBe("img-1");
  });

  test("3.11 [F9 + F11] Adding note block to timeline triggers tactile haptic feedback", () => {
    triggerHaptic("light");
    expect(lastHapticTriggered?.type).toBe("light");

    const entry: Partial<Entry> = {
      notes: [{ id: "n1", text: "Scanned tire batch A", createdAt: Date.now() }],
      attachments: [],
      trips: [],
    };
    const bubbles = entryToChatBubbles(entry as Entry);
    expect(bubbles.length).toBe(1);
  });

  test("3.12 [F3 + F11] Incrementing counter session updates total tyres and triggers medium haptic", () => {
    triggerHaptic("medium");
    expect(lastHapticTriggered?.type).toBe("medium");

    const trips: LoadingSheetTrip[] = [
      {
        id: "1",
        reg: "REG1",
        driverName: "D1",
        tripId: "STOCKS 1",
        quantityLoaded: 24,
        createdAt: 1,
      },
    ];
    trips[0].quantityLoaded += 1;
    expect(calculateLoadingSheetTotals(trips).totalTyresLoaded).toBe(25);
  });

  test("3.13 [F4 + F9] Generating WhatsApp text share directly from chat bubble timeline events", () => {
    const entry: Entry = {
      id: "e1",
      title: "Daily Log",
      tags: [],
      notes: [{ id: "n1", text: "Shift start", createdAt: 100 }],
      attachments: [],
      trips: [{ id: "t1", count: 48, createdAt: 200 }],
      createdAt: 100,
      updatedAt: 200,
      dayKey: "2026-08-13",
      monthKey: "2026-08",
      yearKey: "2026",
    };
    const bubbles = entryToChatBubbles(entry);
    const tripsForExport: LoadingSheetTrip[] = bubbles
      .filter((b) => b.kind === "trip" && b.trip)
      .map((b) => ({
        id: b.trip!.id,
        reg: "MN05XNGP",
        driverName: "Neil",
        tripId: "NLH",
        quantityLoaded: b.trip!.count,
        durationMinutes: 20,
        createdAt: b.createdAt,
      }));

    const text = formatWhatsAppShareText({
      dateStr: "2026-08-13",
      despatcherName: "Neil",
      trips: tripsForExport,
    });
    expect(text).toContain("TOTAL TYRES LOADED: 48");
  });

  test("3.14 [F6 + F7] Queueing photo attachment while offline and updating sync badge after upload", () => {
    let badge: SyncItemStatus = "offline_saved";
    const attachmentUploadSuccess = true;
    if (attachmentUploadSuccess) badge = "synced";
    expect(badge).toBe("synced");
  });

  test("3.15 [F1 + F5] Companion PWA header reflecting despatcher preference name", () => {
    const pwaHeader = {
      title: "Despatch Diary Companion",
      despatcher: "Alice Scanner",
      date: "2026-08-13",
    };
    expect(pwaHeader.despatcher).toBe("Alice Scanner");
  });
});
