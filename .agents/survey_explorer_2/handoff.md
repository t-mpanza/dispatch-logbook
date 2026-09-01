# UI Survey & Surgical Grafting Analysis Report

## 1. Observation

### Codebase Differences and Branch Topology
- Merge Base between `main` (commit `26047b8`) and `origin/feature/ibt-manifest-tracking` (commit `2efb499`):
  `a28e1fae80bf4b829c10d0bcf6eb55cd67751f8e`.
- `main` includes major theme & UX enhancements:
  - Commit `fc21987`: Rich daylight mode rendering (`AppColors.isLight`, `dynamicTextPrimary`, `dynamicBackground`, `dynamicBorder`), target tyres bidirectional sync, over-count fix, and card progress indicators.
  - Commit `9031746`: Real-time target tyres auto-updating & full-fidelity daylight theme rendering across all screens.
  - Commit `a00f273`: In-app PDF preview (`PdfPreviewScreen`), high-visibility daylight sunlight mode, and premium media controls suite.
  - Commit `993d545`: Hold-to-repeat target stepper and quick increment pills (`+1`, `+5`, `+10`, `+20`, `+50`) with auto-repeat.
  - Commit `439b232`: Compact high-density counter layout (`counter_panel.dart` height reductions from 48px to 40px) and elimination of redundant truck assignment card saving 210px screen space.
  - Commit `37c58dd`: Multi-place ThemeToggle & 3-way theme switcher, swipe-to-exit photo lightbox, collapsed archives by default, and floating voice recorder UI.
- `feature/ibt-manifest-tracking` contains the complete AWS AppSync and IBT Manifest tracking subsystem implemented against the older v2.0.47 codebase.

---

### Component-by-Component Survey

#### A. New UI Components to Port (Brand New Files)

1. **`lib/presentation/screens/aws_login_webview_screen.dart`**
   - **Origin**: `origin/feature/ibt-manifest-tracking:flutter_app/lib/presentation/screens/aws_login_webview_screen.dart` (230 lines).
   - **Purpose**: Full-screen WebView implementing AWS Cognito Hosted UI / Microsoft SSO OAuth login flow.
   - **Key Mechanics**:
     - Preconfigured OAuth URL with `client_id=78ikblrgsr8h27197iovkgrro6`, `response_type=code`, `scope=email+openid+aws.cognito.signin.user.admin`, `redirect_uri=myapp://`.
     - Custom Android User Agent (`Mozilla/5.0 (Linux; Android 14; Pixel 8)... Mobile Safari/537.36`) to bypass Google/Cognito embedded WebView restrictions.
     - `NavigationDelegate` intercepting `myapp://` redirect URIs and extracting auth code.
     - Calls `AppSyncManifestService.handleRedirectUrl(url)` to exchange code for tokens and store in secure storage.
     - Pops with `true` on successful auth; shows error banner with retry on failure.
   - **Grafting Strategy**: Port verbatim. Integrate `AppColors.dynamicBackground(context)` and `AppColors.dynamicTextPrimary(context)` if customized app bar styling is desired.

2. **`lib/presentation/widgets/aws_auth_dialog.dart`**
   - **Origin**: `origin/feature/ibt-manifest-tracking:flutter_app/lib/presentation/widgets/aws_auth_dialog.dart` (620 lines).
   - **Purpose**: Modal bottom sheet for managing AWS AppSync credentials and authentication methods.
   - **Key Mechanics**:
     - `AwsAuthDialog.show(BuildContext context)` entry point.
     - Real-time Connection Status Card showing connection status (green connected / red not authenticated), active email/username, session expiration timestamp, and log out button.
     - Primary button: "Sign In with AWS Web Login (SSO)" launching `AwsLoginWebViewScreen.push(context)`.
     - 2 Tabs for advanced auth:
       1. Tab 1: Direct Login (`_usernameController`, `_passwordController`) calling `AppSyncManifestService.loginWithCredentials`.
       2. Tab 2: Direct Token / SSO (`_idTokenController`, `_refreshTokenController`, `_openHostedUI()`) calling `AppSyncManifestService.saveAuthTokens`.
     - Live AppSync GraphQL Query Connection tester (`AppSyncManifestService.testConnection()`).
   - **Grafting Strategy**: Port file, but update styling to support `AppColors.isLight(context)` for Daylight theme compatibility (replace hardcoded dark backgrounds/text colors with dynamic theme accessors).

