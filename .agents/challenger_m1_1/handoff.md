# Milestone 1: Data Models & Core Services — Adversarial Challenge Report

**Working Directory**: `/home/kiddow/Desktop/Work/Despatch Diary/.agents/challenger_m1_1`  
**Role**: Challenger 1 (Critic, Specialist, Empirical Challenger)  
**Milestone**: Milestone 1 (Data Models & Core Services)  
**Verdict**: `REQUEST_CHANGES`  
**Timestamp**: 2026-09-01T19:15:30Z  

---

## Challenge Summary

**Overall risk assessment**: **HIGH**

While the core data structures, GraphQL queries, and PDF/WhatsApp export services demonstrate good baseline stability, adversarial stress testing revealed **4 concrete vulnerabilities and edge-case defects**:
1. **Critical Flaw**: Inability to remove the last attached IBT document due to `LoadingSheetTrip.copyWith` treating `ibtDocuments: null` as a no-op fallback (`ibtDocuments ?? this.ibtDocuments`).
2. **High-Severity Defect**: Inability to step loaded quantities down to 0 on IBT line items in `LoadingSheetViewModel.updateIbtLineQuantity` due to an improper `totalLoadedAcrossAllIbts > 0` condition.
3. **Medium-Severity Edge Case**: `IbtLineItem.overCount` throws runtime `ArgumentError` when `loadedQuantity < 0` because `.clamp(0, loadedQuantity)` executes with `lowerLimit > upperLimit`.
4. **Medium-Severity Sync Defect**: Removing an IBT document from a multi-IBT trip leaves stale `targetQuantity` overriding `ibtTargetTotal` in effective target calculations.

---

## Challenges

### [Critical] Challenge 1: `removeIbtDocument` Fails to Remove the Last IBT Document

- **Assumption challenged**: Calling `LoadingSheetViewModel.removeIbtDocument` removes the specified IBT document from the trip.
- **Attack scenario**:
  1. Attach an IBT document `IBT100` to a trip (`trip.hasIbtDocuments == true`).
  2. User calls `removeIbtDocument(trip: trip, documentNo: 'IBT100')`.
  3. `filtered` becomes empty `[]`.
  4. `removeIbtDocument` attempts: `trip.copyWith(ibtDocuments: filtered.isNotEmpty ? filtered : null)`.
  5. In `loading_sheet_trip.dart` line 123:
     ```dart
     ibtDocuments: ibtDocuments ?? this.ibtDocuments,
     ```
  6. `null ?? this.ibtDocuments` evaluates to `this.ibtDocuments` (the old document list).
- **Blast radius**: The user can never detach an IBT manifest once attached if it is the only IBT on the trip. In the UI, clicking "Remove IBT" appears to succeed but the IBT remains permanently attached after database sync.
- **Mitigation**:
  1. In `LoadingSheetTrip.copyWith`, support explicit clearing or pass an empty list, or use a sentinel/flag pattern for nullable resets.
  2. Alternatively, in `LoadingSheetTrip`, allow `ibtDocuments: filtered` (where empty list `[]` represents no documents, and update `hasIbtDocuments => ibtDocuments != null && ibtDocuments!.isNotEmpty`).

---

### [High] Challenge 2: Stepping Loaded Quantity Down to Zero Fails to Update `trip.quantityLoaded`

- **Assumption challenged**: Stepping down IBT line item quantities in `LoadingSheetViewModel.updateIbtLineQuantity` synchronizes the overall trip loaded count.
- **Attack scenario**:
  1. Trip starts with `quantityLoaded = 0`.
  2. User increments Line 1 from 0 to 5 -> `totalLoadedAcrossAllIbts = 5` -> `trip.quantityLoaded = 5`.
  3. User decrements Line 1 back down to 0 -> `totalLoadedAcrossAllIbts = 0`.
  4. In `loading_sheet_viewmodel.dart` line 167:
     ```dart
     quantityLoaded: totalLoadedAcrossAllIbts > 0
         ? totalLoadedAcrossAllIbts
         : trip.quantityLoaded,
     ```
  5. Because `totalLoadedAcrossAllIbts > 0` is false, `quantityLoaded` is assigned `trip.quantityLoaded` (which is still 5).
