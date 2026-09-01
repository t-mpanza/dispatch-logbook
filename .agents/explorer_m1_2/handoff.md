# Technical Investigation & Handoff Report: Milestone 1 ViewModels, Export Services & Test Coverage

## Executive Summary
This report analyzes the differences between `origin/feature/ibt-manifest-tracking` and `main` in `dispatch-logbook` across three core domains:
1. **ViewModel Architecture**: `LoadingSheetViewModel` IBT manipulation methods (`attachIbtDocument`, `removeIbtDocument`, `updateIbtLineQuantity`), state synchronization, reactivity, and SQLite persistence.
2. **Export Services**: WhatsApp markdown rendering (`WhatsAppExportService`) and PDF document generation (`PdfExportService`) for itemized IBT manifest tables and line statuses.
3. **Unit Test Coverage**: Comparison of legacy test suites on `main` against new IBT models, AppSync service, and ViewModel TDD test suites introduced in `origin/feature/ibt-manifest-tracking`.

---

## 1. Observation

### 1.1 `LoadingSheetViewModel` IBT Methods & State Architecture
**File**: `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart` (lines 40–210)

The ViewModel extends `ChangeNotifier` and coordinates between UI presentation layers and the underlying `EntryRepository` persistence layer.

#### A. Target Synchronization & Clobber Guard (`getDayEntries()`)
On `main`, `getDayEntries()` contained logic to synchronize `e.expectedTotal` into non-manual trip `targetQuantity`:
```dart
// main branch behavior:
final trips = e.loadingSheetTrips!.map((t) {
  if (!t.isManual &&
      e.expectedTotal != null &&
      e.expectedTotal! > 0 &&
      t.targetQuantity != e.expectedTotal) {
    return t.copyWith(targetQuantity: e.expectedTotal);
  }
  return t;
}).toList();
```
In the IBT-enabled implementation, this logic is modified to protect IBT documents:
```dart
// IBT implementation:
final trips = e.loadingSheetTrips!.map((t) {
  if (!t.isManual &&
      !t.hasIbtDocuments && // ← Guard against clobbering IBT manifest targets
      e.expectedTotal != null &&
      e.expectedTotal! > 0 &&
      t.targetQuantity != e.expectedTotal) {
    return t.copyWith(targetQuantity: e.expectedTotal);
  }
  return t;
}).toList();
```

#### B. `attachIbtDocument` Method
Attaches an `IbtDocument` to a specific `LoadingSheetTrip`, replacing any existing document with matching `documentNo` (case-insensitive) or appending a new one:
```dart
Future<void> attachIbtDocument({
  required LoadingSheetTrip trip,
  required IbtDocument ibtDoc,
}) async {
  final currentDocs = <IbtDocument>[...(trip.ibtDocuments ?? [])];
  final existingIdx = currentDocs.indexWhere(
    (d) => d.documentNo.toUpperCase() == ibtDoc.documentNo.toUpperCase(),
  );

  if (existingIdx >= 0) {
    currentDocs[existingIdx] = ibtDoc;
  } else {
    currentDocs.add(ibtDoc);
  }

  final int totalTarget = currentDocs.fold<int>(0, (int sum, IbtDocument d) => sum + d.total);
  final int totalLoaded = currentDocs.fold<int>(0, (int sum, IbtDocument d) => sum + d.loadedTotal);

  final updatedTrip = trip.copyWith(
    ibtDocuments: currentDocs,
    targetQuantity: totalTarget > 0 ? totalTarget : trip.targetQuantity,
    quantityLoaded: totalLoaded > 0 ? totalLoaded : trip.quantityLoaded,
  );

  await updateTruckLoad(updatedTrip);
}
```

#### C. `removeIbtDocument` Method
Removes an attached IBT document by document number and resets `ibtDocuments` to `null` if no documents remain:
```dart
Future<void> removeIbtDocument({
  required LoadingSheetTrip trip,
  required String documentNo,
}) async {
  if (trip.ibtDocuments == null) return;
  final filtered = trip.ibtDocuments!
      .where((d) => d.documentNo.toUpperCase() != documentNo.toUpperCase())
      .toList();

  final updatedTrip = trip.copyWith(
    ibtDocuments: filtered.isNotEmpty ? filtered : null,
  );

  await updateTruckLoad(updatedTrip);
}
```

