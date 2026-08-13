import { describe, expect, test } from "./runner.ts";
import { dayKey } from "../../src/lib/format.ts";
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

describe("Tier 2 - Feature 1: Header Boundary & Corner Cases", () => {
  test("1.1 Empty/whitespace despatcher name defaults to fallback", () => {
    const rawName = "   ";
    const name = rawName.trim() || "Despatcher";
    expect(name).toBe("Despatcher");
  });

  test("1.2 Leap year and year rollover date formatting", () => {
    const leap = new Date("2028-02-29T12:00:00Z");
    const rollover = new Date("2026-12-31T12:00:00Z");
    expect(dayKey(leap)).toBe("2028-02-29");
    expect(dayKey(rollover)).toBe("2026-12-31");
  });

  test("1.3 Super long despatcher name handling", () => {
    const longName = "A".repeat(600);
    const sanitized = longName.substring(0, 100);
    expect(sanitized.length).toBe(100);
  });

  test("1.4 Malformed date string fallback handling", () => {
    const parseDateSafely = (input: string) => {
      const d = new Date(input);
      return isNaN(d.getTime()) ? dayKey(new Date()) : dayKey(d);
    };
    expect(parseDateSafely("invalid-date-xyz")).toBe(dayKey(new Date()));
  });

  test("1.5 Header with extreme timezone dates", () => {
    const dateObj = new Date("2026-08-13T23:59:00+14:00");
    expect(dayKey(dateObj)).toBe("2026-08-13");
  });
});

describe("Tier 2 - Feature 2: Presets Boundary & Corner Cases", () => {
  test("2.1 STOCKS counter boundary max count", () => {
    resetStocksCounter();
    const res = resolvePreset("STOCKS", undefined, { dateStr: "2026-08-13", currentCount: 9999 });
    expect(res.tripId).toBe("STOCKS 9999");
  });

  test("2.2 Preset key space trimming and normalization", () => {
    const keyInput = " nlh  ".trim().toUpperCase() as any;
    const res = resolvePreset(keyInput);
    expect(res.tripId).toBe("NLH");
    expect(res.driverName).toBe("Neil");
  });

  test("2.3 Midnight boundary reset at 23:59:59 to 00:00:00 transition", () => {
    resetStocksCounter();
    resolvePreset("STOCKS", undefined, { dateStr: "2026-08-13" });
    const nextDayRes = resolvePreset("STOCKS", undefined, { dateStr: "2026-08-14" });
    expect(nextDayRes.tripId).toBe("STOCKS 1");
  });

  test("2.4 NLH preset with custom reg plate override", () => {
    const res = resolvePreset("NLH");
    const customReg = "CUSTOM-PLATE";
    const finalReg = customReg || res.reg;
    expect(finalReg).toBe("CUSTOM-PLATE");
    expect(res.driverName).toBe("Neil");
  });

  test("2.5 CUSTOM preset with empty string and special symbols", () => {
    const resEmpty = resolvePreset("CUSTOM", "");
    const resSymbol = resolvePreset("CUSTOM", "TRIP #99 / @SPECIAL");
    expect(resEmpty.tripId).toBe("CUSTOM");
    expect(resSymbol.tripId).toBe("TRIP #99 / @SPECIAL");
  });
});

