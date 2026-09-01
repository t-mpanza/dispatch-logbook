# Survey & Git Diff Analysis Report — IBT Manifest Subsystem Porting

**Author**: survey_explorer_1  
**Date**: 2026-09-01  
**Target Repository**: `dispatch-logbook`  
**Base Branch**: `main` (`26047b8`)  
**Source Branch**: `origin/feature/ibt-manifest-tracking` (`2efb499`)  
**Common Ancestor**: `a28e1fa` (tag: `v2.0.47`)

---

## 1. Observation

### 1.1 Branch & Divergence Structure
- Common base commit: `a28e1fa` (`docs: add comprehensive low-level system manual and technical architecture documentation`).
- `origin/feature/ibt-manifest-tracking` has **12 commits** adding:
  - AWS Cognito OAuth flow & AppSync GraphQL client (`eb8069b`, `05d57a7`, `171f0ba`, `2e6ff3d`, `9306bbb`, `d570aac`).
  - IBT manifest tracking, multi-line counter, stepper sheets (`eb8069b`, `2efb499`).
  - In-app streaming APK downloader & Android `FileProvider` install intent (`73011bf`).
- `main` has **11 commits** implementing:
  - Multi-place ThemeToggle & 3-way theme switcher, high-visibility Daylight/Sunlight mode (`fc21987`, `9031746`, `a00f273`, `37c58dd`).
  - Bidirectional target tyre auto-syncing (`fc21987`, `9031746`).
  - Target stepper pills (+1, +5, +10, +20, +50) and compact high-density counter layout (`993d545`, `439b232`).
  - PDF preview screen and media controls (`a00f273`, `f7d2216`).

### 1.2 `pubspec.yaml` Dependency Changes
Comparing `main` with `origin/feature/ibt-manifest-tracking`:

| Package | Main (`pubspec.yaml`) | Feature Branch | Required Action for Port |
|---|---|---|---|
| `flutter_secure_storage` | *Not present* | `^11.0.0` | **Add** to `dependencies` |
| `webview_flutter` | *Not present* | `^4.10.0` | **Add** to `dependencies` |
| `open_filex` | `^4.7.0` | *Removed* | **Remove** from `dependencies` |

### 1.3 Data Models & Services to Port

#### A. `flutter_app/lib/data/models/ibt_manifest.dart` (New File — 132 lines)
Contains two immutable data models:
1. `IbtLineItem`:
   - Fields: `id`, `description`, `rcsCode`, `sizeId`, `rubberId`, `size`, `rubber`, `targetTotal`, `loadedQuantity`.
   - Computed properties: `remaining`, `overCount`, `isComplete`, `isShort`, `isOverloaded`, `progressPercent`.
   - Methods: `copyWith()`, `toMap()`, `fromMap()`.
2. `IbtDocument`:
   - Fields: `documentNo`, `total`, `lineItems` (`List<IbtLineItem>`).
   - Computed properties: `loadedTotal`, `remainingTotal`, `isComplete`, `hasShortages`.
   - Methods: `copyWith()`, `toMap()`, `fromMap()`.

#### B. `flutter_app/lib/data/services/appsync_manifest_service.dart` (New File — 544 lines)
Encapsulates AWS AppSync GraphQL communication and Cognito authentication:
- **Constants**:
  - AppSync Endpoint: `https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql`
  - Cognito Domain: `cabsystem.auth.eu-central-1.amazoncognito.com`
  - Cognito IDP Endpoint: `https://cognito-idp.eu-central-1.amazonaws.com`
  - Client ID: `78ikblrgsr8h27197iovkgrro6`
  - Redirect URI: `myapp://`