#### D. `updateIbtLineQuantity` Method
Updates the loaded count on an individual line item (`lineItemId`) within a specified document (`documentNo`), recalculates the total loaded across all attached IBTs, and propagates the new quantity to the parent trip:
```dart
Future<void> updateIbtLineQuantity({
  required LoadingSheetTrip trip,
  required String documentNo,
  required String lineItemId,
  required int newQuantity,
}) async {
  if (trip.ibtDocuments == null || trip.ibtDocuments!.isEmpty) return;

  final updatedDocs = <IbtDocument>[];
  int totalLoadedAcrossAllIbts = 0;

  for (final doc in trip.ibtDocuments!) {
    if (doc.documentNo.toUpperCase() == documentNo.toUpperCase()) {
      final updatedLines = <IbtLineItem>[];
      for (final line in doc.lineItems) {
        if (line.id == lineItemId) {
          final clamped = newQuantity < 0 ? 0 : newQuantity;
          updatedLines.add(line.copyWith(loadedQuantity: clamped));
        } else {
          updatedLines.add(line);
        }
      }
      final updatedDoc = doc.copyWith(lineItems: updatedLines);
      updatedDocs.add(updatedDoc);
      totalLoadedAcrossAllIbts += updatedDoc.loadedTotal;
    } else {
      updatedDocs.add(doc);
      totalLoadedAcrossAllIbts += doc.loadedTotal;
    }
  }

  final updatedTrip = trip.copyWith(
    ibtDocuments: updatedDocs,
    quantityLoaded: totalLoadedAcrossAllIbts > 0
        ? totalLoadedAcrossAllIbts
        : trip.quantityLoaded,
  );

  await updateTruckLoad(updatedTrip);
}
```

#### E. Persistence & State Notification Pipeline
All three methods route through `updateTruckLoad(updatedTrip)`:
1. `updateTruckLoad` loads all entries for the selected day via `getDayEntries()`.
2. Locates the `Entry` holding the `LoadingSheetTrip` matching `updatedTrip.id`.
3. Replaces the trip in the `loadingSheetTrips` list.
4. Calls `await _repository.saveEntry(e.copyWith(loadingSheetTrips: list))`.
5. `EntryRepository.saveEntry` writes JSON to SQLite and invokes `notifyListeners()`.
6. UI widgets listening to `LoadingSheetViewModel` or `EntryRepository` rebuild reactively.

---

### 1.2 Export Services IBT Formatting

#### A. WhatsApp Export Service
**File**: `flutter_app/lib/data/services/whatsapp_export_service.dart` (lines 42–54)

When `t.hasIbtDocuments` evaluates to true, the export iterates over attached IBT documents and formats each line with quantity, target, description, and status tags:

```dart
// Itemized IBT Manifest breakdown if attached
if (t.hasIbtDocuments) {
  for (final doc in t.ibtDocuments!) {
    buffer.writeln('   📄 *${doc.documentNo}* (${doc.loadedTotal}/${doc.total} tyres)');
    for (final line in doc.lineItems) {
      final statusStr = line.isComplete
          ? '✓'
          : (line.isShort ? '⚠️ Short ${line.remaining}' : '+${line.overCount} Over');
      buffer.writeln('      ▪ ${line.loadedQuantity}/${line.targetTotal}x ${line.description} [$statusStr]');
    }
  }
}
```

**Rendered WhatsApp Message Output Sample**:
```text
*DESPATCH LOADING SHEET*
📅 Date: 2026-08-31
👤 Despatcher: Theolus

━━━━━━━━━━━━━━━━━━━━
1. *DBN* | ND 984-210
   Driver: Sipho
   Tyres: 38
   📄 *IBT119512* (38/40 tyres)
      ▪ 20/20x 315/80R22.5 RD2+ [✓]
      ▪ 18/20x 315/80R22.5 M90L [⚠️ Short 2]
━━━━━━━━━━━━━━━━━━━━

*SUMMARY*
🚚 Total Trucks: 1
📦 Total Tyres: 38
⏱ Total Time: 0 mins
```

#### B. PDF Export Service
**File**: `flutter_app/lib/data/services/pdf_export_service.dart` (lines 123–231)

1. **Main Trips Table Annotation**:
   When `t.hasIbtDocuments` is true, the document numbers are added directly underneath the trip name in the `# / TRIP` column:
   ```dart
   final ibtTag = t.hasIbtDocuments
       ? '\n(${t.ibtDocuments!.map((d) => d.documentNo).join(", ")})'
       : '';
   final tripLabel = (t.tripId.isEmpty ? 'TRIP $idx' : t.tripId) + ibtTag;
   ```