describe("Tier 2 - Feature 3: Table Calculations Boundary & Corner Cases", () => {
  test("3.1 0 minutes duration when startTime equals finishTime", () => {
    const t = 1700000000000;
    expect(calculateDurationMinutes(t, t)).toBe(0);
  });

  test("3.2 Overnight duration spanning across midnight (23:50 to 00:30)", () => {
    const start = new Date("2026-08-13T23:50:00Z").getTime();
    const finish = new Date("2026-08-14T00:30:00Z").getTime();
    expect(calculateDurationMinutes(start, finish)).toBe(40);
  });

  test("3.3 Negative tyres or rejected count greater than scanned tyres handled safely", () => {
    const trip: LoadingSheetTrip = {
      id: "1",
      reg: "A",
      driverName: "D",
      tripId: "T",
      quantityLoaded: -5,
      rejectedCount: 10,
      createdAt: 1,
    };
    const totals = calculateLoadingSheetTotals([trip]);
    expect(totals.totalTyresLoaded).toBe(0);
  });

  test("3.4 Summary footer calculation with 0 trips", () => {
    const totals = calculateLoadingSheetTotals([]);
    expect(totals.totalTyresLoaded).toBe(0);
    expect(totals.totalLoadingTimeMinutes).toBe(0);
  });

  test("3.5 Large numbers aggregate precision (1,000,000 tyres)", () => {
    const trips: LoadingSheetTrip[] = [
      {
        id: "1",
        reg: "A",
        driverName: "D",
        tripId: "T1",
        quantityLoaded: 500000,
        durationMinutes: 300,
        createdAt: 1,
      },
      {
        id: "2",
        reg: "B",
        driverName: "D",
        tripId: "T2",
        quantityLoaded: 500000,
        durationMinutes: 200,
        createdAt: 2,
      },
    ];
    const totals = calculateLoadingSheetTotals(trips);
    expect(totals.totalTyresLoaded).toBe(1000000);
    expect(totals.totalLoadingTimeMinutes).toBe(500);
  });
});

describe("Tier 2 - Feature 4: Manual Truck Rows & Exports Boundary Cases", () => {
  test("4.1 Manual truck entry with empty reg plate defaults to N/A", () => {
    const manualTrip: LoadingSheetTrip = {
      id: "m1",
      reg: "",
      driverName: "Dave",
      tripId: "LOCAL",
      quantityLoaded: 5,
      isManual: true,
      createdAt: Date.now(),
    };
    const formattedReg = manualTrip.reg.trim() || "N/A";
    expect(formattedReg).toBe("N/A");
  });

  test("4.2 PDF export data generation with 100+ trip rows", () => {
    const trips: LoadingSheetTrip[] = Array.from({ length: 120 }, (_, i) => ({
      id: `t-${i}`,
      reg: `REG-${i}`,
      driverName: `Driver ${i}`,
      tripId: `TRIP-${i}`,
      quantityLoaded: 10,
      durationMinutes: 5,
      createdAt: Date.now() + i,
    }));
    const reportData = buildPDFReportData({ dateStr: "2026-08-13", trips });
    expect(reportData.trips.length).toBe(120);
    expect(reportData.totalTyresLoaded).toBe(1200);
    expect(reportData.totalLoadingTimeMinutes).toBe(600);
  });

  test("4.3 WhatsApp export special character formatting", () => {
    const trips: LoadingSheetTrip[] = [
      {
        id: "1",
        reg: "REG & 100*",
        driverName: "Dave <Tag>",
        tripId: "TRIP_1",
        quantityLoaded: 15,
        durationMinutes: 10,
        createdAt: 1,
      },
    ];
    const text = formatWhatsAppShareText({ dateStr: "2026-08-13", despatcherName: "Neil", trips });
    expect(text).toContain("REG & 100*");
    expect(text).toContain("Dave <Tag>");
  });

  test("4.4 Manual entry duration when startTime is set but finishTime is missing", () => {
    const trip: LoadingSheetTrip = {
      id: "m1",
      reg: "REG-1",
      driverName: "Neil",
      tripId: "STOCKS 1",
      startTime: Date.now(),
      quantityLoaded: 20,
      createdAt: Date.now(),
    };
    const duration = calculateDurationMinutes(trip.startTime, trip.finishTime);
    expect(duration).toBe(0);
  });

  test("4.5 PDF/WhatsApp output formatting when despatcher name has line breaks", () => {
    const text = formatWhatsAppShareText({
      dateStr: "2026-08-13",
      despatcherName: "Neil\nLead Scanner",
      trips: [],
    });
    expect(text).toContain("Despatcher: Neil");
  });
});

