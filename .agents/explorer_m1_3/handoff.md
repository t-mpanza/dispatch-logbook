# Milestone 1: Data Models & Core Services — Deep-Dive Diff & Technical Assessment

## 1. Observation

### 1.1 Git Divergence and Branch Context
- Merge Base Commit: `a28e1fa` (`tag: v2.0.47`)
- Mainline Head: `26047b8` (`origin/main`, `v2.1.0-rc7`)
- Feature Branch Head: `2efb499` (`origin/feature/ibt-manifest-tracking`, `v2.1.0-rc7-ibt`)
- Total Commits on Feature Branch: 12 commits (`eb8069b` through `2efb499`).
- Commit Log Highlights:
  - `eb8069b`: feat: integrate IBT manifest tracking, multi-line counter, and AppSync GraphQL client
  - `05d57a7`: feat: add in-app AWS Cognito authentication dialog and restrict IBT section strictly to STOCKS preset
  - `171f0ba`: feat: add in-app AWS Web Sign-In with automated OAuth token interception and storage
  - `2e6ff3d`: fix(auth): correct Cognito Hosted UI authorization URL flow and user agent for WebView sign-in
  - `9306bbb`: fix(appsync): align getDeliveryInfo GraphQL query signature with exact production schema
  - `d570aac`: fix(appsync): pass empty strings for optional VTL variables to prevent .substring() crash
  - `73011bf`: feat(updater): in-app APK downloader with progress bar + Android install intent
  - `2efb499`: feat(ibt): in-counter IBT line breakdown, expectedTotal sync, and overshoot warning

---

### 1.2 Exact File Inventory: Created or Modified in `origin/feature/ibt-manifest-tracking`

| Layer | Status | File Path | Scope / Milestone | Lines Changed |
|---|---|---|---|---|
| **Data Models** | **NEW** | `flutter_app/lib/data/models/ibt_manifest.dart` | M1 | +132 |
| **Data Models** | **MODIFIED** | `flutter_app/lib/data/models/loading_sheet_trip.dart` | M1 | +83, -13 |
| **Services** | **NEW** | `flutter_app/lib/data/services/appsync_manifest_service.dart` | M1 | +544 |
| **Services** | **MODIFIED** | `flutter_app/lib/data/services/whatsapp_export_service.dart` | M1 | +14 |
| **Services** | **MODIFIED** | `flutter_app/lib/data/services/pdf_export_service.dart` | M1 | +387, -590 |
| **Services** | **MODIFIED** | `flutter_app/lib/data/services/update_service.dart` | M1 / M4 | +192, -60 |
| **ViewModels** | **MODIFIED** | `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart` | M1 | +129, -15 |
| **ViewModels** | **MODIFIED** | `flutter_app/lib/presentation/viewmodels/entries_viewmodel.dart` | M1 | +2 |
| **Configuration** | **MODIFIED** | `flutter_app/pubspec.yaml` | M1 | +2, -1 |
| **Unit Tests** | **NEW** | `flutter_app/test/appsync_manifest_service_test.dart` | M1 | +212 |
| **Unit Tests** | **NEW** | `flutter_app/test/ibt_manifest_test.dart` | M1 | +224 |
| **Unit Tests** | **NEW** | `flutter_app/test/ibt_workflow_tdd_test.dart` | M1 | +120 |
| **Unit Tests** | **MODIFIED** | `flutter_app/test/update_service_test.dart` | M1 / M4 | +76, -10 |
| **Auth UI** | **NEW** | `flutter_app/lib/presentation/screens/aws_login_webview_screen.dart` | M2 | +230 |
| **Auth UI** | **NEW** | `flutter_app/lib/presentation/widgets/aws_auth_dialog.dart` | M2 | +620 |
| **IBT UI** | **NEW** | `flutter_app/lib/presentation/widgets/ibt_line_items_sheet.dart` | M3 | +539 |
| **IBT UI** | **MODIFIED** | `flutter_app/lib/presentation/widgets/counter_panel.dart` | M3 | +50, -10 |
| **IBT UI** | **MODIFIED** | `flutter_app/lib/presentation/widgets/counter_progress.dart` | M3 | +417, -50 |
| **IBT UI** | **MODIFIED** | `flutter_app/lib/presentation/screens/new_entry_screen.dart` | M3 | +257, -15 |
| **IBT UI** | **MODIFIED** | `flutter_app/lib/presentation/screens/entry_detail_screen.dart` | M3 | +169, -15 |
| **IBT UI** | **MODIFIED** | `flutter_app/lib/presentation/screens/loading_sheet_screen.dart` | M3 | +113, -10 |
| **IBT UI** | **MODIFIED** | `flutter_app/lib/presentation/screens/today_screen.dart` | M3 | +29, -5 |
| **IBT UI** | **MODIFIED** | `flutter_app/lib/presentation/widgets/truck_load_dialog.dart` | M3 | +669, -120 |
| **Native Android** | **NEW** | `flutter_app/android/app/src/main/res/xml/file_provider_paths.xml` | M4 | +7 |
| **Native Android** | **MODIFIED** | `flutter_app/android/app/src/main/AndroidManifest.xml` | M4 | +26, -5 |
| **Native Android** | **MODIFIED** | `flutter_app/android/app/src/main/kotlin/com/dispatchdiary/dispatch_diary/MainActivity.kt` | M4 | +56, -5 |
| **Native Android** | **MODIFIED** | `flutter_app/android/app/build.gradle.kts` | M4 | +4, -2 |
| **Native Android** | **MODIFIED** | `flutter_app/lib/presentation/widgets/update_dialog.dart` | M4 | +289, -40 |