3. **`lib/presentation/widgets/ibt_line_items_sheet.dart`**
   - **Origin**: `origin/feature/ibt-manifest-tracking:flutter_app/lib/presentation/widgets/ibt_line_items_sheet.dart` (539 lines).
   - **Purpose**: Modal bottom sheet for viewing and stepping individual IBT manifest line items per document on a trip.
   - **Key Mechanics**:
     - `IbtLineItemsSheet.show(BuildContext context, {required LoadingSheetTrip trip})` entry point.
     - KPI Summary Bar (Target, Loaded, Remaining).
     - Document header with document number and loaded/total status.
     - Line item rows showing description, tyre size pill, rubber compound pill, completion badge (`Complete ✓`, `+N Over`, `N left`).
     - Stepper controls: Mono-spaced `[loaded / target]`, `-1`, `+1` (highlighted if incomplete), and `+5` quick-step buttons.
     - Invokes `vm.updateIbtLineQuantity(trip: _currentTrip, documentNo: doc.documentNo, lineItemId: line.id, newQuantity: newQty)`.
     - Haptic feedback on tap (`AppHaptics.light()`) and on quota completion (`AppHaptics.medium()`).
   - **Grafting Strategy**: Port file, ensure `GlassDecorations.glassElevated(context: context)` is passed `context` and text/containers adapt to daylight mode.

---

#### B. Existing UI Screens Needing Surgical Grafting

1. **`lib/presentation/widgets/counter_panel.dart`**
   - **Existing on `main`**:
     - Compact high-density layout: 40px height buttons, 10-12px border radius, 10px container padding.
     - Full Daylight mode support.
     - Fast auto-repeat hold timers on steppers and quick adds (`_startRepeat`, `_stopRepeat`).
     - Monospace numeric input with direct typing support.
   - **Feature Branch Logic to Graft**:
     - Constructor parameters: `final int currentTotal;` (default 0), `final int? targetTotal;`.
     - Overshoot Warning Dialog:
       ```dart
       Future<bool> _warnIfOver(BuildContext context, int adding) async {
         final target = widget.targetTotal;
         if (target == null || target <= 0) return true;
         final afterAdd = widget.currentTotal + adding;
         if (afterAdd <= target) return true;

         final over = afterAdd - target;
         final confirmed = await showDialog<bool>(
           context: context,
           builder: (ctx) => AlertDialog(
             backgroundColor: AppColors.isLight(context) ? Colors.white : AppColors.backgroundSecondary,
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
                 child: Text('Log +$over over anyway', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
               ),
             ],
           ),
         );
         return confirmed == true;
       }
       ```
     - Guard `_logScanned()` and `_logManual()` with `final ok = await _warnIfOver(context, count); if (!ok) return;`.
   - **DO NOT OVERWRITE on `main`**:
     - Do NOT increase widget sizing back to 48px or border radius to 16/22px (which wastes screen space and was explicitly refactored in commit `439b232`).
     - Do NOT remove daylight theme colors or replace `GlassDecorations.glassElevated`.

2. **`lib/presentation/screens/new_entry_screen.dart`**
   - **Existing on `main`**:
     - Route presets selector (`DBN`, `NLS`, `BLOEM`, `PLK`, `STOCKS`, `NLH`, `TIREPOINT`, `CUSTOM`) with animated active color chips.
     - Auto-naming and auto-tagging.
     - TagsInput, With-Counter toggle, Daylight theme styling.
   - **Feature Branch Logic to Graft**:
     - Add `_ibtInputController = TextEditingController()`, `List<IbtDocument> _ibtDocuments = []`, `bool _isFetchingIbt = false`.
     - Add `_onFetchIbt()` (fetches doc from `AppSyncManifestService.fetchIbtDocument(text)` and attaches to `_ibtDocuments`) and `_onRemoveIbt(docNo)`.
     - In `_handleCreate()`:
       - If `_selectedPreset == PresetKey.STOCKS && _ibtDocuments.isNotEmpty`:
         - Calculate `totalIbtTyres = _ibtDocuments.fold<int>(0, (s, d) => s + d.total)`.
         - Create initial `LoadingSheetTrip(ibtDocuments: _ibtDocuments, targetQuantity: totalIbtTyres, ...)`.
         - Call `vm.createEntry(..., expectedTotal: totalIbtTyres)`.
         - Save entry with initial `loadingSheetTrips: [initialTrip.copyWith(entryId: entry.id)]`.
     - In `build()`:
       - If `_selectedPreset == PresetKey.STOCKS`:
         - Render "Attach IBT Documents (Stocks)" section with:
           - Header with "AWS Auth" button triggering `AwsAuthDialog.show(context)`.
           - Monospaced IBT number TextField (`e.g. IBT119512 or 119512`) + "Fetch IBT" button.
           - Attached IBT chips with tyre count, line count, and remove icon.
   - **DO NOT OVERWRITE on `main`**:
     - Do NOT overwrite `main`'s daylight color handling (`AppColors.dynamicTextPrimary(context)`, `AppColors.dynamicBackground(context)`).
     - Do NOT break `PresetEngine` auto-increment logic (`PresetEngine.getNextStocksTripId`).