- **Blast radius**: If a user corrects a mistaken scan count back to 0 on an IBT load, the overall loading sheet trip retains the outdated non-zero quantity, corrupting daily totals and compliance audits.
- **Mitigation**:
  Change line 167 to:
  ```dart
  quantityLoaded: totalLoadedAcrossAllIbts,
  ```

---

### [Medium] Challenge 3: `IbtLineItem.overCount` Throws `ArgumentError` on Negative Loaded Quantities

- **Assumption challenged**: `IbtLineItem` calculations are crash-safe under all integer values.
- **Attack scenario**:
  1. Construct or deserialize an `IbtLineItem` with `targetTotal: 10` and `loadedQuantity: -5`.
  2. Access `line.overCount`.
  3. In `ibt_manifest.dart` line 25:
     ```dart
     int get overCount => (loadedQuantity - targetTotal).clamp(0, loadedQuantity);
     ```
  4. Evaluates `(-5 - 10).clamp(0, -5)`. Dart's `num.clamp(lowerLimit, upperLimit)` throws:
     `ArgumentError: lowerLimit cannot be greater than upperLimit (0 > -5)`.
- **Blast radius**: Any corrupted data or calculation resulting in a negative loaded quantity will crash the widget tree when rendering over-count badges.
- **Mitigation**:
  Implement `overCount` using branch comparison without inverted clamp limits:
  ```dart
  int get overCount {
    if (loadedQuantity <= targetTotal) return 0;
    return loadedQuantity - targetTotal;
  }
  ```

---

### [Medium] Challenge 4: Target Quantity Desynchronization on Multi-IBT Removal

- **Assumption challenged**: Removing an IBT document updates the trip's target quotas accurately.
- **Attack scenario**:
  1. Trip attaches `IBT-A` (target: 20) and `IBT-B` (target: 30).
  2. `attachIbtDocument` sets `trip.targetQuantity = 50`.
  3. `removeIbtDocument` removes `IBT-B`.
  4. `removeIbtDocument` does not recalculate or clear `targetQuantity`. `trip.targetQuantity` remains 50.
  5. `LoadingSheetTrip.remainingTyres` prioritizes `targetQuantity` (50) over `ibtTargetTotal` (20), calculating remaining tyres against 50 instead of 20.
- **Blast radius**: Multi-document loads display incorrect remaining and progress metrics after removing one of the documents.
- **Mitigation**:
  In `removeIbtDocument`, recalculate `targetQuantity: filtered.isNotEmpty ? filtered.fold(0, (s, d) => s + d.total) : null`.

---

## Stress Test Results

| # | Stress Scenario | Expected Behavior | Actual Behavior | Result |
|---|-----------------|-------------------|-----------------|--------|
| 1 | `IbtLineItem` with zero target & zero loaded quantity | `remaining = 0, overCount = 0, progress = 0.0` | `remaining = 0, overCount = 0, progress = 0.0` | **PASS** |
| 2 | `IbtLineItem` with zero target & 5 loaded quantity | `remaining = 0, overCount = 5, isComplete = false` | `remaining = 0, overCount = 5, isComplete = false` | **PASS** |
| 3 | `IbtLineItem` extreme values (`1,000,000` / `2,000,000`) | No overflow, correct clamp and calculations | Calculations accurate without overflow | **PASS** |
| 4 | Malformed & corrupted JSON in `fromMap` | Defensive fallback to default values without type errors | Handled missing/null/string fields gracefully | **PASS** |
| 5 | `LoadingSheetTrip` effectiveTarget fallback matrix | Standalone, manual, and IBT loads resolve correct targets | Priority hierarchy works as specified | **PASS** |
| 6 | Malformed JWT tokens (garbage, invalid base64, invalid JSON) | `getAuthDetails` returns `isAuthenticated: false` | Caught internally and returns unauthenticated | **PASS** |
| 7 | Cognito OAuth redirect URL permutations | Safe extraction of tokens from fragments and query params | Successfully extracts or safely ignores invalid schemes | **PASS** |
| 8 | AppSync GraphQL 500/502 HTML error responses | Throws descriptive `Exception` with status code | Throws descriptive exception | **PASS** |
| 9 | AppSync GraphQL null/empty `ibt` line items | Throws descriptive "No line items found" exception | Throws descriptive exception | **PASS** |
| 10 | AppSync GraphQL VTL resolver compatibility | Query variables always contain `inv: ""`, `dibt: ""`, `amsInv: ""` | Variables strictly verified | **PASS** |
| 11 | Stepping loaded quantity on IBT line item with negative value | Clamps loaded quantity to 0 | Quantity clamped to 0 | **PASS** |
| 12 | **Stepping loaded quantity down to 0 on IBT line item** | Overall `trip.quantityLoaded` updates to 0 | `trip.quantityLoaded` retains stale non-zero value | **FAIL** |
| 13 | **Removing the last IBT document from a trip** | `trip.ibtDocuments` becomes null or empty | `trip.ibtDocuments` retains old document | **FAIL** |
| 14 | Case-insensitive IBT document replacement | Replacing `'ibt100'` with `'IBT100'` replaces document in-place | In-place replacement works | **PASS** |
| 15 | Multi-IBT document aggregation | Sums targets and loaded counts across all attached documents | Targets aggregated correctly | **PASS** |
| 16 | WhatsApp export on empty trips dataset | Generates formatted 0-trucks summary without error | Text formatted cleanly | **PASS** |
| 17 | PDF export on 0 trips | Produces valid PDF binary without exception | PDF generated cleanly | **PASS** |
| 18 | PDF export on 30+ high-volume trips with IBTs | Multi-page pagination renders without overflow | Multi-page PDF generated cleanly | **PASS** |

