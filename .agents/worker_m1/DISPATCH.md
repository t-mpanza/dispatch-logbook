## 2026-09-01T18:58:31Z
Scope & Task for Milestone 1:
1. `flutter_app/pubspec.yaml`:
   - Add `flutter_secure_storage: ^11.0.0` and `webview_flutter: ^4.10.0`.
   - Remove `open_filex: ^4.7.0`.
   - Run `flutter pub get` in `flutter_app/`.
2. Port `flutter_app/lib/data/models/ibt_manifest.dart` from `origin/feature/ibt-manifest-tracking` (`IbtLineItem`, `IbtDocument`, getters `remaining`, `overCount`, `progressPercent`, `isComplete`, `isShort`, `isOverloaded`, `loadedTotal`, `remainingTotal`, `hasShortages`, `toMap`, `fromMap`, `copyWith`).
3. Update `flutter_app/lib/data/models/loading_sheet_trip.dart`:
   - Add `List<IbtDocument>? ibtDocuments`, `hasIbtDocuments`, `ibtTargetTotal`, `ibtLoadedTotal`.
   - Graft `effectiveTarget` calculation into target-dependent getters (`remainingTyres`, `overCount`, `progressPercent`, `isTargetReached`, `isTargetExceeded`).
   - Update `toMap`, `fromMap`, `copyWith` maintaining complete backwards compatibility.
4. Port `flutter_app/lib/data/services/appsync_manifest_service.dart`:
   - Implement `AppSyncManifestService` with Cognito OAuth2 Hosted UI handling (`myapp://`), direct `USER_PASSWORD_AUTH` credentials login, JWT decoding & automatic refresh, AppSync GraphQL `getDeliveryInfo` with empty-string VTL crash guards (`inv: ""`, `dibt: ""`, `amsInv: ""`), `sizeMaster`, `rubberMaster`, heuristic regex extraction, diagnostics (`testConnection`), and logout.
5. Update `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart`:
   - Add guard in `getDayEntries()` against clobbering IBT document targets (`!t.hasIbtDocuments`).
   - Implement `attachIbtDocument`, `removeIbtDocument`, and `updateIbtLineQuantity`.
6. Update `flutter_app/lib/data/services/whatsapp_export_service.dart` and `flutter_app/lib/data/services/pdf_export_service.dart` with IBT manifest breakdown rendering.
7. Port/Update `flutter_app/lib/data/services/update_service.dart` to remove `open_filex` import and prepare stream-based download / MethodChannel install so `dart analyze` passes without errors.
8. Port/Create tests:
   - `flutter_app/test/ibt_manifest_test.dart`
   - `flutter_app/test/appsync_manifest_service_test.dart`
   - `flutter_app/test/ibt_workflow_tdd_test.dart`
9. Run verification commands:
   - Run `dart analyze` in `flutter_app/`
   - Run `flutter test` on the test suite in `flutter_app/`