- **Master Tables**: `sizeMaster` (maps backend IDs to tire sizes) and `rubberMaster` (maps backend IDs to rubber compounds).
- **Core Functions**:
  - `getHostedUiAuthorizeUrl()`
  - `handleRedirectUrl(String url)` (extracts tokens from implicit/auth code redirect)
  - `exchangeCodeForTokens(String code)`
  - `loginWithCredentials(username, password)` (Cognito `InitiateAuth` with `USER_PASSWORD_AUTH`)
  - `saveAuthTokens()`, `getAuthDetails()`, `getValidIdToken()` (auto-refreshes JWT 60s before expiry), `refreshAccessToken()`, `logout()`, `testConnection()`
  - `fetchIbtDocument(String docNo)`: Executes GraphQL query `getDeliveryInfo` passing required empty strings (`inv: '', dibt: '', amsInv: ''`) to prevent VTL crashes, and parses response via `parseIbtLines()`.

#### C. `flutter_app/lib/data/models/loading_sheet_trip.dart` (Model Modification)
Modifications to graft IBT document support while maintaining compatibility:
- **Field Added**: `final List<IbtDocument>? ibtDocuments;`
- **Getters Added**:
  - `bool get hasIbtDocuments => ibtDocuments != null && ibtDocuments!.isNotEmpty;`
  - `int get ibtTargetTotal => ibtDocuments?.fold<int>(0, (sum, doc) => sum + doc.total) ?? 0;`
  - `int get ibtLoadedTotal => ibtDocuments?.fold<int>(0, (sum, doc) => sum + doc.loadedTotal) ?? 0;`
- **Effective Target in Calculations**:
  ```dart
  final effectiveTarget = (targetQuantity != null && targetQuantity! > 0)
      ? targetQuantity!
      : (hasIbtDocuments ? ibtTargetTotal : 0);
  ```
  Updated across `remainingTyres`, `overCount`, `progressPercent`, `isTargetReached`, and `isTargetExceeded`.
- **Serialization**:
  - `toMap()` includes `'ibtDocuments': ibtDocuments?.map((e) => e.toMap()).toList()`.
  - `fromMap()` deserializes `'ibtDocuments'` if present and uses null-safe type casting.

### 1.4 Downstream ViewModel and Export Changes
1. `LoadingSheetViewModel`:
   - Added methods: `updateIbtLineQuantity()`, `attachIbtDocument()`, `removeIbtDocument()`.
   - Note: Preserve `main`'s existing entry target sync in `getTripsForSelectedDate()`!
2. `WhatsAppExportService`:
   - Formats attached IBT documents with `[✓]`, `[⚠️ Short N]`, or `[+N Over]` status per line item.
3. `PdfExportService`:
   - Adds an itemized IBT line item breakdown table when `hasIbtDocuments` is true.

### 1.5 Native Android & Updater Changes
1. `AndroidManifest.xml`:
   - Added `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>`.
   - Added deep link intent filters for `myapp` and `dispatchdiary` schemes.
   - Added `FileProvider` provider definition for `${applicationId}.fileprovider`.
2. `res/xml/file_provider_paths.xml`:
   - Defines `<cache-path name="apk_cache" path="." />` and `<external-cache-path name="external_apk_cache" path="." />`.