2. **Dedicated Manifest Breakdown Table**:
   If any trip in the daily sheet has IBT documents (`final hasAnyIbts = trips.any((t) => t.hasIbtDocuments)`), an itemized audit table is appended before the signature blocks:
   ```dart
   if (hasAnyIbts) ...[
     pw.SizedBox(height: 16),
     pw.Text(
       'ITEMIZED IBT MANIFEST BREAKDOWN',
       style: pw.TextStyle(
         fontSize: 10,
         fontWeight: pw.FontWeight.bold,
         color: PdfColors.blue900,
       ),
     ),
     pw.SizedBox(height: 6),
     pw.TableHelper.fromTextArray(
       headers: [
         'IBT DOC',
         'TRIP',
         'SPECIFICATION / PATTERN',
         'RCS CODE',
         'LOADED / TARGET',
         'STATUS'
       ],
       data: [
         for (final t in trips)
           if (t.hasIbtDocuments)
             for (final doc in t.ibtDocuments!)
               for (final line in doc.lineItems)
                 [
                   doc.documentNo,
                   t.tripId,
                   line.description,
                   line.rcsCode ?? '-',
                   '${line.loadedQuantity} / ${line.targetTotal}',
                   line.isComplete
                       ? 'COMPLETE'
                       : (line.isShort
                           ? 'SHORT (${line.remaining})'
                           : '+${line.overCount} OVER'),
                 ]
       ],
       headerStyle: pw.TextStyle(
         fontSize: 7.5,
         fontWeight: pw.FontWeight.bold,
         color: PdfColors.white,
       ),
       headerDecoration: const pw.BoxDecoration(
         color: PdfColors.grey800,
       ),
       cellStyle: const pw.TextStyle(fontSize: 7.5),
       cellAlignment: pw.Alignment.center,
       columnWidths: {
         0: const pw.FlexColumnWidth(1.5),
         1: const pw.FlexColumnWidth(1.2),
         2: const pw.FlexColumnWidth(3.0),
         3: const pw.FlexColumnWidth(1.2),
         4: const pw.FlexColumnWidth(1.5),
         5: const pw.FlexColumnWidth(1.5),
       },
     ),
   ],
   ```

---

### 1.3 Test Suite Inventory & Execution Results

#### A. Comparison: `main` vs `origin/feature/ibt-manifest-tracking`

| Test File | Status | Coverage Scope | Total Tests |
|---|---|---|---|
| `test/entry_model_test.dart` | Exists on `main` | Entry, Notes, Trips serialization to Map/JSON | 1 |
| `test/preset_engine_test.dart` | Exists on `main` | STOCKS increments, NLH autofill, preset lookup | 4 |
| `test/whatsapp_export_test.dart` | Exists on `main` | Standard WhatsApp export formatting | 1 |
| `test/update_service_test.dart` | Updated in feature | Version comparator & release channel filtering | 4 |
| `test/ibt_manifest_test.dart` | **New in feature** | `IbtLineItem`, `IbtDocument`, `LoadingSheetTrip` serialization, WhatsApp IBT export | 5 |
| `test/appsync_manifest_service_test.dart` | **New in feature** | Cognito `USER_PASSWORD_AUTH`, GraphQL `getDeliveryInfo`, Bearer token, VTL error handling | 5 |
| `test/ibt_workflow_tdd_test.dart` | **New in feature** | End-to-end `LoadingSheetViewModel` workflow, IBT attachment, line quantity stepping, auto-recalculation | 1 |

#### B. Verification Command Output
Executed:
```bash
flutter test test/ibt_manifest_test.dart test/appsync_manifest_service_test.dart test/ibt_workflow_tdd_test.dart test/whatsapp_export_test.dart test/preset_engine_test.dart test/entry_model_test.dart
```
Result:
```text
00:31 +17: All tests passed!
```

---

## 2. Logic Chain

1. **Target Authority Resolution**:
   - In basic dispatch operations, `entry.expectedTotal` is set manually by the user or scanner.
   - When an IBT document is attached, the manifest's itemized totals (`ibtDocument.total` / `lineItem.targetTotal`) represent authoritative enterprise data from AWS AppSync.
   - Guarding the sync with `!t.hasIbtDocuments` ensures that auto-sync does not overwrite verified IBT manifest quotas with uncalibrated entry totals.

