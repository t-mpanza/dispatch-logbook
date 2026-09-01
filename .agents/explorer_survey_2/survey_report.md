# UI Grafting Survey Report: Requirements R3 & R4
**AWS AppSync IBT Manifest Tracking Subsystem Port**
**Explorer**: Explorer Survey 2
**Scope**: Requirement R3 (Port IBT UI Components) & Requirement R4 (Surgical UI Integration)
**Repository Target**: `dispatch-logbook` (`flutter_app/`)
**Branch Comparison**: `main` (commit `26047b8`) vs `origin/feature/ibt-manifest-tracking` (commit `2efb499`)

---

## 1. Executive Summary & Survey Scope

### 1.1 Context & Architectural Divergence
Both branches diverged from commit `a28e1fa` (tag `v2.0.47`):
- **`main` (v2.0.48 – v2.1.0-rc7)**: Received 11 major UI, theme, and UX commits:
  1. Full-fidelity **Daylight Theme** (light mode scaffold `Color(0xFFF1F5F9)`, Slate text palette, dynamic theme accessors, light glass decorations).
  2. Multi-place **ThemeToggle** & 3-way theme switcher.
  3. **High-density compact counter layout** (saving 210px screen space by eliminating redundant truck assignment cards, shrinking button heights to 40-42px, 10px padding).
  4. **Hold-to-repeat target steppers** and quick increment pills (`+1`, `+5`, `+10`, `+20`, `+50`) with auto-repeat.
  5. Real-time **Target Tyres bidirectional sync** and progress indicators.
  6. **Interactive media captions** with quick tags, inline editor, and caption editing in `PhotoLightbox`.
  7. In-app **PDF preview modal** (`PdfPreviewScreen.openLoadingSheet(...)`).
  8. Optimistic entry saving indicators (`_cachedEntry`, `_isSaved` pill).
- **`origin/feature/ibt-manifest-tracking` (v2.1.0-rc1-ibt – v2.1.0-rc7-ibt)**: Focused entirely on IBT data fetching, Cognito authentication, and multi-line counters:
  1. IBT Manifest data model (`IbtDocument`, `IbtLineItem`).
  2. AppSync GraphQL client (`AppSyncManifestService`).
  3. Cognito OAuth WebView and In-App Auth Dialog (`AwsLoginWebviewScreen`, `AwsAuthDialog`).
  4. IBT Line Items modal bottom sheet (`IbtLineItemsSheet`).
  5. Multi-line counter breakdown and overshoot warning dialog (`_warnIfOver`).
  6. STOCKS preset IBT document attachment workflow in `NewEntryScreen`.

### 1.2 Core Risk & Golden Rule
> ⚠️ **CRITICAL RISK**: Because the feature branch branched off older code (v2.0.47), blind merging or replacing files from `feature/ibt-manifest-tracking` will **destroy** all Daylight theme support, compact button sizing, repeat steppers, interactive photo captioning, and PDF previewing on `main`.
>
> **GOLDEN GRAFTING RULE**:
> **Main's visual styling, layout sizing, and Daylight theme MUST take absolute precedence.**
> All IBT logic, state variables, callbacks, and modals must be surgically injected into `main`'s existing widgets and themed using `AppColors.dynamic*` and `GlassDecorations.*(context: context)`.

---

## 2. Requirement R3: Examination of `lib/widgets/ibt_line_items_sheet.dart`

### 2.1 File Location & Purpose
- **Path**: `flutter_app/lib/presentation/widgets/ibt_line_items_sheet.dart`
- **Purpose**: A modal bottom sheet allowing the despatcher to inspect line-item breakdowns for all IBT documents attached to a truck trip, view per-line target vs loaded counts, and increment/decrement loaded quantities via steppers (`-1`, `+1`, `+5`).

### 2.2 Component Architecture & Lifecycle
- **Widget**: `StatefulWidget` (`IbtLineItemsSheet`) + `_IbtLineItemsSheetState`.
- **Static Helper**:
  ```dart
  static Future<void> show(
    BuildContext context, {
    required LoadingSheetTrip trip,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IbtLineItemsSheet(trip: trip),
    );
  }
  ```
- **State**:
  - `late LoadingSheetTrip _currentTrip`: initialized in `initState()` from `widget.trip`.
  - Refreshed whenever a line item quantity changes.
- **Dependencies**:
  - `package:provider/provider.dart`
  - `LoadingSheetViewModel` (`context.read<LoadingSheetViewModel>()`)
  - `IbtDocument`, `IbtLineItem`, `LoadingSheetTrip`
  - `AppColors`, `GlassDecorations`, `AppHaptics`

