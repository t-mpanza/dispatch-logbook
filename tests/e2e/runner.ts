/**
 * E2E Test Runner & Helper for Dispatch Diary
 * Executes Tier 1, Tier 2, Tier 3, and Tier 4 test suites under Node.js.
 */

// ── Environment Polyfills for Node.js Testing ───────────────────────────────

if (typeof globalThis.navigator === "undefined") {
  (globalThis as any).navigator = {
    vibrate: (pattern: number | number[]) => true,
  };
} else if (!globalThis.navigator.vibrate) {
  (globalThis as any).navigator.vibrate = (pattern: number | number[]) => true;
}

// In-Memory Storage Mock for IndexedDB fallback
const memoryDbStore = new Map<string, Map<string, any>>();

(globalThis as any).indexedDB = (globalThis as any).indexedDB || {
  open: (name: string, version: number) => {
    if (!memoryDbStore.has(name)) {
      memoryDbStore.set(name, new Map());
    }
    const storeMap = memoryDbStore.get(name)!;
    return {
      result: {
        objectStoreNames: {
          contains: (storeName: string) => true,
        },
        createObjectStore: (storeName: string) => {
          if (!storeMap.has(storeName)) storeMap.set(storeName, new Map());
          return { createIndex: () => {} };
        },
        transaction: (storeName: string, mode: string) => {
          const store = storeMap.get(storeName) || new Map();
          return {
            store: {
              put: async (val: any) => store.set(val.id, val),
              get: async (id: string) => store.get(id),
              delete: async (id: string) => store.delete(id),
              getAll: async () => Array.from(store.values()),
            },
            done: Promise.resolve(),
          };
        },
      },
    };
  },
};

// ── Simple Assertions & Framework Engine ───────────────────────────────────

export type TestFn = () => void | Promise<void>;

export interface TestCase {
  name: string;
  fn: TestFn;
}

export interface TestSuiteResults {
  suiteName: string;
  total: number;
  passed: number;
  failed: number;
  errors: Array<{ testName: string; error: any }>;
}

let currentSuiteName = "Default";
const suites = new Map<string, TestCase[]>();
const suiteHooks = new Map<string, { beforeEach: TestFn[]; afterEach: TestFn[] }>();

export function describe(name: string, fn: () => void): void {
  const previousSuite = currentSuiteName;
  currentSuiteName = name;
  if (!suites.has(name)) {
    suites.set(name, []);
    suiteHooks.set(name, { beforeEach: [], afterEach: [] });
  }
  fn();
  currentSuiteName = previousSuite;
}

export function it(name: string, fn: TestFn): void {
  const list = suites.get(currentSuiteName) || [];
  list.push({ name, fn });
  suites.set(currentSuiteName, list);
}

export const test = it;

export function beforeEach(fn: TestFn): void {
  const hooks = suiteHooks.get(currentSuiteName);
  if (hooks) hooks.beforeEach.push(fn);
}

export function afterEach(fn: TestFn): void {
  const hooks = suiteHooks.get(currentSuiteName);
  if (hooks) hooks.afterEach.push(fn);
}

export function expect(actual: any) {
  return {
    toBe(expected: any) {
      if (actual !== expected) {
        throw new Error(`Expected ${JSON.stringify(actual)} to be ${JSON.stringify(expected)}`);
      }
    },
    toEqual(expected: any) {
      const a = JSON.stringify(actual);
      const e = JSON.stringify(expected);
      if (a !== e) {
        throw new Error(`Expected ${a} to equal ${e}`);
      }
    },
    toBeTruthy() {
      if (!actual) {
        throw new Error(`Expected ${JSON.stringify(actual)} to be truthy`);
      }
    },
    toBeFalsy() {
      if (actual) {
        throw new Error(`Expected ${JSON.stringify(actual)} to be falsy`);
      }
    },
    toBeGreaterThan(num: number) {
      if (typeof actual !== "number" || actual <= num) {
        throw new Error(`Expected ${actual} to be greater than ${num}`);
      }
    },
    toBeGreaterThanOrEqual(num: number) {
      if (typeof actual !== "number" || actual < num) {
        throw new Error(`Expected ${actual} to be greater than or equal to ${num}`);
      }
    },
    toBeLessThan(num: number) {
      if (typeof actual !== "number" || actual >= num) {
        throw new Error(`Expected ${actual} to be less than ${num}`);
      }
    },
    toBeLessThanOrEqual(num: number) {
      if (typeof actual !== "number" || actual > num) {
        throw new Error(`Expected ${actual} to be less than or equal to ${num}`);
      }
    },
    toContain(item: any) {
      if (Array.isArray(actual)) {
        if (!actual.includes(item)) {
          throw new Error(`Expected array to contain ${JSON.stringify(item)}`);
        }
      } else if (typeof actual === "string") {
        if (!actual.includes(String(item))) {
          throw new Error(`Expected string to contain "${item}"`);
        }
      } else {
        throw new Error(`Target is neither array nor string`);
      }
    },
    toThrow(msgSubstring?: string) {
      if (typeof actual !== "function") {
        throw new Error(`Expected function for toThrow matcher`);
      }
      let threw = false;
      let err: any = null;
      try {
        const res = actual();
        if (res && typeof res.then === "function") {
          return res.then(
            () => {
              throw new Error(`Expected async function to throw an error, but it resolved`);
            },
            (e: any) => {
              if (msgSubstring && (!e || !String(e.message || e).includes(msgSubstring))) {
                throw new Error(
                  `Expected error message to contain "${msgSubstring}", got "${e?.message || e}"`,
                );
              }
            },
          );
        }
      } catch (e) {
        threw = true;
        err = e;
      }
      if (!threw) {
        throw new Error(`Expected function to throw an error, but it did not`);
      }
      if (msgSubstring && (!err || !String(err.message || err).includes(msgSubstring))) {
        throw new Error(
          `Expected error message to contain "${msgSubstring}", got "${err?.message || err}"`,
        );
      }
    },
    toSatisfy(predicate: (val: any) => boolean) {
      if (!predicate(actual)) {
        throw new Error(`Value ${JSON.stringify(actual)} failed predicate satisfaction`);
      }
    },
    not: {
      toThrow(msgSubstring?: string) {
        if (typeof actual !== "function") {
          throw new Error(`Expected function for not.toThrow matcher`);
        }
        let threw = false;
        let err: any = null;
        try {
          actual();
        } catch (e) {
          threw = true;
          err = e;
        }
        if (threw) {
          throw new Error(`Expected function NOT to throw, but it threw: ${err?.message || err}`);
        }
      },
    },
  };
}