---

### 1.3 Database & Storage Schema Direct Inspection

#### SQLite (`flutter_app/lib/data/services/database_service.dart`)
- `DatabaseService._initDb()` creates tables:
  ```sql
  CREATE TABLE entries (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    tags TEXT,
    expected_total INTEGER,
    notes TEXT,
    attachments TEXT,
    trips TEXT,
    loading_sheet_trips TEXT,
    despatcher_name TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    day_key TEXT NOT NULL,
    month_key TEXT NOT NULL,
    year_key TEXT NOT NULL
  );
  ```
- `loading_sheet_trips` is stored as a serialized JSON text array of `LoadingSheetTrip` records.
- In `LoadingSheetTrip`:
  - `ibtDocuments` is serialized into `'ibtDocuments': ibtDocuments?.map((e) => e.toMap()).toList()`.
  - Deserialization in `LoadingSheetTrip.fromMap(map)`:
    ```dart
    List<IbtDocument>? ibts;
    if (map['ibtDocuments'] != null) {
      final rawList = map['ibtDocuments'] as List<dynamic>;
      ibts = rawList
          .map((e) => IbtDocument.fromMap(e as Map<String, dynamic>))
          .toList();
    }
    ```
- Result: **Zero SQLite DDL schema changes or table migrations are needed.** Old entries lacking `ibtDocuments` deserialize with `ibtDocuments = null` without errors.

#### Supabase Sync (`flutter_app/lib/data/services/supabase_service.dart`)
- In `_formatEntryPayload(Entry entry, String userId)`:
  - `loadingSheetTrips` are embedded inside the `notes` column as a JSON note object with `id: '__meta_sheet__'`.
  - Content: `jsonEncode({'loadingSheetTrips': entry.loadingSheetTrips?.map((t) => t.toMap()).toList() ?? [], 'despatcherName': ...})`.
- In `pullAndMerge()`:
  - Finds `n['id'] == '__meta_sheet__'`, decodes `parsed['loadingSheetTrips']`, and runs `LoadingSheetTrip.fromMap()`.
- Result: **Zero Supabase SQL schema migrations or table column additions (ALTER TABLE) are required.**

---

### 1.4 Dependencies and `pubspec.yaml` Inspection

Diff in `flutter_app/pubspec.yaml`:
```diff
 dependencies:
   photo_view: ^0.15.0
   http: ^1.2.0
   package_info_plus: ^10.2.1
-  open_filex: ^4.7.0
+  flutter_secure_storage: ^11.0.0
+  webview_flutter: ^4.10.0
```