### 2.3 Visual Hierarchy & UI Breakdown
1. **Container Constraint**: `maxHeight: MediaQuery.of(context).size.height * 0.85`
2. **Drag Handle**: Centered 40×4 pill (`borderRadius: 2`).
3. **Header Row**:
   - Icon: `Icons.inventory_2_outlined` (`AppColors.primaryGlow`).
   - Title: `_currentTrip.tripId.isNotEmpty ? '${_currentTrip.tripId} — IBT Breakdown' : 'IBT Manifest Breakdown'`.
   - Subtitle: `Vehicle: ${trip.reg} • Driver: ${trip.driverName}`.
   - Close button: `IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context))`.
4. **Summary KPI Banner**:
   - Three metrics separated by vertical dividers:
     - **Target**: `_currentTrip.ibtTargetTotal` (Color: `AppColors.primaryGlow`).
     - **Loaded**: `_currentTrip.ibtLoadedTotal` (Color: `Colors.greenAccent`).
     - **Remaining**: `(target - loaded).clamp(0, target)` (Color: `greenAccent` if 0, else `orangeAccent`).
5. **Documents List (`ListView.builder`)**:
   - For each `IbtDocument` in `_currentTrip.ibtDocuments`:
     - Container with border: `Colors.greenAccent` if `doc.isComplete`, else `white08` (or dynamic border).
     - **Document Header**: `doc.documentNo` (e.g. `IBT119512`), `doc.total` target, loaded badge, status tag (`Complete ✓` or `Remaining`).
     - **Line Items List**: List of `IbtLineItem` widgets.
6. **Line Item Row (`_buildLineItemRow`)**:
   - **Left Details**: Description text, tyre size pill (`line.size`), rubber compound tag (`line.rubber`), status badge (`Complete ✓`, `+N Over`, or `N left`).
   - **Right Steppers**:
     - Monospace count badge: `[ ${line.loadedQuantity} / ${line.targetTotal} ]`.
     - `-1` button (`Icons.remove`).
     - `+1` button (`Icons.add`, highlighted when `!isDone`).
     - `+5` quick button (`+5`).

### 2.4 Stepper Logic & ViewModel Interaction
```dart
void _onStepQuantity({
  required IbtDocument doc,
  required IbtLineItem line,
  required int delta,
}) async {
  AppHaptics.light();
  final newQty = (line.loadedQuantity + delta).clamp(0, 9999);

  final vm = context.read<LoadingSheetViewModel>();
  await vm.updateIbtLineQuantity(
    trip: _currentTrip,
    documentNo: doc.documentNo,
    lineItemId: line.id,
    newQuantity: newQty,
  );

  // Trigger medium haptic when quota is reached
  if (newQty == line.targetTotal && line.targetTotal > 0) {
    AppHaptics.medium();
  }

  // Refresh local trip state
  final trips = await vm.getTripsForSelectedDate();
  final updated = trips.firstWhere(
    (t) => t.id == _currentTrip.id,
    orElse: () => _currentTrip,
  );

  if (mounted) {
    setState(() {
      _currentTrip = updated;
    });
  }
}
```

### 2.5 Daylight Theme Adaptation for `IbtLineItemsSheet`
To support Daylight mode seamlessly:
- Wrap top container decoration with `GlassDecorations.glassElevated(context: context)`.
- Replace hardcoded `Colors.white` texts with `AppColors.dynamicTextPrimary(context)`.
- Replace hardcoded `Colors.white.withValues(alpha: 0.6)` with `AppColors.dynamicTextMuted(context)`.
- In line item rows, use `isLight ? const Color(0xFFF8FAFC) : Colors.black.withValues(alpha: 0.3)` for count badges.

---

## 3. Requirement R4: Screen-by-Screen Contrast & Surgical Grafting Guide

### 3.1 `flutter_app/lib/presentation/widgets/counter_panel.dart`

#### Comparison Analysis
| Feature / Area | `main` (Preserve!) | `origin/feature/ibt-manifest-tracking` | Grafting Action |
|---|---|---|---|
| **Constructor Props** | `trips`, `onChange`, `onAttachment` | `trips`, `onChange`, `onAttachment`, `currentTotal`, `targetTotal` | **Add** `currentTotal` (default 0) & `targetTotal` (`int?`) |
| **Overshoot Warning** | None | `_warnIfOver(context, count)` dialog | **Port** `_warnIfOver` logic & make dialog theme-aware |
| **`_logScanned()`** | Sync, logs without over-target prompt | Async, checks `_warnIfOver` before logging | **Adopt** async check + logging |
| **`_logManual()`** | Sync, logs without over-target prompt | Async, checks `_warnIfOver` before logging | **Adopt** async check + logging |
| **Component Height** | **40px** inputs/steppers, **42px** log button | 48px inputs/steppers, 48px log button | **KEEP MAIN's 40px/42px!** |
| **Padding & Radius** | **10px** padding, **16px** card radius | 12px padding, 22px card radius | **KEEP MAIN's 10px/16px!** |
| **Steppers & Auto-repeat** | Hold-to-repeat `_startRepeat`, `+1, +5, +10, +20, +50` | Basic single-tap stepper | **KEEP MAIN's repeat steppers!** |
| **Glass Decorator** | `GlassDecorations.glassElevated(borderRadius: 16)` | `GlassDecorations.glassElevated(borderRadius: 22)` | **KEEP MAIN's 16px radius** |