export async function runSuite(suiteName: string): Promise<TestSuiteResults> {
  const tests = suites.get(suiteName) || [];
  const hooks = suiteHooks.get(suiteName) || { beforeEach: [], afterEach: [] };

  const res: TestSuiteResults = {
    suiteName,
    total: tests.length,
    passed: 0,
    failed: 0,
    errors: [],
  };

  for (const t of tests) {
    try {
      for (const hook of hooks.beforeEach) await hook();
      await t.fn();
      for (const hook of hooks.afterEach) await hook();
      res.passed++;
    } catch (err: any) {
      res.failed++;
      res.errors.push({ testName: t.name, error: err });
    }
  }

  return res;
}

// Main execution entry point when run directly
if (process.argv[1]?.endsWith("runner.ts") || import.meta.url.includes("runner.ts")) {
  (async () => {
    console.log("====================================================");
    console.log("DISPATCH DIARY E2E TEST RUNNER - TIERS 1 TO 4");
    console.log("====================================================");

    // Dynamically import test files
    await import("./tier1_feature_coverage.test.ts");
    await import("./tier2_boundary_corner.test.ts");
    await import("./tier3_cross_feature.test.ts");
    await import("./tier4_real_world.test.ts");

    const allSuites = Array.from(suites.keys());
    let grandTotal = 0;
    let grandPassed = 0;
    let grandFailed = 0;

    const summaryByTier = {
      Tier1: { total: 0, passed: 0, failed: 0 },
      Tier2: { total: 0, passed: 0, failed: 0 },
      Tier3: { total: 0, passed: 0, failed: 0 },
      Tier4: { total: 0, passed: 0, failed: 0 },
    };

    for (const name of allSuites) {
      const res = await runSuite(name);
      grandTotal += res.total;
      grandPassed += res.passed;
      grandFailed += res.failed;

      if (name.includes("Tier 1")) {
        summaryByTier.Tier1.total += res.total;
        summaryByTier.Tier1.passed += res.passed;
        summaryByTier.Tier1.failed += res.failed;
      } else if (name.includes("Tier 2")) {
        summaryByTier.Tier2.total += res.total;
        summaryByTier.Tier2.passed += res.passed;
        summaryByTier.Tier2.failed += res.failed;
      } else if (name.includes("Tier 3")) {
        summaryByTier.Tier3.total += res.total;
        summaryByTier.Tier3.passed += res.passed;
        summaryByTier.Tier3.failed += res.failed;
      } else if (name.includes("Tier 4")) {
        summaryByTier.Tier4.total += res.total;
        summaryByTier.Tier4.passed += res.passed;
        summaryByTier.Tier4.failed += res.failed;
      }

      console.log(`\n[SUITE] ${res.suiteName}: ${res.passed}/${res.total} passed`);
      if (res.errors.length > 0) {
        for (const e of res.errors) {
          console.error(`  ❌ FAIL: ${e.testName}`);
          console.error(`     ${e.error.stack || e.error.message || e.error}`);
        }
      }
    }

    console.log("\n----------------------------------------------------");
    console.log(
      `TIER 1 (Feature Coverage):     ${summaryByTier.Tier1.passed}/${summaryByTier.Tier1.total} passed`,
    );
    console.log(
      `TIER 2 (Boundary & Corner):    ${summaryByTier.Tier2.passed}/${summaryByTier.Tier2.total} passed`,
    );
    console.log(
      `TIER 3 (Cross-Feature):        ${summaryByTier.Tier3.passed}/${summaryByTier.Tier3.total} passed`,
    );
    console.log(
      `TIER 4 (Real-World Scenarios): ${summaryByTier.Tier4.passed}/${summaryByTier.Tier4.total} passed`,
    );
    console.log("----------------------------------------------------");
    console.log(`TOTAL: ${grandPassed}/${grandTotal} passed (Failed: ${grandFailed})`);
    console.log("====================================================");

    if (grandFailed > 0) {
      process.exit(1);
    } else {
      process.exit(0);
    }
  })();
}