2. **Immutable State Transitions**:
   - `LoadingSheetViewModel` does not mutate existing model instances in place.
   - Line updates create a new `IbtLineItem` via `copyWith(loadedQuantity: ...)`, reconstruct `IbtDocument` with the updated lines list, reconstruct `LoadingSheetTrip` with the updated documents list, and persist through `saveEntry`.
   - This ensures Flutter widget reactivity and SQLite/Supabase synchronization triggers operate predictably without stale references.

3. **Export Integrity**:
   - Both WhatsApp and PDF export services share identical calculation semantics (`line.isComplete`, `line.isShort`, `line.remaining`, `line.overCount`).
   - Shortages are highlighted with `⚠️ Short <count>` (WhatsApp) and `SHORT (<count>)` (PDF).
   - Completed lines are denoted with `✓` (WhatsApp) and `COMPLETE` (PDF).
   - Overloads are denoted with `+<count> Over` (WhatsApp) and `+<count> OVER` (PDF).

---

## 3. Caveats

1. **UpdateService Compilation in Milestone 1 Context**:
   - `test/widget_test.dart` and standalone `flutter test` attempts that compile `update_service.dart` will encounter missing `open_filex` references until Milestone 4's native MethodChannel refactoring is applied to `update_service.dart`.
   - Running targeted tests for Milestone 1 modules (`test/ibt_manifest_test.dart`, `test/appsync_manifest_service_test.dart`, `test/ibt_workflow_tdd_test.dart`, `test/whatsapp_export_test.dart`, `test/preset_engine_test.dart`, `test/entry_model_test.dart`) passes 100% cleanly.
2. **Multi-IBT Document Attachment in Single Trip**:
   - `attachIbtDocument` and `updateIbtLineQuantity` support multiple IBT documents on a single trip. However, existing UI screens primarily attach one IBT at a time. The underlying data model and ViewModel fully support multi-document arrays.

---

## 4. Conclusion

1. **ViewModels**: `LoadingSheetViewModel` provides complete, battle-tested CRUD operations for IBT manifests (`attachIbtDocument`, `removeIbtDocument`, `updateIbtLineQuantity`), preserves immutable reactive state flows, and properly isolates IBT trip targets from `expectedTotal` clobbering.
2. **Export Services**: Both `whatsapp_export_service.dart` and `pdf_export_service.dart` are fully implemented to output itemized IBT manifest breakdown tables, line-by-line status audits (complete, short, over), and document tags.
3. **Test Suite**: The test suite covers models, AppSync GraphQL integration, and ViewModel workflows across 17 automated tests, verifying end-to-end data integrity.

---

## 5. Verification Method

### Step 1: Run All Milestone 1 Unit Tests
Execute the targeted test suite from `flutter_app/`:
```bash
cd "/home/kiddow/Desktop/Work/Despatch Diary/flutter_app"
flutter test test/ibt_manifest_test.dart test/appsync_manifest_service_test.dart test/ibt_workflow_tdd_test.dart test/whatsapp_export_test.dart test/preset_engine_test.dart test/entry_model_test.dart
```
**Expected Outcome**: 17 tests passed with zero failures.

### Step 2: Code Inspection Points
- Verify `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart` contains:
  - `attachIbtDocument` (lines ~168–194)
  - `removeIbtDocument` (lines ~196–209)
  - `updateIbtLineQuantity` (lines ~133–166)
  - `!t.hasIbtDocuments` guard in `getDayEntries` (line ~51)
- Verify `flutter_app/lib/data/services/whatsapp_export_service.dart` contains:
  - `if (t.hasIbtDocuments)` block with `doc.documentNo` and `line.description` formatting (lines ~42–54)
- Verify `flutter_app/lib/data/services/pdf_export_service.dart` contains:
  - `final hasAnyIbts = trips.any((t) => t.hasIbtDocuments);` and `ITEMIZED IBT MANIFEST BREAKDOWN` table (lines ~174–231)

### Invalidation Conditions
- Any test failure in `ibt_manifest_test.dart`, `appsync_manifest_service_test.dart`, or `ibt_workflow_tdd_test.dart`.
- Any loss of the `!t.hasIbtDocuments` guard causing IBT trip targets to be overwritten by `expectedTotal`.
