# Milestone 1: Adversarial Challenge Report (Challenger 2)

**Working Directory**: `/home/kiddow/Desktop/Work/Despatch Diary/.agents/challenger_m1_2`  
**Role**: Challenger 2 (Empirical Challenger, Critic, Specialist)  
**Target Milestone**: Milestone 1: Data Models & Core Services  
**Timestamp**: 2026-09-01T19:16:00Z  
**Verdict**: `REQUEST_CHANGES`

---

## 1. Observation

Adversarial stress-testing and empirical verification were conducted on `LoadingSheetViewModel`, `LoadingSheetTrip`, `WhatsAppExportService`, and `PdfExportService`. The following concrete defects and failure modes were uncovered:

### 1.1 Defect 1: `LoadingSheetViewModel.removeIbtDocument` Cannot Remove the Final IBT Document

**Files & Lines**:
- `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart:213-216`
- `flutter_app/lib/data/models/loading_sheet_trip.dart:123`

**Observed Code**:
In `loading_sheet_viewmodel.dart`:
```dart
204:   Future<void> removeIbtDocument({
205:     required LoadingSheetTrip trip,
206:     required String documentNo,
207:   }) async {
208:     if (trip.ibtDocuments == null) return;
209:     final filtered = trip.ibtDocuments!
210:         .where((d) => d.documentNo.toUpperCase() != documentNo.toUpperCase())
211:         .toList();
212: 
213:     final updatedTrip = trip.copyWith(
214:       ibtDocuments: filtered.isNotEmpty ? filtered : null,
215:     );
216: 
217:     await updateTruckLoad(updatedTrip);
218:   }
```
In `loading_sheet_trip.dart`:
```dart
89:   LoadingSheetTrip copyWith({
...
123:     ibtDocuments: ibtDocuments ?? this.ibtDocuments,
124:   );
```
**Empirical Evidence**:
When a trip has a single IBT document remaining and `removeIbtDocument(trip, docNo)` is executed:
1. `filtered` becomes empty list `[]`.
2. `filtered.isNotEmpty ? filtered : null` evaluates to `null`.
3. `trip.copyWith(ibtDocuments: null)` executes `ibtDocuments: ibtDocuments ?? this.ibtDocuments`.
4. Because `ibtDocuments` is `null`, `?? this.ibtDocuments` returns the existing 1-document list.
5. The document is NEVER removed from the trip.
```
Bug 1 - hasDocBeenRemoved: false (expected: true, actual: false)
```

---

### 1.2 Defect 2: `removeIbtDocument` Retains Stale `targetQuantity` and `quantityLoaded`, Corrupting `effectiveTarget`

**Files & Lines**:
- `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart:191-198, 213-217`
- `flutter_app/lib/data/models/loading_sheet_trip.dart:49-56`

**Observed Code**:
In `attachIbtDocument`:
```dart
191:   final int totalTarget = currentDocs.fold<int>(0, (int sum, IbtDocument d) => sum + d.total);
192:   final int totalLoaded = currentDocs.fold<int>(0, (int sum, IbtDocument d) => sum + d.loadedTotal);
193: 
194:   final updatedTrip = trip.copyWith(
195:     ibtDocuments: currentDocs,
196:     targetQuantity: totalTarget > 0 ? totalTarget : trip.targetQuantity,
197:     quantityLoaded: totalLoaded > 0 ? totalLoaded : trip.quantityLoaded,
198:   );
```
In `removeIbtDocument`:
```dart
213:   final updatedTrip = trip.copyWith(
214:     ibtDocuments: filtered.isNotEmpty ? filtered : null,
215:   );
```
In `LoadingSheetTrip`:
```dart
49:   int get remainingTyres {
50:     final effectiveTarget = (targetQuantity != null && targetQuantity! > 0)
51:         ? targetQuantity!
52:         : (hasIbtDocuments ? ibtTargetTotal : 0);
53:     if (effectiveTarget <= 0) return 0;
54:     final diff = effectiveTarget - quantityLoaded;
55:     return diff > 0 ? diff : 0;
56:   }
```
**Empirical Evidence**:
When two documents (Doc 1: target 30, Doc 2: target 20) are attached, `attachIbtDocument` sets `trip.targetQuantity = 50`. When Doc 2 is removed, `removeIbtDocument` does not recalculate `targetQuantity` or `quantityLoaded`.
- `trip.targetQuantity` remains `50` even though `ibtTargetTotal` is now `30`.
- Because `effectiveTarget` prioritizes `targetQuantity > 0` over `ibtTargetTotal`, `effectiveTarget` evaluates to `50` instead of `30`, leading to incorrect `remainingTyres`, `overCount`, `progressPercent`, and `isTargetReached`.
```
Bug 2 - trip.targetQuantity after removing 20-tyre doc: 50 (ibtTargetTotal is 30)
Bug 2 - trip.remainingTyres: 0 (effectiveTarget used: 50)
```