#### Exact Grafting Snippet for `counter_panel.dart`
```dart
// 1. Constructor parameters
class CounterPanel extends StatefulWidget {
  final List<Trip> trips;
  final Function(List<Trip>) onChange;
  final Function(Attachment)? onAttachment;
  final int currentTotal;
  final int? targetTotal;

  const CounterPanel({
    super.key,
    required this.trips,
    required this.onChange,
    this.onAttachment,
    this.currentTotal = 0,
    this.targetTotal,
  });
  ...
}

// 2. Overshoot Warning Dialog
Future<bool> _warnIfOver(BuildContext context, int adding) async {
  final target = widget.targetTotal;
  if (target == null || target <= 0) return true;
  final afterAdd = widget.currentTotal + adding;
  if (afterAdd <= target) return true;

  final over = afterAdd - target;
  final isLight = AppColors.isLight(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isLight ? Colors.white : AppColors.backgroundSecondary,
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Text(
            'Over IBT Target',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.dynamicTextPrimary(context),
            ),
          ),
        ],
      ),
      content: Text(
        'Adding $adding tyres will put you $over over the target of $target.\n\nAre you sure you want to continue?',
        style: TextStyle(fontSize: 13, color: AppColors.dynamicTextSecondary(context)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: TextStyle(color: AppColors.dynamicTextMuted(context))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
          child: Text(
            'Log +$over over anyway',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

// 3. Update _logScanned & _logManual
void _logScanned() async {
  if (_count <= 0) return;
  final ok = await _warnIfOver(context, _count);
  if (!ok) return;
  AppHaptics.success();
  final newTrip = Trip(
    id: IdGenerator.generate(),
    count: _count,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
  widget.onChange([...widget.trips, newTrip]);
  setState(() {
    _count = 0;
    _countController.text = '0';
  });
}

void _logManual({String? noteOverride}) async {
  if (_manualCount <= 0) return;
  final ok = await _warnIfOver(context, _manualCount);
  if (!ok) return;
  AppHaptics.success();
  final slip = _slipController.text.trim();
  final note = noteOverride ?? (slip.isNotEmpty ? 'slip:text:$slip' : null);
  final newTrip = Trip(
    id: IdGenerator.generate(),
    count: 0,
    rejected: _manualCount,
    note: note,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
  widget.onChange([...widget.trips, newTrip]);
  setState(() {
    _manualCount = 1;
    _countController.text = '1';
    _slipController.clear();
  });
}
```

---

### 3.2 `flutter_app/lib/presentation/screens/new_entry_screen.dart`

#### Comparison Analysis
| Feature / Area | `main` (Preserve!) | `origin/feature/ibt-manifest-tracking` | Grafting Action |
|---|---|---|---|
| **Route Presets** | Full preset selector (DBN, NLS, BLOEM, PLK, STOCKS, NLH, TIREPOINT, CUSTOM) | Presets exist, but STOCKS triggers IBT attachment card | **Keep** main's preset wrap & brand colors, trigger IBT card on `PresetKey.STOCKS` |
| **IBT Card Section** | Not present | Rendered when `_selectedPreset == PresetKey.STOCKS` | **Graft** IBT Card with AWS Auth button, IBT fetch input, and IBT document tag list |
| **AWS Auth Dialog** | Not present | `AwsAuthDialog.show(context)` invoked from header pill | **Graft** AWS Auth pill button |
| **IBT Fetch Action** | Not present | `_onFetchIbt()` with `AppSyncManifestService.fetchIbtDocument` | **Graft** `_onFetchIbt()` and error SnackBar |
| **Entry Creation Hook** | Creates simple entry | Creates entry + initial `LoadingSheetTrip` with `ibtDocuments` & `expectedTotal` | **Graft** initial trip creation & IBT target sync |
| **Daylight Theme** | `AppColors.dynamicTextPrimary(context)`, `GlassDecorations.glassCard(context: context)` | Hardcoded `Colors.white`, `Colors.black26` | **Themify** IBT card using main's daylight accessors |

#### Exact Grafting Placement for `new_entry_screen.dart`
1. **Add Imports**:
   ```dart
   import '../../core/utils/id_generator.dart';
   import '../../data/models/ibt_manifest.dart';
   import '../../data/models/loading_sheet_trip.dart';
   import '../../data/services/appsync_manifest_service.dart';
   import '../widgets/aws_auth_dialog.dart';
   ```
2. **Add State Variables**:
   ```dart
   final TextEditingController _ibtInputController = TextEditingController();
   final List<IbtDocument> _ibtDocuments = [];
   bool _isFetchingIbt = false;
   ```