#### Analyzer / Compilation Check:
When `open_filex` is removed from `pubspec.yaml` without updating `update_service.dart`:
```
Analyzing flutter_app...
  error - lib/data/services/update_service.dart:6:8 - Target of URI doesn't exist: 'package:open_filex/open_filex.dart'. - uri_does_not_exist
  error - lib/data/services/update_service.dart:150:28 - Undefined name 'OpenFilex'. - undefined_identifier
  error - lib/data/services/update_service.dart:155:29 - Undefined name 'ResultType'. - undefined_identifier
   info - lib/data/services/update_service.dart:6:8 - The imported package 'open_filex' isn't a dependency of the importing package. - depend_on_referenced_packages
4 issues found.
```
Resolution: Updating `lib/data/services/update_service.dart` to use the stream-based `downloadApk` (which relies solely on `http`, `path_provider`, and `dart:io`) completely resolves all 4 issues.

---

### 1.5 Test Suite Execution Results

Running M1 tests:
- `test/appsync_manifest_service_test.dart` (5/5 tests PASSED)
- `test/ibt_manifest_test.dart` (5/5 tests PASSED)
- `test/ibt_workflow_tdd_test.dart` (1/1 test PASSED)
- `test/preset_engine_test.dart` (4/4 tests PASSED)
- `test/whatsapp_export_test.dart` (1/1 test PASSED)
- `test/entry_model_test.dart` (1/1 test PASSED)
- **Total M1 tests: 17/17 PASSED in 19 seconds.**

---

## 2. Logic Chain

1. **Branch Divergence Analysis**:
   - `origin/main` and `origin/feature/ibt-manifest-tracking` diverged at `v2.0.47`.
   - `main` received Daylight theme improvements (`dynamicTextPrimary`, `dynamicCardSurface`), rich media controls, audio players, and capacitor releases.
   - `origin/feature/ibt-manifest-tracking` received the complete AWS AppSync IBT manifest tracking subsystem, Cognito auth, multi-line steppers, and native APK updater.
   - Direct whole-file overwriting from the feature branch would inadvertently revert mainline theme and media improvements; therefore, **surgical porting per milestone** is necessary.

2. **Data Layer Architecture**:
   - `IbtLineItem` and `IbtDocument` in `lib/data/models/ibt_manifest.dart` encapsulate line-level tyre accounting:
     - `remaining = (targetTotal - loadedQuantity).clamp(0, targetTotal)`
     - `overCount = (loadedQuantity - targetTotal).clamp(0, loadedQuantity)`
     - `isComplete = targetTotal > 0 && loadedQuantity >= targetTotal`
     - `isShort = loadedQuantity < targetTotal`
     - `isOverloaded = loadedQuantity > targetTotal`
     - `progressPercent = (loadedQuantity / targetTotal).clamp(0.0, 1.0)`
   - `LoadingSheetTrip` integrates `List<IbtDocument>? ibtDocuments`:
     - `effectiveTarget` computation: prioritizes explicit `targetQuantity` if > 0, otherwise computes `ibtTargetTotal` if `hasIbtDocuments` is true.
     - `remainingTyres`, `overCount`, `progressPercent`, `isTargetReached`, `isTargetExceeded` dynamically adapt based on `effectiveTarget`.

3. **Database Schema Compatibility**:
   - SQLite stores `loading_sheet_trips` as a JSON text blob in the `entries` table (`loading_sheet_trips TEXT`).
   - Adding `ibtDocuments` to `LoadingSheetTrip.toMap()` and `fromMap()` serializes the document hierarchy nested within this JSON column.
   - Supabase sync packs `loadingSheetTrips` into the synthetic `__meta_sheet__` note in the `notes` JSONB column.
   - Because all persistence relies on structured JSON serialization with safe null handling, existing records load smoothly without requiring any schema migrations, table alters, or DB version bumps.

