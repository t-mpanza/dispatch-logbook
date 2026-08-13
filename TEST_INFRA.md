# E2E Test Infra: Dispatch Diary Extension

## Test Philosophy

- Opaque-box, requirement-driven. No dependency on internal implementation details.
- Methodology: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial Testing + Real-World Workload Testing.

## Feature Inventory

| #   | Feature                                                                      | Source (requirement) | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
| --- | ---------------------------------------------------------------------------- | -------------------- | :----: | :----: | :----: | :----: |
| 1   | Loading Sheet Header & Config                                                | ORIGINAL_REQUEST §R1 |   5    |   5    |   ✓    |   ✓    |
| 2   | Presets & Auto-Fill (STOCKS, NLH, DBN, NLS, BLOEM, PLK, TIREPOINT)           | ORIGINAL_REQUEST §R1 |   5    |   5    |   ✓    |   ✓    |
| 3   | Table Calculations & Summary Footer (TOTAL TYRES LOADED, TOTAL LOADING TIME) | ORIGINAL_REQUEST §R1 |   5    |   5    |   ✓    |   ✓    |
| 4   | Manual Truck Rows & Exports (Printable PDF & Formatted WhatsApp text)        | ORIGINAL_REQUEST §R1 |   5    |   5    |   ✓    |   ✓    |
| 5   | Companion PWA View & Real-Time Sync                                          | ORIGINAL_REQUEST §R2 |   5    |   5    |   ✓    |   ✓    |
| 6   | Offline Caching & Sync Badges (`Sent`, `Synced`, `Offline saved`)            | ORIGINAL_REQUEST §R2 |   5    |   5    |   ✓    |   ✓    |
| 7   | Multi-Device Media Sync & Storage Repair                                     | ORIGINAL_REQUEST §R3 |   5    |   5    |   ✓    |   ✓    |
| 8   | Fresh Device Restore & Re-push Loop Prevention                               | ORIGINAL_REQUEST §R3 |   5    |   5    |   ✓    |   ✓    |
| 9   | WhatsApp / Telegram Chat Bubble Timeline UI                                  | ORIGINAL_REQUEST §R4 |   5    |   5    |   ✓    |   ✓    |
| 10  | Rich Media Gallery & Lightbox Modal                                          | ORIGINAL_REQUEST §R4 |   5    |   5    |   ✓    |   ✓    |
| 11  | Tactile Haptics (`navigator.vibrate`)                                        | ORIGINAL_REQUEST §R4 |   5    |   5    |   ✓    |   ✓    |

## Test Architecture

- Test runner: Vitest / Node test runner (`npm run test:e2e` / `npx vitest tests/e2e`)
- Test case format: Opaque-box test suites validating data structures, compliance rules, calculations, exports, sync state machines, PWA offline mechanics, and UI state wrappers.
- Directory layout:
  - `tests/e2e/tier1_feature_coverage.test.ts`
  - `tests/e2e/tier2_boundary_corner.test.ts`
  - `tests/e2e/tier3_cross_feature.test.ts`
  - `tests/e2e/tier4_real_world.test.ts`
  - `tests/e2e/runner.ts`

## Real-World Application Scenarios (Tier 4)

| #   | Scenario                                                                                                                                                     | Features Exercised | Complexity |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ | ---------- |
| 1   | Daily Loading Sheet Operation: Presets (STOCKS 1, STOCKS 2, NLH auto-fill), manual additions, summary auto-sum, and WhatsApp/PDF Export                      | F1, F2, F3, F4     | Medium     |
| 2   | Multi-Device Cross-Sync & Media Restore: Scanner entry creation with photo attachment, companion PWA real-time pull, and fresh install restoration           | F5, F6, F7, F8     | High       |
| 3   | Mobile Dispatcher Timeline & Tactile UI Flow: Chat bubble timeline navigation, media lightbox preview, and haptic feedback triggers                          | F9, F10, F11       | Medium     |
| 4   | Offline Shift & Cloud Reconciliation: Full shift logging offline, sync badge updates (`Offline saved` -> `Synced`), duplicate re-push prevention             | F3, F5, F6, F8     | High       |
| 5   | Full End-to-End Operations Lifecycle: Complete workflow combining header setup, presets auto-increment, media upload, offline sync, PWA read, and PDF export | F1-F11             | High       |

## Coverage Thresholds

- Tier 1: ≥5 per feature (11 features × 5 = 55 test cases)
- Tier 2: ≥5 per feature (11 features × 5 = 55 test cases)
- Tier 3: Pairwise feature interaction tests (15 test cases covering major feature pairs)
- Tier 4: Real-world application scenarios (5 application-level scenario tests)
- **Total Minimum Test Cases**: 130 test cases
