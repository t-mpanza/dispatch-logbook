# Handoff Report: Explorer Survey 2 (R3 & R4 UI Integration)

## 1. Observation
1. **Branch Divergence Point**: Both `main` (commit `26047b8`) and `origin/feature/ibt-manifest-tracking` (commit `2efb499`) diverged from commit `a28e1fa` (tag `v2.0.47`).
2. **`main` Specific Enhancements**:
   - `flutter_app/lib/core/theme/app_colors.dart`: Added light theme tokens (`lightBackground: 0xFFF1F5F9`, `lightTextPrimary: 0xFF0F172A`, `lightTextSecondary: 0xFF334155`, etc.) and dynamic helper methods (`isLight(context)`, `dynamicBackground(context)`, `dynamicCardSurface(context)`, `dynamicTextPrimary(context)`).
   - `flutter_app/lib/core/theme/glass_decorations.dart`: Updated `glassCard`, `glassElevated`, `glassDock` to take `BuildContext? context` and render Slate borders (`#CBD5E1`) and clean shadows when `isLight` is true.
   - `flutter_app/lib/presentation/widgets/counter_panel.dart`: High-density compact layout with 40px component heights, 10px container padding, 16px corner radii, hold-to-repeat steppers (`_startRepeat`), and quick increment pills (`+1`, `+5`, `+10`, `+20`, `+50`).
   - `flutter_app/lib/presentation/screens/entry_detail_screen.dart`: Removed bulky 210px truck assignment card from main scroll view; added `_cachedEntry` state variable, `_isSaved` auto-save pill timer, and interactive photo caption editor in `PhotoLightbox.show(context, att, allAttachments: ..., onUpdateAttachment: ...)`.
   - `flutter_app/lib/presentation/screens/loading_sheet_screen.dart`: Rich daylight gradient KPI banner (`LinearGradient([Color(0xFFEFF6FF), Color(0xFFEEF2FF)])`), Slate borders (`#BFDBFE`), and in-app PDF preview modal via `PdfPreviewScreen.openLoadingSheet(...)`.
3. **`origin/feature/ibt-manifest-tracking` IBT Specific Additions**:
   - `flutter_app/lib/presentation/widgets/ibt_line_items_sheet.dart` (539 lines): Modal bottom sheet with drag handle, summary KPI card (Target, Loaded, Remaining), document cards, and per-line steppers (`-1`, `+1`, `+5`) calling `LoadingSheetViewModel.updateIbtLineQuantity(...)`.
   - `flutter_app/lib/presentation/widgets/counter_panel.dart`: Added `currentTotal` (default 0) and `targetTotal` (`int?`) props; `_warnIfOver` validation dialog triggering when adding tyres exceeds target; async `_logScanned()` and `_logManual()`.
   - `flutter_app/lib/presentation/screens/new_entry_screen.dart`: Attached IBT document card when `_selectedPreset == PresetKey.STOCKS`, AWS Auth button (`AwsAuthDialog.show(context)`), `_onFetchIbt()` querying `AppSyncManifestService.fetchIbtDocument`, IBT document chips with remove actions, and initial `LoadingSheetTrip` creation with `ibtDocuments` in `_handleCreate()`.
   - `flutter_app/lib/presentation/screens/entry_detail_screen.dart`: Calculates `effectiveTarget = currentEntry.expectedTotal ?? ibtTarget`, passes `targetTotal` to `CounterPanel` and `CounterProgress`, and renders IBT breakdown cards with `_IbtLineRow` in the timeline scroll view.
   - `flutter_app/lib/presentation/screens/loading_sheet_screen.dart`: Added "AWS Sync" button in the header triggering `AwsAuthDialog.show(context)`, and added IBT document status chip with "Breakdown" button launching `IbtLineItemsSheet.show(context, trip: trip)` in `_buildTruckCard()`.

## 2. Logic Chain
1. **Fact**: Blindly copying or merging files from `origin/feature/ibt-manifest-tracking` will overwrite `main`'s 11 subsequent commits, breaking daylight theme rendering, compact layout density, hold-to-repeat steppers, photo caption editing, and PDF previews.
2. **Inference**: All UI additions from the feature branch must be grafted surgically and made daylight-theme-compatible using `AppColors.dynamic*` and `GlassDecorations.*(context: context)`.
3. **Inference**: For `counter_panel.dart`, only `currentTotal`, `targetTotal`, `_warnIfOver`, and async confirmation in `_logScanned`/`_logManual` should be grafted. The 40px heights, 10px paddings, 16px radii, and repeat steppers from `main` must remain intact.
4. **Inference**: For `new_entry_screen.dart`, the IBT attachment section must be isolated inside `if (_selectedPreset == PresetKey.STOCKS)` and styled using `GlassDecorations.glassCard(context: context)`.
5. **Inference**: For `entry_detail_screen.dart`, `hasIbt` and `_IbtLineRow` breakdown cards should be grafted into the scroll view, while keeping main's `_cachedEntry`, `_triggerSavedIndicator()`, `PhotoLightbox` caption editing, and avoiding the old bulky truck card.
6. **Inference**: For `loading_sheet_screen.dart`, grafting the "AWS Sync" header button and `_buildTruckCard` IBT chip must retain `PdfPreviewScreen.openLoadingSheet(...)` and daylight KPI gradients.

## 3. Caveats
- No changes were made directly to application source code during this turn (strictly read-only investigation).
- `IbtLineItemsSheet` depends on `LoadingSheetViewModel.updateIbtLineQuantity(...)`, which is part of Requirement R1 data models and viewmodels. Ensure R1 is implemented prior to R3/R4 integration.
- Ensure `AwsAuthDialog` and `AppSyncManifestService` are imported correctly where referenced.

## 4. Conclusion
A complete, surgical UI grafting plan has been established and fully documented in `.agents/explorer_survey_2/survey_report.md`.
All state variables, callbacks, layout parameters, and Daylight theme preservation rules have been specified with exact code snippets for the implementer agent.

## 5. Verification Method
1. Inspect report:
   ```bash
   cat "/home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_survey_2/survey_report.md"
   ```
2. Verify git diff between main and feature branch for target UI files:
   ```bash
   git diff origin/main origin/feature/ibt-manifest-tracking -- flutter_app/lib/presentation/widgets/counter_panel.dart
   git diff origin/main origin/feature/ibt-manifest-tracking -- flutter_app/lib/presentation/screens/new_entry_screen.dart
   git diff origin/main origin/feature/ibt-manifest-tracking -- flutter_app/lib/presentation/screens/entry_detail_screen.dart
   git diff origin/main origin/feature/ibt-manifest-tracking -- flutter_app/lib/presentation/screens/loading_sheet_screen.dart
   ```
3. Test suite & static analysis verification (post-graft):
   ```bash
   cd flutter_app && dart analyze
   cd flutter_app && flutter test
   ```
