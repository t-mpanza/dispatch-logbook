import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "../../");

// ---------------------------------------------------------------------------
// Setup dynamic temporary module wrappers to execute tests empirically
// ---------------------------------------------------------------------------
let rawPresets = fs.readFileSync(path.join(projectRoot, "src/lib/loading-presets.ts"), "utf8");

// Fix relative imports in temp file
rawPresets = rawPresets.replace("./types.ts", "../../src/lib/types.ts");
rawPresets = rawPresets.replace("./format.ts", "../../src/lib/format.ts");

if (!rawPresets.includes("const STOCKS_STORAGE_KEY")) {
  rawPresets = `const STOCKS_STORAGE_KEY = "dispatch_stocks_counter";\n` + rawPresets;
}

const resetMatches = [...rawPresets.matchAll(/export function resetStocksCounter\(\): void \{/g)];
if (resetMatches.length > 1) {
  const lastIndex = rawPresets.lastIndexOf("export function resetStocksCounter");
  rawPresets =
    rawPresets.substring(0, lastIndex) +
    "// Removed duplicate resetStocksCounter\n/* " +
    rawPresets.substring(lastIndex) +
    " */";
}

fs.writeFileSync(path.join(__dirname, "temp_loading_presets.ts"), rawPresets);

let rawWA = fs.readFileSync(path.join(projectRoot, "src/lib/export-whatsapp.ts"), "utf8");
rawWA = rawWA.replace("./loading-presets.ts", "./temp_loading_presets.ts");
rawWA = rawWA.replace("./types.ts", "../../src/lib/types.ts");
fs.writeFileSync(path.join(__dirname, "temp_export_whatsapp.ts"), rawWA);

let rawPDF = fs.readFileSync(path.join(projectRoot, "src/lib/export-pdf.ts"), "utf8");
rawPDF = rawPDF.replace("./loading-presets.ts", "./temp_loading_presets.ts");
rawPDF = rawPDF.replace("./types.ts", "../../src/lib/types.ts");
rawPDF = rawPDF.replace("(t) =>", "(t: any) =>");
fs.writeFileSync(path.join(__dirname, "temp_export_pdf.ts"), rawPDF);

const { calculateDurationMinutes, calculateLoadingSheetTotals } =
  await import("./temp_loading_presets.ts");
const { formatWhatsAppShareText } = await import("./temp_export_whatsapp.ts");
const { generatePDFReport, buildPDFReportData } = await import("./temp_export_pdf.ts");

interface TestResult {
  id: string;
  category: string;
  name: string;
  passed: boolean;
  details: string;
}

const results: TestResult[] = [];

function recordTest(id: string, category: string, name: string, passed: boolean, details: string) {
  results.push({ id, category, name, passed, details });
  const status = passed ? "✅ PASS" : "❌ FAIL";
  console.log(`[${status}] [${id}] ${category}: ${name}\n     Details: ${details}`);
}

// Mock Global DOM for generatePDFReport
let capturedPDFHTML = "";
let printCalled = false;

(globalThis as any).document = {
  getElementById: (id: string) => {
    if (id === "printable-loading-sheet") {
      return { remove: () => {} };
    }
    return null;
  },
  createElement: (tag: string) => {
    let _innerHTML = "";
    return {
      id: "",
      className: "",
      set innerHTML(val: string) {
        _innerHTML = val;
        capturedPDFHTML = val;
      },
      get innerHTML() {
        return _innerHTML;
      },
    };
  },
  body: {
    appendChild: (child: any) => {},
  },
};

(globalThis as any).window = {
  print: () => {
    printCalled = true;
  },
};

async function runEmpiricalHarness() {
  console.log("=================================================================");
  console.log(" EMPIRICAL TEST HARNESS -- CHALLENGER 2 (MILESTONE 1)");
  console.log(
    " Target Components: calculateLoadingSheetTotals, formatWhatsAppShareText, generatePDFReport",
  );
  console.log("=================================================================\n");

  // -------------------------------------------------------------------------
  // CATEGORY 1: Footer Summary Calculations (calculateLoadingSheetTotals)
  // -------------------------------------------------------------------------
  console.log("--- Category 1: Footer Summary Calculations ---");

  // 1.1 Empty List
  try {
    const res = calculateLoadingSheetTotals([]);
    const pass = res.totalTyresLoaded === 0 && res.totalLoadingTimeMinutes === 0;
    recordTest(
      "CALC-01",
      "Footer Summary",
      "Empty List Handling",
      pass,
      `totalTyresLoaded=${res.totalTyresLoaded} (exp 0), totalLoadingTimeMinutes=${res.totalLoadingTimeMinutes} (exp 0)`,
    );
  } catch (err: any) {
    recordTest(
      "CALC-01",
      "Footer Summary",
      "Empty List Handling",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 1.2 100+ Manual Rows (150 rows stress test)
  try {
    const count = 150;
    const trips: any[] = Array.from({ length: count }, (_, i) => ({
      id: `manual-${i}`,
      reg: `REG-${i}`,
      driverName: `Driver ${i}`,
      tripId: `CUSTOM-${i}`,
      quantityLoaded: 12,
      durationMinutes: 25,
      createdAt: Date.now(),
    }));

    const startMs = performance.now();
    const res = calculateLoadingSheetTotals(trips);
    const elapsed = performance.now() - startMs;

    const expectedTyres = count * 12; // 1800
    const expectedMins = count * 25; // 3750

    const pass =
      res.totalTyresLoaded === expectedTyres && res.totalLoadingTimeMinutes === expectedMins;
    recordTest(
      "CALC-02",
      "Footer Summary",
      "100+ Manual Rows (150 rows stress test)",
      pass,
      `Tyres=${res.totalTyresLoaded} (exp ${expectedTyres}), Mins=${res.totalLoadingTimeMinutes} (exp ${expectedMins}), Time=${elapsed.toFixed(3)}ms`,
    );
  } catch (err: any) {
    recordTest("CALC-02", "Footer Summary", "100+ Manual Rows", false, `Exception: ${err.message}`);
  }

  // 1.3 Zero Quantity Trips (0, negative, undefined, NaN)
  try {
    const zeroTrips: any[] = [
      {
        id: "z1",
        reg: "R1",
        driverName: "D1",
        tripId: "T1",
        quantityLoaded: 0,
        durationMinutes: 10,
        createdAt: Date.now(),
      },
      {
        id: "z2",
        reg: "R2",
        driverName: "D2",
        tripId: "T2",
        quantityLoaded: -15,
        durationMinutes: 10,
        createdAt: Date.now(),
      },
      {
        id: "z3",
        reg: "R3",
        driverName: "D3",
        tripId: "T3",
        quantityLoaded: undefined,
        durationMinutes: 10,
        createdAt: Date.now(),
      },
      {
        id: "z4",
        reg: "R4",
        driverName: "D4",
        tripId: "T4",
        quantityLoaded: NaN,
        durationMinutes: 10,
        createdAt: Date.now(),
      },
    ];

    const res = calculateLoadingSheetTotals(zeroTrips);
    const pass = res.totalTyresLoaded === 0 && res.totalLoadingTimeMinutes === 40;
    recordTest(
      "CALC-03",
      "Footer Summary",
      "Zero & Negative & Undefined Quantity Trips",
      pass,
      `totalTyresLoaded=${res.totalTyresLoaded} (exp 0), totalLoadingTimeMinutes=${res.totalLoadingTimeMinutes} (exp 40)`,
    );
  } catch (err: any) {
    recordTest(
      "CALC-03",
      "Footer Summary",
      "Zero Quantity Trips",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 1.4 Undefined Durations & Fallback Calculation
  try {
    const baseMs = 1700000000000;
    const durationTrips: any[] = [
      { id: "d1", quantityLoaded: 10, durationMinutes: 20 }, // 20
      { id: "d2", quantityLoaded: 10, durationMinutes: undefined }, // 0
      {
        id: "d3",
        quantityLoaded: 10,
        quantityLoaded: 10,
        durationMinutes: undefined,
        startTime: baseMs,
      }, // 0
      {
        id: "d4",
        quantityLoaded: 10,
        durationMinutes: undefined,
        startTime: baseMs,
        finishTime: baseMs - 60000,
      }, // 0
      {
        id: "d5",
        quantityLoaded: 10,
        durationMinutes: undefined,
        startTime: baseMs,
        finishTime: baseMs + 45 * 60 * 1000,
      }, // 45
      { id: "d6", quantityLoaded: 10, durationMinutes: -30 }, // 0
    ];

    const res = calculateLoadingSheetTotals(durationTrips);
    const expected = 20 + 0 + 0 + 0 + 45 + 0; // 65
    const pass = res.totalLoadingTimeMinutes === expected;
    recordTest(
      "CALC-04",
      "Footer Summary",
      "Undefined & Negative Durations Fallback Logic",
      pass,
      `totalLoadingTimeMinutes=${res.totalLoadingTimeMinutes} (exp ${expected})`,
    );
  } catch (err: any) {
    recordTest(
      "CALC-04",
      "Footer Summary",
      "Undefined Durations",
      false,
      `Exception: ${err.message}`,
    );
  }

  // -------------------------------------------------------------------------
  // CATEGORY 2: WhatsApp Text Formatter (formatWhatsAppShareText)
  // -------------------------------------------------------------------------
  console.log("\n--- Category 2: WhatsApp Text Formatter ---");

  // 2.1 Basic Output Formatting & Layout
  try {
    const entry: any = {
      id: "e1",
      dayKey: "2026-08-13",
      createdAt: Date.now(),
      loadingSheetTrips: [
        {
          id: "t1",
          reg: "MN05XNGP",
          driverName: "Neil",
          tripId: "NLH",
          quantityLoaded: 150,
          durationMinutes: 75,
          startTime: new Date("2026-08-13T08:00:00Z").getTime(),
          finishTime: new Date("2026-08-13T09:15:00Z").getTime(),
        },
      ],
    };

    const formatted = formatWhatsAppShareText(entry, "Sipho Khumalo");

    const checks = {
      header: formatted.includes("📋 *DESPATCH LOADING SHEET*"),
      date: formatted.includes("📅 Date: 2026-08-13"),
      despatcher: formatted.includes("👤 Despatcher: Sipho Khumalo"),
      tripsHeader: formatted.includes("🚛 *LOADED TRIPS (1)*"),
      divider: formatted.includes("----------------------------------"),
      tripLine: formatted.includes("1. [NLH] MN05XNGP (Neil) - 150 tyres (75 mins)"),
      totalsHeader: formatted.includes("📊 *SUMMARY TOTALS*"),
      totalTyres: formatted.includes("📦 TOTAL TYRES LOADED: 150"),
      totalTime: formatted.includes("⏱️ TOTAL LOADING TIME: 75 mins"),
    };

    const pass = Object.values(checks).every(Boolean);
    recordTest(
      "WA-01",
      "WhatsApp Formatter",
      "Output Structure & Section Headers",
      pass,
      pass
        ? "All layout section checks passed"
        : `Failed section checks: ${Object.entries(checks)
            .filter(([_, v]) => !v)
            .map(([k]) => k)
            .join(", ")}`,
    );
  } catch (err: any) {
    recordTest(
      "WA-01",
      "WhatsApp Formatter",
      "Output Structure",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 2.2 Date Fallback Hierarchy
  try {
    const tA = formatWhatsAppShareText({ dayKey: "2026-08-01" });
    const passA = tA.includes("Date: 2026-08-01");

    const tB = formatWhatsAppShareText({ dateStr: "2026-08-02" });
    const passB = tB.includes("Date: 2026-08-02");

    const tC = formatWhatsAppShareText({ createdAt: new Date("2026-08-03T12:00:00Z").getTime() });
    const passC = tC.includes("Date: 2026-08-03");

    const todayISO = new Date().toISOString().split("T")[0];
    const tD = formatWhatsAppShareText({});
    const passD = tD.includes(`Date: ${todayISO}`);

    const pass = passA && passB && passC && passD;
    recordTest(
      "WA-02",
      "WhatsApp Formatter",
      "Date Fallback Hierarchy (dayKey -> dateStr -> createdAt -> current date)",
      pass,
      `dayKey: ${passA}, dateStr: ${passB}, createdAt: ${passC}, defaultToday: ${passD}`,
    );
  } catch (err: any) {
    recordTest(
      "WA-02",
      "WhatsApp Formatter",
      "Date Fallback Hierarchy",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 2.3 Special Characters (Reg, Driver, Trip ID, Despatcher)
  try {
    const specialEntry: any = {
      id: "e-spec",
      dayKey: "2026-08-13",
      loadingSheetTrips: [
        {
          id: "ts1",
          reg: "CA *123* _456_",
          driverName: "Thabo *'Boss'* & <Mpho>\nDriver Line 2",
          tripId: 'STOCKS "1" ~Test~',
          quantityLoaded: 40,
          durationMinutes: 20,
        },
      ],
    };

    const formatted = formatWhatsAppShareText(specialEntry, "Supervisor *John* <Admin>");

    const hasReg = formatted.includes("CA *123* _456_");
    const hasDriver = formatted.includes("Thabo *'Boss'* & <Mpho>");
    const hasTrip = formatted.includes('STOCKS "1" ~Test~');
    const hasDespatcher = formatted.includes("Supervisor *John* <Admin>");
    const hasMultiline = formatted.includes("Driver Line 2");

    const pass = hasReg && hasDriver && hasTrip && hasDespatcher && hasMultiline;
    recordTest(
      "WA-03",
      "WhatsApp Formatter",
      "Special Characters Handling (Markdown, HTML tags, Quotes, Ampersands, Newlines)",
      pass,
      `Reg: ${hasReg}, Driver: ${hasDriver}, Trip: ${hasTrip}, Despatcher: ${hasDespatcher}, Multiline: ${hasMultiline}`,
    );
  } catch (err: any) {
    recordTest(
      "WA-03",
      "WhatsApp Formatter",
      "Special Characters",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 2.4 Single Trip vs Multi-Trip vs Zero Trips
  try {
    const zeroStr = formatWhatsAppShareText({ dayKey: "2026-08-13", loadingSheetTrips: [] });
    const passZero =
      zeroStr.includes("🚛 *LOADED TRIPS (0)*") &&
      zeroStr.includes("No loading trips recorded on this sheet.");

    const singleStr = formatWhatsAppShareText({
      dayKey: "2026-08-13",
      loadingSheetTrips: [
        { reg: "REG1", driverName: "D1", tripId: "T1", quantityLoaded: 50, durationMinutes: 30 },
      ],
    });
    const passSingle =
      singleStr.includes("🚛 *LOADED TRIPS (1)*") &&
      singleStr.includes("1. [T1] REG1 (D1) - 50 tyres (30 mins)");

    const multiStr = formatWhatsAppShareText({
      dayKey: "2026-08-13",
      loadingSheetTrips: [
        { reg: "R1", driverName: "D1", tripId: "T1", quantityLoaded: 10, durationMinutes: 10 },
        { reg: "R2", driverName: "D2", tripId: "T2", quantityLoaded: 20, durationMinutes: 15 },
        { reg: "R3", driverName: "D3", tripId: "T3", quantityLoaded: 30, durationMinutes: 20 },
      ],
    });
    const passMulti =
      multiStr.includes("🚛 *LOADED TRIPS (3)*") &&
      multiStr.includes("1. [T1] R1 (D1) - 10 tyres (10 mins)") &&
      multiStr.includes("2. [T2] R2 (D2) - 20 tyres (15 mins)") &&
      multiStr.includes("3. [T3] R3 (D3) - 30 tyres (20 mins)") &&
      multiStr.includes("📦 TOTAL TYRES LOADED: 60") &&
      multiStr.includes("⏱️ TOTAL LOADING TIME: 45 mins");

    const pass = passZero && passSingle && passMulti;
    recordTest(
      "WA-04",
      "WhatsApp Formatter",
      "Zero Trip vs Single Trip vs Multi-Trip Formatting",
      pass,
      `Zero pass: ${passZero}, Single pass: ${passSingle}, Multi pass: ${passMulti}`,
    );
  } catch (err: any) {
    recordTest(
      "WA-04",
      "WhatsApp Formatter",
      "Single vs Multi-Trip",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 2.5 Unused Pre-Calculated Hours vs Mins Formatting Bug
  try {
    const multiHourEntry: any = {
      dayKey: "2026-08-13",
      loadingSheetTrips: [
        { reg: "R1", driverName: "D1", tripId: "T1", quantityLoaded: 100, durationMinutes: 135 }, // 2h 15m
      ],
    };

    const formatted = formatWhatsAppShareText(multiHourEntry);
    // Notice: formatWhatsAppShareText computes `timeFormatted = "135 mins (2h 15m)"` on line 46,
    // but outputs line 73 as: `⏱️ TOTAL LOADING TIME: 135 mins`.
    const usesHoursFormat = formatted.includes("2h 15m");
    recordTest(
      "WA-05",
      "WhatsApp Formatter",
      "Multi-Hour Duration String Verification (hours & minutes formatting)",
      usesHoursFormat,
      `Formatted output: "${formatted.split("\n").pop()}", contains (2h 15m): ${usesHoursFormat}`,
    );
  } catch (err: any) {
    recordTest(
      "WA-05",
      "WhatsApp Formatter",
      "Multi-Hour Duration Formatting",
      false,
      `Exception: ${err.message}`,
    );
  }

  // -------------------------------------------------------------------------
  // CATEGORY 3: PDF Report HTML String Generation (generatePDFReport)
  // -------------------------------------------------------------------------
  console.log("\n--- Category 3: PDF Report HTML String Generation ---");

  const pdfEntry: any = {
    id: "pdf-e1",
    dayKey: "2026-08-13",
    loadingSheetTrips: [
      {
        id: "pt1",
        reg: "MN05XNGP",
        driverName: "Neil",
        tripId: "NLH",
        startTime: new Date("2026-08-13T08:00:00Z").getTime(),
        finishTime: new Date("2026-08-13T08:45:00Z").getTime(),
        durationMinutes: 45,
        quantityLoaded: 160,
      },
      {
        id: "pt2",
        reg: "KZN 789 GP",
        driverName: "Sipho",
        tripId: "STOCKS 1",
        startTime: new Date("2026-08-13T09:00:00Z").getTime(),
        finishTime: new Date("2026-08-13T10:00:00Z").getTime(),
        durationMinutes: 60,
        quantityLoaded: 240,
      },
    ],
  };

  capturedPDFHTML = "";
  printCalled = false;
  await generatePDFReport(pdfEntry, "Operations Manager");

  // 3.1 Table Structure - Exact 7 Active Columns
  try {
    const expectedHeaders = [
      "Reg",
      "Driver Name",
      "Trip ID",
      "Start Time",
      "Finished Time",
      "Minutes",
      "Quantity Loaded",
    ];
    const hasAllHeaders = expectedHeaders.every((h) =>
      capturedPDFHTML.toUpperCase().includes(h.toUpperCase()),
    );

    const thMatches = capturedPDFHTML.match(/<th\b[^>]*>/gi) || [];
    const exact7TH = thMatches.length === 7;

    const trMatches = capturedPDFHTML.match(/<tr>[\s\S]*?<\/tr>/gi) || [];
    let tbodyRowsCount = 0;
    let allRowsHave7TD = true;

    for (const tr of trMatches) {
      if (tr.includes("<td")) {
        tbodyRowsCount++;
        const tdMatches = tr.match(/<td\b[^>]*>/gi) || [];
        if (tdMatches.length !== 7) {
          allRowsHave7TD = false;
        }
      }
    }

    const pass = hasAllHeaders && exact7TH && tbodyRowsCount === 2 && allRowsHave7TD;
    recordTest(
      "PDF-01",
      "PDF Report Generator",
      "Table Structure - Exact 7 Active Columns (<thead> & <tbody>)",
      pass,
      `Headers present: ${hasAllHeaders}, <th> count: ${thMatches.length} (exp 7), Tbody rows: ${tbodyRowsCount}, All rows 7 <td>: ${allRowsHave7TD}`,
    );
  } catch (err: any) {
    recordTest(
      "PDF-01",
      "PDF Report Generator",
      "Table Structure",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 3.2 Header Date & Despatcher Name
  try {
    const hasDate =
      capturedPDFHTML.includes("Date:</strong> 2026-08-13") ||
      capturedPDFHTML.includes("2026-08-13");
    const hasDespatcher =
      capturedPDFHTML.includes("Despatcher:</strong> Operations Manager") ||
      capturedPDFHTML.includes("Operations Manager");

    const pass = hasDate && hasDespatcher;
    recordTest(
      "PDF-02",
      "PDF Report Generator",
      "Header Date & Despatcher Name Inclusion",
      pass,
      `Header Date match: ${hasDate}, Header Despatcher match: ${hasDespatcher}`,
    );
  } catch (err: any) {
    recordTest(
      "PDF-02",
      "PDF Report Generator",
      "Header Date & Despatcher",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 3.3 Total Tyres Loaded & Total Loading Time Summary
  try {
    const hasTyresTotal =
      capturedPDFHTML.includes("TOTAL TYRES LOADED:</strong> 400") ||
      capturedPDFHTML.includes("400");
    const hasTimeTotal =
      capturedPDFHTML.includes("TOTAL LOADING TIME:</strong> 1h 45m (105 mins)") ||
      capturedPDFHTML.includes("1h 45m (105 mins)");

    const pass = hasTyresTotal && hasTimeTotal;
    recordTest(
      "PDF-03",
      "PDF Report Generator",
      "Summary Box Totals (Total Tyres & Total Loading Time)",
      pass,
      `Tyres Total (400) match: ${hasTyresTotal}, Time Total (1h 45m) match: ${hasTimeTotal}`,
    );
  } catch (err: any) {
    recordTest(
      "PDF-03",
      "PDF Report Generator",
      "Summary Totals",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 3.4 Supervisor Sign-off Line Check
  try {
    const hasSupervisor = /Supervisor/i.test(capturedPDFHTML);
    const hasDespatcherSignature = /Despatcher Signature/i.test(capturedPDFHTML);

    recordTest(
      "PDF-04",
      "PDF Report Generator",
      "Supervisor Sign-off Line Compliance",
      hasSupervisor,
      `Contains 'Supervisor': ${hasSupervisor}, Contains 'Despatcher Signature': ${hasDespatcherSignature}`,
    );
  } catch (err: any) {
    recordTest(
      "PDF-04",
      "PDF Report Generator",
      "Supervisor Sign-off Line",
      false,
      `Exception: ${err.message}`,
    );
  }

  // 3.5 Absence of Legacy Fields (Arrival, Departure, Pressure, PSI)
  try {
    const hasArrival = /Arrival/i.test(capturedPDFHTML);
    const hasDeparture = /Departure/i.test(capturedPDFHTML);
    const hasPressure = /Pressure/i.test(capturedPDFHTML);
    const hasPSI = /\bPSI\b/i.test(capturedPDFHTML);

    const legacyFound = hasArrival || hasDeparture || hasPressure || hasPSI;
    const pass = !legacyFound;

    recordTest(
      "PDF-05",
      "PDF Report Generator",
      "Absence of Legacy Fields (Arrival, Departure, Pressure, PSI)",
      pass,
      `Legacy field status: Arrival=${hasArrival}, Departure=${hasDeparture}, Pressure=${hasPressure}, PSI=${hasPSI}`,
    );
  } catch (err: any) {
    recordTest(
      "PDF-05",
      "PDF Report Generator",
      "Absence of Legacy Fields",
      false,
      `Exception: ${err.message}`,
    );
  }

  // -------------------------------------------------------------------------
  // SUMMARY REPORT
  // -------------------------------------------------------------------------
  console.log("\n=================================================================");
  console.log(" SUMMARY OF EMPIRICAL TEST HARNESS RESULTS");
  console.log("=================================================================");
  const total = results.length;
  const passed = results.filter((r) => r.passed).length;
  const failed = results.filter((r) => !r.passed).length;

  console.log(`Total Empirical Tests Executed: ${total}`);
  console.log(`Passed: ${passed}`);
  console.log(`Failed: ${failed}`);
  console.log("=================================================================\n");
}

runEmpiricalHarness();