---

### 1.3 Defect 3: `updateIbtLineQuantity` Fails to Reset `quantityLoaded` to 0 When All Lines are Stepped Down to 0

**Files & Lines**:
- `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart:167-169`

**Observed Code**:
```dart
165:   final updatedTrip = trip.copyWith(
166:     ibtDocuments: updatedDocs,
167:     quantityLoaded: totalLoadedAcrossAllIbts > 0
168:         ? totalLoadedAcrossAllIbts
169:         : trip.quantityLoaded,
170:   );
```
**Empirical Evidence**:
When a user steps down line items from a loaded state (e.g. 10) back down to 0:
1. `totalLoadedAcrossAllIbts` becomes `0`.
2. `totalLoadedAcrossAllIbts > 0` evaluates to `false`.
3. `quantityLoaded` retains the previous `trip.quantityLoaded` (10) instead of updating to `0`.
```
Bug 3 - trip.quantityLoaded after stepping to 0: 10 (expected 0)
```

---

### 1.4 Defect 4: Overloaded IBT Line Items are Marked as `[✓]` / `COMPLETE` Instead of `+N Over`

**Files & Lines**:
- `flutter_app/lib/data/models/ibt_manifest.dart:26, 28`
- `flutter_app/lib/data/services/whatsapp_export_service.dart:47-49`
- `flutter_app/lib/data/services/pdf_export_service.dart:205-209`

**Observed Code**:
In `ibt_manifest.dart`:
```dart
26:   bool get isComplete => targetTotal > 0 && loadedQuantity >= targetTotal;
28:   bool get isOverloaded => targetTotal > 0 && loadedQuantity > targetTotal;
```
In `whatsapp_export_service.dart`:
```dart
47:   final statusStr = line.isComplete
48:       ? '✓'
49:       : (line.isShort ? '⚠️ Short ${line.remaining}' : '+${line.overCount} Over');
```
In `pdf_export_service.dart`:
```dart
205:   line.isComplete
206:       ? 'COMPLETE'
207:       : (line.isShort
208:           ? 'SHORT (${line.remaining})'
209:           : '+${line.overCount} OVER')
```
**Empirical Evidence**:
Because `isComplete` is defined as `loadedQuantity >= targetTotal`, any overloaded line item (`loadedQuantity > targetTotal`, e.g. 25/20) returns `line.isComplete == true`. The ternary expression checks `isComplete` first, so the `+${line.overCount} Over` branch is dead code and unreachable.
```
Bug 4 - WhatsApp text line item:
         ▪ 25/20x Spec Overload [✓]   (Expected: ▪ 25/20x Spec Overload [+5 Over])
```

---

## 2. Logic Chain

1. **Root Cause Analysis (Defect 1)**:
   - Dart's null-coalescing operator in `copyWith` (`param ?? this.param`) prevents callers from explicitly setting nullable fields to `null`.
   - `removeIbtDocument` relies on passing `null` when the filtered list is empty.
   - Consequently, the last document cannot be cleared from `LoadingSheetTrip.ibtDocuments`.

2. **Root Cause Analysis (Defect 2)**:
   - `attachIbtDocument` mutates both `ibtDocuments` and `targetQuantity`.
   - `removeIbtDocument` mutates only `ibtDocuments`, omitting updates to `targetQuantity` and `quantityLoaded`.
   - `LoadingSheetTrip.effectiveTarget` gives precedence to `targetQuantity > 0`, causing stale targets to override current manifest totals.