3. **`lib/presentation/screens/entry_detail_screen.dart`**
   - **Existing on `main`**:
     - Smooth saved indicator (`_isSaved`, `_triggerSavedIndicator()`).
     - Local entry cache `_cachedEntry` preventing UI jumpiness on rapid edits.
     - `CounterProgress` bidirectional sync and truck assignment editing (eliminated separate redundant 210px truck card).
     - Light/Daylight mode support across top bar, event log, lightbox.
     - Rich photo captions in `PhotoLightbox.show(context, att, allAttachments: ..., onUpdateAttachment: ...)`.
   - **Feature Branch Logic to Graft**:
     - Extract IBT manifest data from non-manual loading sheet trip:
       ```dart
       final sheetTrip = currentEntry.loadingSheetTrips?.firstWhere(
         (t) => !t.isManual,
         orElse: () => LoadingSheetTrip(
           id: '', entryId: '', reg: '', driverName: '',
           tripId: '', quantityLoaded: 0,
           createdAt: DateTime.now().millisecondsSinceEpoch,
         ),
       );
       final ibtDocs = sheetTrip?.ibtDocuments ?? [];
       final hasIbt = ibtDocs.isNotEmpty;
       final ibtTarget = sheetTrip?.ibtTargetTotal ?? 0;
       final effectiveTarget = currentEntry.expectedTotal ?? (ibtTarget > 0 ? ibtTarget : null);
       ```
     - Pass `expectedTotal: effectiveTarget` to `CounterProgress`.
     - Pass `currentTotal: grandTotal` and `targetTotal: effectiveTarget` to `CounterPanel`.
     - Render IBT Manifest Breakdown card when `hasIbt`:
       - Card per IBT document displaying document number badge, tyre count, and line items.
     - Add `_IbtLineRow` widget with size, rubber compound, progress bar, and `$loaded / $target` counter.
     - Ensure `_IbtLineRow` respects `AppColors.dynamicTextPrimary(context)` and `AppColors.dynamicTextMuted(context)`.
   - **DO NOT OVERWRITE on `main`**:
     - Do NOT re-add the old redundant 210px "TRUCK ASSIGNMENT" card that was deleted in commit `439b232`.
     - Do NOT remove `_cachedEntry` or `_isSaved` indicator.
     - Do NOT revert `PhotoLightbox.show` to the single-argument version.

4. **`lib/presentation/screens/loading_sheet_screen.dart`**
   - **Existing on `main`**:
     - Daylight & Sunlight mode rendering (light backgrounds, blue borders, slate text).
     - In-app PDF preview (`PdfPreviewScreen.openLoadingSheet(...)`).
     - Despatcher name dialog and pill.
     - Trip row styling and date navigation.
   - **Feature Branch Logic to Graft**:
     - Header: Add "AWS Sync" button next to Despatcher Name pill that opens `AwsAuthDialog.show(context)`.
     - Trip Card (`_buildTripRow`): If `trip.hasIbtDocuments`:
       - Render IBT chip container with document numbers, loaded/target totals, and "Breakdown" button opening `IbtLineItemsSheet.show(context, trip: trip)`.
     - Make sure the IBT chip container and "Breakdown" button use daylight-compatible colors (`isLight ? AppColors.primary : AppColors.primaryGlow`, light surface colors).
   - **DO NOT OVERWRITE on `main`**:
     - Do NOT remove `PdfPreviewScreen` in-app preview support.
     - Do NOT strip `isLight` and daylight gradient/surface decorations.

5. **`lib/presentation/widgets/truck_load_dialog.dart`**
   - **Existing on `main`**:
     - Hold-to-repeat target stepper and quick increment pills (+1, +5, +10, +20, +50).
     - Daylight mode support.
   - **Feature Branch Logic to Graft**:
     - Support `_ibtDocuments` attachment when `_selectedPreset == PresetKey.STOCKS`.
     - Add `_ibtInputController`, `_onFetchIbt()`, `_onRemoveIbt()`, and IBT input UI section with chips.
     - In `_handleSave()`, set `ibtDocuments: _ibtDocuments` and auto-fill `targetQuantity` from IBT total if not manually overridden.

---

## 2. Logic Chain