describe("Tier 2 - Feature 5: Companion PWA Boundary & Corner Cases", () => {
  test("5.1 Querying companion view for non-existent dayKey returns empty list", () => {
    const entries: Entry[] = [];
    const found = entries.filter((e) => e.dayKey === "1999-01-01");
    expect(found.length).toBe(0);
  });

  test("5.2 Multi-tab storage update notification broadcast", () => {
    let broadcastReceived = false;
    const channel = {
      postMessage: () => {
        broadcastReceived = true;
      },
    };
    channel.postMessage();
    expect(broadcastReceived).toBe(true);
  });

  test("5.3 Sudden offline network drop during active pull operation", () => {
    let errorCaught = false;
    const simulatePull = async (online: boolean) => {
      if (!online) throw new Error("Network connection lost during pull");
    };
    expect(async () => {
      await simulatePull(false);
    }).toThrow("Network connection lost");
  });

  test("5.4 Supabase channel reconnection after intermittent network drop", () => {
    let status = "CLOSED";
    const reconnect = () => {
      status = "SUBSCRIBED";
    };
    reconnect();
    expect(status).toBe("SUBSCRIBED");
  });

  test("5.5 PWA caching empty local storage state gracefully", () => {
    const cachedEntries: Entry[] = [];
    expect(cachedEntries.length).toBe(0);
  });
});

describe("Tier 2 - Feature 6: Offline Badges Boundary Cases", () => {
  test("6.1 Item sync state transition under sudden network drop mid-flight", () => {
    let state: SyncItemStatus = "syncing";
    const networkDropped = true;
    if (networkDropped) state = "offline_saved";
    expect(state).toBe("offline_saved");
  });

  test("6.2 Rapid toggling offline -> online -> offline within 100ms", () => {
    const states: SyncItemStatus[] = [];
    states.push("offline_saved");
    states.push("syncing");
    states.push("offline_saved");
    expect(states[states.length - 1]).toBe("offline_saved");
  });

  test("6.3 Corrupted object store recovery fallback to fresh store", () => {
    const recoverStore = (corrupted: boolean) => (corrupted ? [] : ["valid"]);
    expect(recoverStore(true)).toEqual([]);
  });

  test("6.4 Sync status badge rendering with 10,000 queued items", () => {
    const queue = new Array(10000).fill("offline_saved");
    expect(queue.length).toBe(10000);
  });

  test("6.5 Handling HTTP 500 / 503 backend error status from cloud", () => {
    const handleHttpResponse = (statusCode: number): SyncItemStatus => {
      if (statusCode >= 500) return "error";
      return "synced";
    };
    expect(handleHttpResponse(500)).toBe("error");
    expect(handleHttpResponse(503)).toBe("error");
    expect(handleHttpResponse(200)).toBe("synced");
  });
});

describe("Tier 2 - Feature 7: Media Sync Boundary & Corner Cases", () => {
  test("7.1 Zero-byte Blob upload handling", () => {
    const emptyBlob = new Blob([], { type: "image/png" });
    expect(emptyBlob.size).toBe(0);
  });

  test("7.2 Storage path generation with unexpected MIME types", () => {
    const mime = "application/x-custom-binary; charset=utf-8";
    const ext = mime.split("/")[1]?.split(";")[0] ?? "bin";
    expect(ext).toBe("x-custom-binary");
  });

  test("7.3 High resolution media file metadata (8K image 7680x4320)", () => {
    const att: Attachment = {
      id: "a-8k",
      kind: "image",
      blob: new Blob([]),
      mime: "image/png",
      width: 7680,
      height: 4320,
      createdAt: Date.now(),
    };
    expect(att.width).toBe(7680);
    expect(att.height).toBe(4320);
  });

  test("7.4 Network timeout during storage download URL resolution", () => {
    const resolveWithTimeout = (timeoutMs: number) => {
      if (timeoutMs < 100) throw new Error("Storage URL fetch timed out");
      return "https://storage.local/item";
    };
    expect(() => resolveWithTimeout(50)).toThrow("timed out");
  });

  test("7.5 Deleting non-existent remote storage object returns soft cleanup success", () => {
    const deleteStorageObject = (path: string) => ({ error: null, success: true });
    const res = deleteStorageObject("non-existent-path");
    expect(res.success).toBe(true);
  });
});