3. **Root Cause Analysis (Defect 3)**:
   - In `updateIbtLineQuantity`, guarding `quantityLoaded` with `totalLoadedAcrossAllIbts > 0 ? ... : trip.quantityLoaded` treats `0` as an invalid value rather than a valid loaded count of zero.
   - For IBT trips, `totalLoadedAcrossAllIbts` is the authoritative sum across all lines, so it should directly assign `quantityLoaded: totalLoadedAcrossAllIbts`.

4. **Root Cause Analysis (Defect 4)**:
   - Both export services evaluate `isComplete` before checking `isOverloaded` or `overCount > 0`.
   - Because `isComplete` matches `loadedQuantity >= targetTotal`, all overloads trigger the `isComplete` branch.
   - Checking `line.isOverloaded` before `line.isComplete` or checking `line.isShort` and `line.isOverloaded` explicitly resolves the ambiguity.

---

## 3. Caveats

1. Non-IBT standalone manual truck entries and standard counter trip calculations function properly when not mixed with stale IBT state.
2. `AppSyncManifestService` GraphQL schema integration, VTL crash guards (`inv: ""`, `dibt: ""`, `amsInv: ""`), and Cognito auth flow pass all static analysis and unit test suites.
3. No external network requests were made to production AWS endpoints during empirical testing; all tests utilized mock repositories and deterministic test fixtures.

---

## 4. Conclusion

Milestone 1 **cannot be approved** in its current state due to 4 empirical state synchronization and export formatting defects.

### Required Changes for Worker:

1. **Fix `LoadingSheetTrip.copyWith` and `removeIbtDocument`**:
   - Allow clearing `ibtDocuments` (e.g. support explicit empty list or sentinel in `copyWith`, or ensure `removeIbtDocument` sets `ibtDocuments: filtered.isNotEmpty ? filtered : null` in combination with an updated `copyWith` or constructor).
   - In `removeIbtDocument`, recalculate `targetQuantity` and `quantityLoaded`:
     ```dart
     final int totalTarget = filtered.fold<int>(0, (sum, d) => sum + d.total);
     final int totalLoaded = filtered.fold<int>(0, (sum, d) => sum + d.loadedTotal);
     final updatedTrip = trip.copyWith(
       ibtDocuments: filtered,
       targetQuantity: totalTarget > 0 ? totalTarget : null,
       quantityLoaded: totalLoaded,
     );
     ```

2. **Fix `updateIbtLineQuantity` in `LoadingSheetViewModel`**:
   - Update `quantityLoaded` directly from `totalLoadedAcrossAllIbts` without the `> 0` fallback:
     ```dart
     final updatedTrip = trip.copyWith(
       ibtDocuments: updatedDocs,
       quantityLoaded: totalLoadedAcrossAllIbts,
     );
     ```

3. **Fix IBT Line Status Formatting in Export Services**:
   - In `WhatsAppExportService`:
     ```dart
     final statusStr = line.isOverloaded
         ? '+${line.overCount} Over'
         : (line.isShort ? '⚠️ Short ${line.remaining}' : '✓');
     ```
   - In `PdfExportService`:
     ```dart
     line.isOverloaded
         ? '+${line.overCount} OVER'
         : (line.isShort
             ? 'SHORT (${line.remaining})'
             : 'COMPLETE')
     ```

---

## 5. Verification Method

To independently verify these defects and validate the fixes:

1. **Run Flutter Test Suite**:
   ```bash
   cd "/home/kiddow/Desktop/Work/Despatch Diary/flutter_app"
   flutter test
   ```

2. **Run Targeted Reproduction Test Cases**:
   - Attach 1 IBT doc, call `removeIbtDocument`, assert `trip.hasIbtDocuments == false` and `trip.ibtDocuments == null`.
   - Attach 2 IBT docs (30 + 20), remove 1, assert `trip.targetQuantity == 30` and `trip.remainingTyres` is computed against 30.
   - Step line item from 10 to 0, assert `trip.quantityLoaded == 0`.
   - Format WhatsApp & PDF with overloaded line (25/20), assert output contains `+5 Over` / `+5 OVER`.