1. **Isolation of Styling vs Business Logic**:
   - `main` branch holds the latest design system refinements (v2.0.48 - v2.0.64) including Daylight Theme, compact sizing (40px steppers), in-app PDF preview, and hold-to-repeat timers.
   - `feature/ibt-manifest-tracking` holds the IBT data models, AppSync client, Cognito OAuth webview, and IBT line breakdown sheet.
   - Conclusion: Every UI integration must port ONLY the business logic, state connections, dialog triggers, and IBT breakdown widgets, while adopting `main`'s color tokens (`AppColors.dynamic*`), `GlassDecorations`, and compact layout constraints.

2. **Clean State Propagation Call Graph**:
   ```
   [AwsLoginWebViewScreen] / [AwsAuthDialog]
          │ (stores Cognito tokens in secure storage)
          ▼
   [AppSyncManifestService] ◄─── (fetches IBT manifests via GraphQL)
          │
          ├─────────────────────────┬───────────────────────────────┐
          ▼                         ▼                               ▼
   [NewEntryScreen]          [TruckLoadDialog]               [LoadingSheetScreen]
    (attaches IBTs)           (attaches IBTs)                 (AWS Sync button &
          │                         │                          Breakdown button)
          ▼                         ▼                               │
   [LoadingSheetTrip.ibtDocuments]                                  │
          │                                                         │
          ├─────────────────────────┐                               │
          ▼                         ▼                               ▼
   [EntryDetailScreen]       [CounterPanel]               [IbtLineItemsSheet]
    (IBT manifest card        (overshoot warning           (stepper increments &
     & line rows)              dialog)                      vm.updateIbtLineQuantity)
   ```

3. **Theme Preservation**:
   - All newly ported UI (`AwsAuthDialog`, `IbtLineItemsSheet`, `_IbtLineRow`, IBT input sections) must check `AppColors.isLight(context)` or use `AppColors.dynamicTextPrimary(context)`, `AppColors.dynamicBorder(context)`, `AppColors.dynamicBackground(context)`.
   - This ensures zero visual regression when switching between Dark mode, Daylight mode, and Sunlight high-visibility mode.

---

## 3. Caveats

- **Network Mode & Credentials**: Live GraphQL testing via `AppSyncManifestService.testConnection()` requires valid Cognito tokens; offline unit tests with mock payloads should be used during CI/CD.
- **`webview_flutter` Native Setup**: On Android, WebView requires internet permission (already present in `AndroidManifest.xml`).
- **Data Model Dependency**: UI grafting depends on `IbtDocument`, `IbtLineItem`, `LoadingSheetTrip.ibtDocuments`, `AppSyncManifestService`, and `LoadingSheetViewModel.updateIbtLineQuantity`. Those model/service files must be in place before or alongside UI grafting.

---

## 4. Conclusion

The surgical grafting of the IBT subsystem UI is completely mapped and scoped:
1. **3 New UI Files to Port**:
   - `flutter_app/lib/presentation/screens/aws_login_webview_screen.dart`
   - `flutter_app/lib/presentation/widgets/aws_auth_dialog.dart` (enhanced with Daylight theme support)
   - `flutter_app/lib/presentation/widgets/ibt_line_items_sheet.dart` (enhanced with Daylight theme support)
2. **4 Existing UI Files to Surgically Graft**:
   - `flutter_app/lib/presentation/widgets/counter_panel.dart` (add `currentTotal`/`targetTotal` and `_warnIfOver`, preserving 40px compact sizing)
   - `flutter_app/lib/presentation/screens/new_entry_screen.dart` (add STOCKS IBT fetch/attach section and pre-fill expectedTotal)
   - `flutter_app/lib/presentation/screens/entry_detail_screen.dart` (add IBT manifest breakdown card, `_IbtLineRow`, pass target to CounterPanel, preserve `_cachedEntry` and `_isSaved`)
   - `flutter_app/lib/presentation/screens/loading_sheet_screen.dart` (add AWS Sync header button and trip IBT breakdown trigger, preserving `PdfPreviewScreen` and daylight theme)
3. **1 Auxiliary Dialog to Graft**:
   - `flutter_app/lib/presentation/widgets/truck_load_dialog.dart` (add STOCKS IBT fetch/attach section)

---

## 5. Verification Method

To verify the surgical UI grafting once implemented:
1. Run static analysis:
   ```bash
   cd flutter_app && dart analyze
   ```
   (Must report 0 issues/errors).
2. Run automated test suite:
   ```bash
   cd flutter_app && flutter test
   ```
   (Must pass all existing and new IBT unit/widget tests).
3. Invalidation conditions:
   - Any layout regressions in Daylight mode (e.g. white text on white background in IBT sheets or dialogs).
   - Any screen space overflow in `CounterPanel` (must maintain compact 40px buttons).
   - Any missing IBT breakdown buttons on `LoadingSheetScreen` or `EntryDetailScreen`.