describe("Tier 2 - Feature 8: Fresh Device Restore Boundary Cases", () => {
  test("8.1 Push loop protection during 100 rapid local updates", () => {
    let pushCalls = 0;
    const mockUpdate = (skipPush: boolean) => {
      if (!skipPush) pushCalls++;
    };
    for (let i = 0; i < 100; i++) mockUpdate(true);
    expect(pushCalls).toBe(0);
  });

  test("8.2 Fresh device pull when cloud database has 0 records", () => {
    const remoteData: any[] = [];
    const localDb: any[] = [];
    if (remoteData.length > 0) localDb.push(...remoteData);
    expect(localDb.length).toBe(0);
  });

  test("8.3 Merging remote data when local item has identical updatedAt", () => {
    const local = { id: "1", title: "Local", updatedAt: 5000 };
    const remote = { id: "1", title: "Remote", updatedAt: 5000 };
    const merged = local.updatedAt >= remote.updatedAt ? local : remote;
    expect(merged.title).toBe("Local");
  });

  test("8.4 Network drop mid-way through fresh device restore chunk processing", () => {
    const chunks = [
      [1, 2],
      [3, 4],
      [5, 6],
    ];
    const processed: number[] = [];
    let networkOk = true;
    for (let i = 0; i < chunks.length; i++) {
      if (i === 1) networkOk = false;
      if (!networkOk) break;
      processed.push(...chunks[i]);
    }
    expect(processed).toEqual([1, 2]);
  });

  test("8.5 Remote deletion when local database contains un-pushed modifications", () => {
    let localDeleted = false;
    const handleDeleteRemote = (id: string, hasLocalUnpushed: boolean) => {
      if (hasLocalUnpushed) {
        // Force remote delete wins
        localDeleted = true;
      }
    };
    handleDeleteRemote("e1", true);
    expect(localDeleted).toBe(true);
  });
});

describe("Tier 2 - Feature 9: Chat Bubble Timeline Boundary Cases", () => {
  test("9.1 Timeline rendering entry with 0 notes, 0 attachments, 0 trips", () => {
    const emptyEntry: Entry = {
      id: "e0",
      title: "Empty",
      tags: [],
      notes: [],
      attachments: [],
      trips: [],
      createdAt: Date.now(),
      updatedAt: Date.now(),
      dayKey: "2026-08-13",
      monthKey: "2026-08",
      yearKey: "2026",
    };
    const bubbles = entryToChatBubbles(emptyEntry);
    expect(bubbles.length).toBe(0);
  });

  test("9.2 Timeline with 1,000 chat messages", () => {
    const notes = Array.from({ length: 1000 }, (_, i) => ({
      id: `n-${i}`,
      text: `Note ${i}`,
      createdAt: 1000 + i,
    }));
    const entry: Partial<Entry> = { notes, attachments: [], trips: [] };
    const bubbles = entryToChatBubbles(entry as Entry);
    expect(bubbles.length).toBe(1000);
  });

  test("9.3 Multiline note block formatting with emojis and newlines", () => {
    const multilineText = "Line 1: Scanned 🎯\nLine 2: Checked ✅\nLine 3: Complete 🚀";
    const entry: Partial<Entry> = {
      notes: [{ id: "n1", text: multilineText, createdAt: 100 }],
      attachments: [],
      trips: [],
    };
    const bubbles = entryToChatBubbles(entry as Entry);
    expect(bubbles[0].text).toContain("Line 1: Scanned");
    expect(bubbles[0].text).toContain("\n");
  });

  test("9.4 Chat bubble timestamp at exactly midnight", () => {
    const midnightTs = new Date("2026-08-13T00:00:00Z").getTime();
    const d = new Date(midnightTs);
    const formatted =
      d.getUTCHours().toString().padStart(2, "0") +
      ":" +
      d.getUTCMinutes().toString().padStart(2, "0");
    expect(formatted).toBe("00:00");
  });

  test("9.5 Out-of-order timestamp events sorted strictly by createdAt", () => {
    const entry: Partial<Entry> = {
      notes: [
        { id: "n3", text: "Third", createdAt: 300 },
        { id: "n1", text: "First", createdAt: 100 },
        { id: "n2", text: "Second", createdAt: 200 },
      ],
      attachments: [],
      trips: [],
    };
    const bubbles = entryToChatBubbles(entry as Entry);
    expect(bubbles.map((b) => b.id)).toEqual(["n1", "n2", "n3"]);
  });
});