3. `MainActivity.kt`:
   - Implements MethodChannel handler for `installApk` using Android `FileProvider` and `Intent.ACTION_VIEW`.
   - Channel Name: `com.dispatchdiary.dispatch_diary/install` (matching `main`'s applicationId).
4. `UpdateService`:
   - Replaces `OpenFilex` with streaming `downloadApk` and semver/RC version comparison (`isNewerVersion`).

---

## 2. Logic Chain

1. **Why `open_filex` is removed and replaced with `MainActivity.kt` MethodChannel**:
   - `open_filex` has issues with Android 13/14 package installer intents and file URIs.
   - The native `FileProvider` implementation directly emits `ACTION_VIEW` with `FLAG_GRANT_READ_URI_PERMISSION`, ensuring robust 1-tap APK upgrades.
2. **Why `flutter_secure_storage` is required**:
   - AWS Cognito ID tokens, access tokens, and refresh tokens must be securely persisted on disk so users do not need to re-login every session.
3. **Why `webview_flutter` is required**:
   - The Cognito Hosted UI sign-in flow (`cabsystem.auth.eu-central-1.amazoncognito.com`) runs in an in-app WebView (`AwsLoginWebViewScreen`) which intercepts the `myapp://` redirect URL to capture the authorization code/tokens.
4. **Why `LoadingSheetTrip` must use `effectiveTarget`**:
   - For STOCKS trips attached to IBT manifests, the target is computed dynamically by summing all line items across attached `IbtDocument`s (`ibtTargetTotal`). If a manual `targetQuantity` is not explicitly set, `ibtTargetTotal` serves as the fallback target for quota calculations.

---

## 3. Caveats

1. **Application ID naming**:
   - On the feature branch, `applicationId` was changed to `com.dispatchdiary.ibt_edition`.
   - On `main`, the applicationId remains `com.dispatchdiary.dispatch_diary`.
   - Therefore, the MethodChannel name in `MainActivity.kt` and `update_dialog.dart` MUST be `com.dispatchdiary.dispatch_diary/install`.
2. **Daylight Theme & Layout Protection**:
   - The feature branch branched from `a28e1fa` before `main`'s daylight/sunlight theme and compact UI refactor was implemented.
   - Files such as `counter_panel.dart`, `counter_progress.dart`, `today_screen.dart`, and `new_entry_screen.dart` on `main` have daylight theme awareness (`AppColors.dynamicTextPrimary(context)`, `GlassDecorations.glassCard(context: context)`).
   - Under no circumstances should feature branch UI files simply overwrite `main`'s files. Only the IBT-specific widgets/cards must be grafted into `main`.

---

## 4. Conclusion

The porting surface is clearly mapped:
- **New Files to Port Directly**:
  - `flutter_app/lib/data/models/ibt_manifest.dart`
  - `flutter_app/lib/data/services/appsync_manifest_service.dart`
  - `flutter_app/lib/presentation/widgets/ibt_line_items_sheet.dart`
  - `flutter_app/lib/presentation/screens/aws_login_webview_screen.dart`
  - `flutter_app/lib/presentation/widgets/aws_auth_dialog.dart`
  - `flutter_app/android/app/src/main/res/xml/file_provider_paths.xml`
  - `flutter_app/test/appsync_manifest_service_test.dart`
  - `flutter_app/test/ibt_manifest_test.dart`
  - `flutter_app/test/ibt_workflow_tdd_test.dart`
- **Files to Modify Surgically**:
  - `flutter_app/pubspec.yaml` (add `flutter_secure_storage: ^11.0.0`, `webview_flutter: ^4.10.0`, remove `open_filex`)
  - `flutter_app/lib/data/models/loading_sheet_trip.dart` (add `ibtDocuments` & helper getters)
  - `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart` (add IBT attachment and line update methods)
  - `flutter_app/lib/data/services/whatsapp_export_service.dart` & `pdf_export_service.dart`
  - `flutter_app/lib/data/services/update_service.dart`
  - `flutter_app/android/app/src/main/AndroidManifest.xml` & `MainActivity.kt`
  - `flutter_app/lib/presentation/screens/new_entry_screen.dart`, `entry_detail_screen.dart`, `loading_sheet_screen.dart`, `truck_load_dialog.dart`, `update_dialog.dart`.

---

## 5. Verification Method

To independently verify the survey and resulting implementation:
1. Run `flutter pub get` after modifying `pubspec.yaml`.
2. Execute all unit and TDD test suites:
   ```bash
   cd flutter_app
   flutter test test/ibt_manifest_test.dart
   flutter test test/appsync_manifest_service_test.dart
   flutter test test/ibt_workflow_tdd_test.dart
   flutter test test/update_service_test.dart
   flutter test
   ```
3. Run static analysis:
   ```bash
   dart analyze
   ```
4. Build APK to ensure Android native integration compiles:
   ```bash
   flutter build apk --debug
   ```