3. **Add Fetch & Remove Methods**:
   ```dart
   Future<void> _onFetchIbt() async {
     final text = _ibtInputController.text.trim();
     if (text.isEmpty) return;
     AppHaptics.light();
     setState(() => _isFetchingIbt = true);
     try {
       final doc = await AppSyncManifestService.fetchIbtDocument(text);
       AppHaptics.medium();
       setState(() {
         final existingIdx = _ibtDocuments.indexWhere(
           (d) => d.documentNo.toUpperCase() == doc.documentNo.toUpperCase(),
         );
         if (existingIdx >= 0) {
           _ibtDocuments[existingIdx] = doc;
         } else {
           _ibtDocuments.add(doc);
         }
         _ibtInputController.clear();
       });
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Failed to fetch IBT: $e'),
             backgroundColor: AppColors.error,
             action: SnackBarAction(
               label: 'AWS Login',
               textColor: Colors.white,
               onPressed: () => AwsAuthDialog.show(context),
             ),
           ),
         );
       }
     } finally {
       if (mounted) setState(() => _isFetchingIbt = false);
     }
   }

   void _onRemoveIbt(String docNo) {
     AppHaptics.light();
     setState(() {
       _ibtDocuments.removeWhere(
         (d) => d.documentNo.toUpperCase() == docNo.toUpperCase(),
       );
     });
   }
   ```
4. **IBT Attachment UI (inside `build()` Column, directly after Presets Wrap)**:
   ```dart
   // Attach IBT Documents Section (Shown only for STOCKS preset)
   if (_selectedPreset == PresetKey.STOCKS) ...[
     Container(
       padding: const EdgeInsets.all(14),
       decoration: GlassDecorations.glassCard(context: context, borderRadius: 16),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Row(
                 children: [
                   Icon(
                     Icons.receipt_long_rounded,
                     color: isLight ? AppColors.primary : AppColors.primaryGlow,
                     size: 18,
                   ),
                   const SizedBox(width: 6),
                   Text(
                     'Attach IBT Documents (Stocks)',
                     style: TextStyle(
                       fontSize: 13,
                       fontWeight: FontWeight.bold,
                       color: AppColors.dynamicTextPrimary(context),
                     ),
                   ),
                 ],
               ),
               InkWell(
                 onTap: () => AwsAuthDialog.show(context),
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                   decoration: BoxDecoration(
                     color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: isLight ? 0.12 : 0.2),
                     borderRadius: BorderRadius.circular(6),
                   ),
                   child: Row(
                     children: [
                       Icon(
                         Icons.vpn_key_outlined,
                         size: 10,
                         color: isLight ? AppColors.primary : AppColors.primaryGlow,
                       ),
                       const SizedBox(width: 4),
                       Text(
                         'AWS Auth',
                         style: TextStyle(
                           fontSize: 10,
                           fontWeight: FontWeight.bold,
                           color: isLight ? AppColors.primary : AppColors.primaryGlow,
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ],
           ),
           const SizedBox(height: 10),
           Row(
             children: [
               Expanded(
                 child: Container(
                   height: 40,
                   decoration: BoxDecoration(
                     color: isLight ? const Color(0xFFF8FAFC) : Colors.black.withValues(alpha: 0.3),
                     borderRadius: BorderRadius.circular(10),
                     border: Border.all(
                       color: isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder,
                     ),
                   ),
                   padding: const EdgeInsets.symmetric(horizontal: 10),
                   child: Center(
                     child: TextField(
                       controller: _ibtInputController,
                       textCapitalization: TextCapitalization.characters,
                       style: TextStyle(
                         color: AppColors.dynamicTextPrimary(context),
                         fontSize: 13,
                         fontFamily: 'monospace',
                       ),
                       decoration: InputDecoration(
                         hintText: 'e.g. IBT119512 or 119512',
                         hintStyle: TextStyle(
                           color: AppColors.dynamicTextMuted(context),
                           fontSize: 12,
                         ),
                         border: InputBorder.none,
                         isDense: true,
                         contentPadding: EdgeInsets.zero,
                       ),
                       onSubmitted: (_) => _onFetchIbt(),
                     ),
                   ),
                 ),
               ),
               const SizedBox(width: 8),
               SizedBox(
                 height: 40,
                 child: ElevatedButton(
                   onPressed: _isFetchingIbt ? null : _onFetchIbt,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: isLight ? AppColors.primary : AppColors.primaryGlow,
                     foregroundColor: isLight ? Colors.white : Colors.black,
                     padding: const EdgeInsets.symmetric(horizontal: 12),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                   ),
                   child: _isFetchingIbt
                       ? const SizedBox(
                           width: 16,
                           height: 16,
                           child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                         )
                       : const Text(
                           'Fetch IBT',
                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                         ),
                 ),
               ),
             ],
           ),

           if (_ibtDocuments.isNotEmpty) ...[
             const SizedBox(height: 10),
             Wrap(
               spacing: 8,
               runSpacing: 8,
               children: _ibtDocuments.map((doc) {
                 return Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                   decoration: BoxDecoration(
                     color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: isLight ? 0.12 : 0.15),
                     borderRadius: BorderRadius.circular(8),
                     border: Border.all(
                       color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: 0.3),
                     ),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Text(
                         '${doc.documentNo} (${doc.total} tyres • ${doc.lineItems.length} lines)',
                         style: TextStyle(
                           color: AppColors.dynamicTextPrimary(context),
                           fontSize: 12,
                           fontWeight: FontWeight.w600,
                         ),
                       ),
                       const SizedBox(width: 6),
                       InkWell(
                         onTap: () => _onRemoveIbt(doc.documentNo),
                         child: Icon(
                           Icons.close,
                           size: 14,
                           color: AppColors.dynamicTextMuted(context),
                         ),
                       ),
                     ],
                   ),
                 );
               }).toList(),
             ),
           ],
         ],
       ),
     ),
     const SizedBox(height: 18),
   ],
   ```