---

## Unchallenged Areas

- **Live AWS Cognito Network Infrastructure**: Live cloud authentication was tested using mock HTTP response harnesses matching Cognito IdP and AppSync schemas rather than live production credentials.

---

## 5-Component Handoff Protocol

### 1. Observation
1. In `flutter_app/lib/data/models/loading_sheet_trip.dart` line 123:
   ```dart
   ibtDocuments: ibtDocuments ?? this.ibtDocuments,
   ```
2. In `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart` line 213:
   ```dart
   final updatedTrip = trip.copyWith(
     ibtDocuments: filtered.isNotEmpty ? filtered : null,
   );
   ```
   When `filtered` is empty, passing `null` causes `LoadingSheetTrip.copyWith` to keep `this.ibtDocuments`, failing to remove the document.
3. In `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart` line 167:
   ```dart
   quantityLoaded: totalLoadedAcrossAllIbts > 0
       ? totalLoadedAcrossAllIbts
       : trip.quantityLoaded,
   ```
   When `totalLoadedAcrossAllIbts == 0`, `quantityLoaded` retains stale `trip.quantityLoaded`.
4. In `flutter_app/lib/data/models/ibt_manifest.dart` line 25:
   ```dart
   int get overCount => (loadedQuantity - targetTotal).clamp(0, loadedQuantity);
   ```
   Throws `ArgumentError` if `loadedQuantity < 0`.

### 2. Logic Chain
1. Document removal requires mutating the trip state such that `trip.hasIbtDocuments` becomes `false` and `trip.ibtDocuments` is cleared.
2. Because `copyWith` defaults to preserving the current value when the passed parameter is `null`, passing `null` cannot clear nullable fields.
3. Consequently, calling `removeIbtDocument` on a trip with 1 document leaves that document in place and fails to persist the removal.
4. Similarly, `updateIbtLineQuantity` incorrectly treats `totalLoadedAcrossAllIbts == 0` as "do not update", preventing a trip's loaded count from returning to 0.

### 3. Caveats
- No other architectural defects were found in the serialization layer, GraphQL parsing, or export services.
- Fixing these issues requires targeted updates in `loading_sheet_trip.dart`, `loading_sheet_viewmodel.dart`, and `ibt_manifest.dart`.

### 4. Conclusion
Milestone 1 code is well-architected but contains 4 concrete, reproducible bugs.
**Verdict**: `REQUEST_CHANGES` (Worker 1 should apply the specified mitigations and add regression tests).

### 5. Verification Method
1. In `flutter_app`, verify that `removeIbtDocument` clears `ibtDocuments` when the last document is removed.
2. Verify that `updateIbtLineQuantity` updates `quantityLoaded` to 0 when all lines are set to 0.
3. Run:
   ```bash
   cd "/home/kiddow/Desktop/Work/Despatch Diary/flutter_app"
   flutter test
   ```