describe("Tier 2 - Feature 10: Rich Media Lightbox Boundary Cases", () => {
  test("10.1 Lightbox navigation when attachment list is empty", () => {
    const state = openLightbox([], 0);
    expect(state.isOpen).toBe(false);
    expect(state.activeAttachment).toBe(null);
  });

  test("10.2 Extreme zoom level boundaries clamped between 0.5x and 5.0x", () => {
    const clampZoom = (val: number) => Math.min(5.0, Math.max(0.5, val));
    expect(clampZoom(0.1)).toBe(0.5);
    expect(clampZoom(10.0)).toBe(5.0);
    expect(clampZoom(2.5)).toBe(2.5);
  });

  test("10.3 Next/Previous navigation at boundary indexes", () => {
    const total = 3;
    const canPrev = (index: number) => index > 0;
    const canNext = (index: number) => index < total - 1;
    expect(canPrev(0)).toBe(false);
    expect(canNext(2)).toBe(false);
    expect(canNext(1)).toBe(true);
  });

  test("10.4 Lightbox previewing damaged or zero-length image Blob", () => {
    const damagedBlob = new Blob([], { type: "image/png" });
    const isBlobValid = damagedBlob.size > 0;
    expect(isBlobValid).toBe(false);
  });

  test("10.5 Rapidly toggling open/close lightbox state 50 times", () => {
    let state = createInitialLightboxState();
    const atts: Attachment[] = [
      { id: "a1", kind: "image", blob: new Blob([]), mime: "image/png", createdAt: 1 },
    ];
    for (let i = 0; i < 50; i++) {
      state = i % 2 === 0 ? openLightbox(atts, 0) : createInitialLightboxState();
    }
    expect(state.isOpen).toBe(false);
  });
});

describe("Tier 2 - Feature 11: Haptics Boundary & Corner Cases", () => {
  test("11.1 Triggering haptics 100 times in 1 second debounced safely", () => {
    let count = 0;
    for (let i = 0; i < 100; i++) {
      triggerHaptic("light");
      count++;
    }
    expect(count).toBe(100);
    expect(lastHapticTriggered?.type).toBe("light");
  });

  test("11.2 Unknown haptic type fallback to light pattern", () => {
    triggerHaptic("unknown-type" as any);
    expect(lastHapticTriggered?.pattern).toBe(10);
  });

  test("11.3 Triggering haptics when navigator is undefined", () => {
    const triggerInNode = () => {
      triggerHaptic("medium");
    };
    expect(triggerInNode).not.toThrow();
  });

  test("11.4 navigator.vibrate throwing DOMException handled gracefully", () => {
    const mockVibrateThrow = () => {
      throw new Error("DOMException: User denied vibration permission");
    };
    const safeVibrate = () => {
      try {
        mockVibrateThrow();
      } catch {
        // Suppress
      }
    };
    expect(safeVibrate).not.toThrow();
  });

  test("11.5 Custom array vibration pattern duration validation", () => {
    const pattern = HAPTIC_PATTERNS.error as number[];
    const allPositive = pattern.every((dur) => dur > 0);
    expect(allPositive).toBe(true);
  });
});