5. **Update `_handleCreate`**:
   ```dart
   void _handleCreate() async {
     final title = _titleController.text.trim();
     if (title.isEmpty) return;

     AppHaptics.success();
     final vm = context.read<EntriesViewModel>();

     final isStocks = _selectedPreset == PresetKey.STOCKS;
     final totalIbtTyres = _ibtDocuments.fold<int>(0, (s, d) => s + d.total);

     LoadingSheetTrip? initialTrip;
     if (isStocks && _ibtDocuments.isNotEmpty) {
       final now = DateTime.now().millisecondsSinceEpoch;
       initialTrip = LoadingSheetTrip(
         id: IdGenerator.generate(),
         tripId: title,
         reg: '',
         driverName: '',
         presetKey: _selectedPreset,
         quantityLoaded: 0,
         targetQuantity: totalIbtTyres > 0 ? totalIbtTyres : null,
         startTime: now,
         createdAt: now,
         ibtDocuments: _ibtDocuments,
       );
     }

     final entry = await vm.createEntry(
       title: title,
       tags: _tags,
       withCounter: _withCounter,
       expectedTotal: (isStocks && totalIbtTyres > 0) ? totalIbtTyres : null,
     );

     if (initialTrip != null) {
       final updatedEntry = entry.copyWith(
         loadingSheetTrips: [
           initialTrip.copyWith(entryId: entry.id),
         ],
       );
       await vm.updateEntry(updatedEntry);
     }

     if (mounted) {
       Navigator.pushReplacement(
         context,
         MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: entry.id)),
       );
     }
   }
   ```

---

### 3.3 `flutter_app/lib/presentation/screens/entry_detail_screen.dart`

#### Comparison Analysis
| Feature / Area | `main` (Preserve!) | `origin/feature/ibt-manifest-tracking` | Grafting Action |
|---|---|---|---|
| **IBT Breakdown Card** | Not present | Rendered in scroll view when `hasIbt` is true | **Graft** IBT Card with document badges & `_IbtLineRow` items |
| **`_IbtLineRow` Widget** | Not present | Defines compact line item progress bar & quantities | **Graft** `_IbtLineRow` with Daylight Theme support |
| **Target Calculation** | Uses `entry.expectedTotal` | Computes `effectiveTarget = currentEntry.expectedTotal ?? ibtTarget` | **Adopt** `effectiveTarget` computation |
| **`CounterPanel` Props** | Passes `trips`, `onChange`, `onAttachment` | Passes `currentTotal: grandTotal, targetTotal: effectiveTarget` | **Pass** `currentTotal` & `targetTotal` |
| **Truck Assignment Card** | **Eliminated** from main scroll view (managed via bottom sheet) | Old bulky 210px card in scroll view | **DO NOT ADD OLD CARD! Keep Main's compact layout!** |
| **Photo Lightbox** | Caption editor (`allAttachments`, `onUpdateAttachment`) | Simple image view without captions | **KEEP MAIN's caption editor!** |
| **Saved Indicator** | `_isSaved` checkmark pill with 1400ms timer | Not present | **KEEP MAIN's saved indicator!** |

#### Exact Grafting Placement for `entry_detail_screen.dart`
1. **Add Import**:
   ```dart
   import '../../data/models/ibt_manifest.dart';
   ```
2. **Compute IBT Target in `build()`**:
   ```dart
   final sheetTrip = currentEntry.loadingSheetTrips?.firstWhere(
     (t) => !t.isManual,
     orElse: () => LoadingSheetTrip(
       id: '',
       entryId: '',
       reg: '',
       driverName: '',
       tripId: '',
       quantityLoaded: 0,
       createdAt: DateTime.now().millisecondsSinceEpoch,
     ),
   );
   final ibtDocs = sheetTrip?.ibtDocuments ?? [];
   final hasIbt = ibtDocs.isNotEmpty;

   final ibtTarget = hasIbt
       ? ibtDocs.fold<int>(0, (s, d) => s + d.total)
       : null;
   final effectiveTarget = currentEntry.expectedTotal ?? ibtTarget;
   ```