4. **AWS AppSync & Cognito Service Architecture**:
   - `AppSyncManifestService` connects to endpoint `https://tbbvff57pve53e6d234w7f2mva.appsync-api.af-south-1.amazonaws.com/graphql`.
   - Auth flows supported:
     1. Direct credentials login (`loginWithCredentials`) via Cognito `USER_PASSWORD_AUTH` on `cognito-idp.af-south-1.amazonaws.com`.
     2. Hosted UI OAuth2 Web sign-in (`getHostedUiAuthorizeUrl` / `handleRedirectUrl`).
     3. JWT token decode, expiry validation, and automatic refresh via Cognito `/oauth2/token` refresh grant.
   - Tokens stored securely in KeyStore/Keychain via `FlutterSecureStorage`.
   - GraphQL query `getDeliveryInfo` passes empty strings `""` for optional VTL variables (`inv`, `dibt`, `amsInv`) to prevent AppSync Velocity Template `.substring()` crashes.

5. **Compilation and Analyzer Stability**:
   - Removing `open_filex` in favor of native Android `MethodChannel` (`MainActivity.kt`) and `FileProvider` is optimal for Android 14+ compatibility.
   - `UpdateService` must be updated in tandem with `pubspec.yaml` to ensure zero compilation breaks during intermediate milestones.

6. **ViewModel & Export Integration**:
   - `LoadingSheetViewModel` provides `updateIbtLineQuantity`, `attachIbtDocument`, and `removeIbtDocument`.
   - `WhatsAppExportService` itemizes IBT manifests with emoji status indicators (`✓`, `⚠️ Short N`, `+N Over`).
   - `PdfExportService` formats IBT manifest tables with line breakdowns, descriptions, RCS codes, targets, and completion status.

---

## 3. Caveats

1. **Theme Consistency**:
   - UI screens created on the feature branch (`aws_login_webview_screen.dart`, `aws_auth_dialog.dart`, `ibt_line_items_sheet.dart`) used dark theme defaults.
   - During M2 and M3 implementation, all new UI widgets must use `GlassDecorations.glassCard(context: context)` and `AppColors.dynamicTextPrimary(context)` so they look stunning in both Daylight and Night themes.

2. **Cognito Hosted UI Google/Chrome Restrictions**:
   - Google blocks OAuth in standard Android webviews with generic User-Agents (`disallowed_useragent`).
   - `AwsLoginWebViewScreen` must set `customUserAgent: 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36'` to enable smooth in-app sign-in.

3. **Android Native MethodChannel (M4 Scope)**:
   - Full APK installation requires `file_provider_paths.xml`, `AndroidManifest.xml` FileProvider declarations, and `MainActivity.kt` MethodChannel handlers which are scheduled for M4.

---

## 4. Conclusion

The data models and core services for Milestone 1 are well-structured, backward-compatible, and ready for full implementation.
- **Data Models**: `IbtLineItem`, `IbtDocument`, and `LoadingSheetTrip` extension are self-contained and verified.
- **Database**: Zero schema alterations needed for SQLite and Supabase.
- **Services**: `AppSyncManifestService` includes comprehensive VTL crash guards, Cognito token refresh, and secure storage integration.
- **Dependencies**: `flutter_secure_storage: ^11.0.0` and `webview_flutter: ^4.10.0` provide the necessary cryptographic and web capabilities.
- **Test Suite**: 17 M1 tests pass 100% with full offline mock support.

---

## 5. Verification Method

### 5.1 Verification Commands
To independently verify Milestone 1 integrity:

1. **Resolve dependencies**:
   ```bash
   cd "/home/kiddow/Desktop/Work/Despatch Diary/flutter_app"
   flutter pub get
   ```

2. **Static Analysis (Must return 0 errors, 0 warnings)**:
   ```bash
   dart analyze
   ```

3. **Run M1 Test Suite**:
   ```bash
   flutter test \
     test/appsync_manifest_service_test.dart \
     test/ibt_manifest_test.dart \
     test/ibt_workflow_tdd_test.dart \
     test/preset_engine_test.dart \
     test/whatsapp_export_test.dart \
     test/entry_model_test.dart
   ```

### 5.2 Invalidation Conditions
- Any `dart analyze` errors in `flutter_app/lib/` or `flutter_app/test/`.
- Any failure in `appsync_manifest_service_test.dart`, `ibt_manifest_test.dart`, or `ibt_workflow_tdd_test.dart`.
- Any SQLite deserialization failure on legacy entry records lacking `ibtDocuments`.