3. **Pass `effectiveTarget` to `CounterProgress` and `CounterPanel`**:
   ```dart
   CounterProgress(
     currentTotal: grandTotal,
     expectedTotal: effectiveTarget,
     truckReg: _regController.text.isNotEmpty ? _regController.text : null,
     driverName: _driverController.text.isNotEmpty ? _driverController.text : null,
     tripTitle: currentEntry.title,
     onSetExpected: (target) {
       final updatedSheetTrips = currentEntry.loadingSheetTrips?.map((st) {
         if (!st.isManual) {
           return st.copyWith(targetQuantity: target);
         }
         return st;
       }).toList();
       final updatedEntry = currentEntry.copyWith(
         expectedTotal: target,
         loadingSheetTrips: updatedSheetTrips,
       );
       setState(() => _cachedEntry = updatedEntry);
       repo.saveEntry(updatedEntry);
       _triggerSavedIndicator();
     },
     onUpdateTruckDetails: (reg, driver, target) {
       ...
     },
   ),
   const SizedBox(height: 10),
   CounterPanel(
     trips: trips,
     currentTotal: grandTotal,
     targetTotal: effectiveTarget,
     onChange: (nextTrips) { ... },
     onAttachment: (att) { ... },
   ),
   ```
4. **Insert IBT Manifest Breakdown in Scroll View (directly after `CounterPanel`)**:
   ```dart
   // IBT Manifest Breakdown
   if (hasIbt) ...[
     const SizedBox(height: 10),
     for (final doc in ibtDocs) ...[
       Container(
         margin: const EdgeInsets.only(bottom: 10),
         padding: const EdgeInsets.all(14),
         decoration: GlassDecorations.glassCard(context: context, borderRadius: 16),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               children: [
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                   decoration: BoxDecoration(
                     color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: isLight ? 0.12 : 0.15),
                     borderRadius: BorderRadius.circular(6),
                     border: Border.all(
                       color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: 0.3),
                     ),
                   ),
                   child: Text(
                     doc.documentNo,
                     style: TextStyle(
                       fontSize: 10,
                       fontWeight: FontWeight.w800,
                       color: isLight ? AppColors.primary : AppColors.primaryGlow,
                       fontFamily: 'monospace',
                     ),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Text(
                   '${doc.total} tyres total',
                   style: TextStyle(fontSize: 11, color: AppColors.dynamicTextMuted(context)),
                 ),
               ],
             ),
             const SizedBox(height: 10),
             for (final line in doc.lineItems) ...[
               _IbtLineRow(line: line, grandTotal: grandTotal, ibtTarget: doc.total),
               const SizedBox(height: 6),
             ],
           ],
         ),
       ),
     ],
     const SizedBox(height: 2),
   ],
   ```
5. **Append Theme-Aware `_IbtLineRow` Class**:
   ```dart
   class _IbtLineRow extends StatelessWidget {
     final IbtLineItem line;
     final int grandTotal;
     final int ibtTarget;

     const _IbtLineRow({
       required this.line,
       required this.grandTotal,
       required this.ibtTarget,
     });

     @override
     Widget build(BuildContext context) {
       final isLight = AppColors.isLight(context);
       final target = line.targetTotal;
       final loaded = line.loadedQuantity;
       final pct = target > 0 ? (loaded / target).clamp(0.0, 1.0) : 0.0;
       final isOver = loaded > target && target > 0;
       final isDone = target > 0 && loaded >= target;

       final Color barColor = isOver
           ? AppColors.warning
           : (isDone ? AppColors.success : (isLight ? AppColors.primary : AppColors.primaryGlow));

       return Row(
         children: [
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     if (line.size != null)
                       Text(
                         line.size!,
                         style: TextStyle(
                           fontSize: 11,
                           fontWeight: FontWeight.w700,
                           color: AppColors.dynamicTextPrimary(context),
                           fontFamily: 'monospace',
                         ),
                       ),
                     if (line.size != null && line.rubber != null)
                       Text(' · ', style: TextStyle(color: AppColors.dynamicTextMuted(context), fontSize: 11)),
                     if (line.rubber != null)
                       Text(
                         line.rubber!,
                         style: TextStyle(fontSize: 11, color: AppColors.dynamicTextSecondary(context)),
                       ),
                     if (line.size == null && line.rubber == null)
                       Expanded(
                         child: Text(
                           line.description,
                           style: TextStyle(fontSize: 10, color: AppColors.dynamicTextSecondary(context)),
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                   ],
                 ),
                 const SizedBox(height: 4),
                 ClipRRect(
                   borderRadius: BorderRadius.circular(4),
                   child: LinearProgressIndicator(
                     value: pct,
                     minHeight: 5,
                     backgroundColor: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.07),
                     valueColor: AlwaysStoppedAnimation<Color>(barColor),
                   ),
                 ),
               ],
             ),
           ),
           const SizedBox(width: 12),
           Text(
             '$loaded / $target',
             style: TextStyle(
               fontSize: 12,
               fontWeight: FontWeight.w800,
               color: isOver
                   ? AppColors.warning
                   : (isDone ? AppColors.success : AppColors.dynamicTextPrimary(context)),
               fontFamily: 'monospace',
             ),
           ),
         ],
       );
     }
   }
   ```

---

### 3.4 `flutter_app/lib/presentation/screens/loading_sheet_screen.dart`

#### Comparison Analysis
| Feature / Area | `main` (Preserve!) | `origin/feature/ibt-manifest-tracking` | Grafting Action |
|---|---|---|---|
| **Header AWS Sync** | Not present | AWS Sync pill button beside Despatcher Name | **Graft** AWS Sync button with `AwsAuthDialog.show(context)` |
| **IBT Card Summary** | Not present | Summary chip with `Breakdown` button launching `IbtLineItemsSheet` | **Graft** IBT chip into `_buildTruckCard()` |
| **PDF Export** | `PdfPreviewScreen.openLoadingSheet(...)` | Direct `PdfExportService.sharePdf(...)` | **KEEP MAIN's `PdfPreviewScreen`!** |
| **Daylight Sunlight Mode** | Rich blue gradients (`Color(0xFFEFF6FF)`), crisp Slate borders | Hardcoded dark background | **KEEP MAIN's Daylight Sunlight Mode!** |

#### Exact Grafting Placement for `loading_sheet_screen.dart`
1. **Add Imports**:
   ```dart
   import '../widgets/aws_auth_dialog.dart';
   import '../widgets/ibt_line_items_sheet.dart';
   ```
2. **Add AWS Sync Button to Header**:
   ```dart
   Row(
     children: [
       GestureDetector(
         onTap: () => AwsAuthDialog.show(context),
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
           decoration: GlassDecorations.glassCard(context: context, borderRadius: 14),
           child: Row(
             children: [
               Icon(
                 Icons.cloud_sync_rounded,
                 size: 14,
                 color: isLight ? AppColors.primary : AppColors.primaryGlow,
               ),
               const SizedBox(width: 4),
               Text(
                 'AWS Sync',
                 style: TextStyle(
                   fontSize: 11,
                   fontWeight: FontWeight.bold,
                   color: AppColors.dynamicTextPrimary(context),
                 ),
               ),
             ],
           ),
         ),
       ),
       const SizedBox(width: 6),
       // Despatcher Name Pill
       GestureDetector(
         onTap: () {
           _showEditDespatcherDialog(context, settingsRepo);
         },
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
           decoration: GlassDecorations.glassCard(context: context, borderRadius: 14),
           child: Row(
             children: [
               Icon(
                 Icons.person_rounded,
                 size: 14,
                 color: isLight ? AppColors.primary : AppColors.primaryGlow,
               ),
               const SizedBox(width: 4),
               Text(
                 despatcherName,
                 style: TextStyle(
                   fontSize: 12,
                   fontWeight: FontWeight.bold,
                   color: AppColors.dynamicTextPrimary(context),
                 ),
               ),
             ],
           ),
         ),
       ),
     ],
   ),
   ```
3. **Add IBT Document Summary Chip inside `_buildTruckCard`**:
   ```dart
   if (trip.hasIbtDocuments) ...[
     const SizedBox(height: 8),
     Container(
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
       decoration: BoxDecoration(
         color: isLight ? const Color(0xFFF1F5F9) : AppColors.glassSurfaceElevated,
         borderRadius: BorderRadius.circular(8),
         border: Border.all(
           color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: isLight ? 0.35 : 0.25),
         ),
       ),
       child: Row(
         children: [
           Icon(
             Icons.receipt_long_outlined,
             size: 13,
             color: isLight ? AppColors.primary : AppColors.primaryGlow,
           ),
           const SizedBox(width: 6),
           Expanded(
             child: Text(
               trip.ibtDocuments!.map((d) => '${d.documentNo} (${d.loadedTotal}/${d.total})').join(' • '),
               style: TextStyle(
                 fontSize: 11,
                 fontWeight: FontWeight.w600,
                 color: AppColors.dynamicTextPrimary(context),
               ),
               overflow: TextOverflow.ellipsis,
             ),
           ),
           InkWell(
             onTap: () {
               AppHaptics.medium();
               IbtLineItemsSheet.show(context, trip: trip);
             },
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
               decoration: BoxDecoration(
                 color: (isLight ? AppColors.primary : AppColors.primaryGlow).withValues(alpha: isLight ? 0.15 : 0.2),
                 borderRadius: BorderRadius.circular(4),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(
                     'Breakdown',
                     style: TextStyle(
                       fontSize: 10,
                       fontWeight: FontWeight.bold,
                       color: isLight ? AppColors.primary : AppColors.primaryGlow,
                     ),
                   ),
                   Icon(
                     Icons.chevron_right,
                     size: 12,
                     color: isLight ? AppColors.primary : AppColors.primaryGlow,
                   ),
                 ],
               ),
             ),
           ),
         ],
       ),
     ),
   ],
   ```

---

## 4. Main's Daylight Theme & Layout Preservation Rules

### 4.1 Theme Token Reference
| Semantic Role | Dark Value | Daylight Value (`AppColors.isLight(context) == true`) |
|---|---|---|
| Scaffold Background | `AppColors.background` (`0xFF0B0F17`) | `AppColors.lightBackground` (`0xFFF1F5F9` Slate 100) |
| Primary Accent | `AppColors.primaryGlow` (`0xFF60A5FA`) | `AppColors.primary` (`0xFF1D4ED8` Deep Blue 700) |
| Card Surface | `AppColors.glassSurface` (`0xCC131C2E`) | `Colors.white` |
| Elevated Surface | `AppColors.glassSurfaceElevated` (`0xE61A253C`) | `Color(0xFFF1F5F9)` / `Colors.white` |
| Borders | `AppColors.glassBorder` (`0x1FFFFFFF`) | `Color(0xFFCBD5E1)` (Slate 300) |
| Primary Text | `AppColors.textPrimary` (`0xFFF8FAFC`) | `AppColors.lightTextPrimary` (`0xFF0F172A` Deep Slate 900) |
| Secondary Text | `AppColors.textSecondary` (`0xFF94A3B8`) | `AppColors.lightTextSecondary` (`0xFF334155` Slate 700) |
| Muted Text | `AppColors.textMuted` (`0xFF64748B`) | `AppColors.lightTextMuted` (`0xFF64748B` Slate 500) |

### 4.2 Preservation Checklist for Implementation
- [x] **Rule 1: Always provide `context: context` to `GlassDecorations` methods** (`glassCard`, `glassElevated`, `glassDock`).
- [x] **Rule 2: Never hardcode `Colors.white` or `AppColors.textPrimary` in text widgets without checking `isLight`**; use `AppColors.dynamicTextPrimary(context)`, `AppColors.dynamicTextSecondary(context)`, `AppColors.dynamicTextMuted(context)`.
- [x] **Rule 3: Keep compact widget sizing**: 40px component heights for counter inputs and stepper buttons, 10px paddings, 16px corner radii.
- [x] **Rule 4: Retain main's PDF preview modal**: Never replace `PdfPreviewScreen.openLoadingSheet(...)` with raw `PdfExportService.sharePdf(...)`.
- [x] **Rule 5: Retain main's interactive photo captions**: Keep `allAttachments` and `onUpdateAttachment` in `PhotoLightbox.show(...)`.
- [x] **Rule 6: Retain main's hold-to-repeat steppers**: Keep `_startRepeat` and `_stopRepeat` on the quick add buttons (`+1`, `+5`, `+10`, `+20`, `+50`).
- [x] **Rule 7: Retain main's optimistic state updates**: Keep `_cachedEntry` and `_triggerSavedIndicator()` in `EntryDetailScreen`.

---

## 5. Verification & Testing Matrix

| Component / Target | Test Scenario | Expected Outcome |
|---|---|---|
| `IbtLineItemsSheet` | Tap "Breakdown" on an IBT-linked trip | Modal opens showing target/loaded KPI cards, line item cards, and steppers |
| `IbtLineItemsSheet` Steppers | Tap `+1` or `+5` on a line item | Line item loaded count increments, updates `LoadingSheetTrip`, and refreshes sheet |
| `CounterPanel` Over Target | Increment count past `targetTotal` and tap "LOG SCANNED" | Warning dialog "Over IBT Target" appears with cancel / log anyway options |
| `NewEntryScreen` Preset | Select `STOCKS` preset | IBT Document attachment card appears with "AWS Auth" button and IBT fetch field |
| `NewEntryScreen` IBT Fetch | Enter valid IBT (e.g. `IBT119512`) & tap "Fetch IBT" | IBT Document tag chip renders with tyre count and line item count |
| `EntryDetailScreen` IBT Section | Open an entry with IBT documents attached | "IBT Manifest Breakdown" card renders line item progress bars |
| `LoadingSheetScreen` AWS Sync | Tap "AWS Sync" button in header | `AwsAuthDialog` opens with Cognito login status |
| Daylight Mode Verification | Toggle theme to Light mode across all screens | All IBT cards, sheets, text, and dialogs render with high-contrast Slate & Deep Blue styles |
| Flutter Tests | Run `flutter test` | All existing unit and widget tests pass with 0 regressions |
| Dart Static Analysis | Run `dart analyze` | Reports 0 warnings, 0 errors |

---
