# Project: AWS AppSync IBT Manifest Tracking Subsystem Port

## Architecture
- **Language / Framework**: Dart / Flutter 3.12.2+, Kotlin 2.3.20, Android Gradle Plugin 9.0.1
- **Subsystems**:
  1. **Data Layer**: Pure Dart IBT models (`IbtLineItem`, `IbtDocument`), `LoadingSheetTrip` extension, JSON serialization to SQLite and Supabase.
  2. **Service Layer**: `AppSyncManifestService` (Cognito OAuth2 token flow, `USER_PASSWORD_AUTH`, JWT decoding/refresh, AppSync GraphQL `getDeliveryInfo` with empty-string VTL crash guards).
  3. **Auth UI**: `AwsLoginWebViewScreen` (embedded Webview with Chrome Android UA, custom URI redirect interception `myapp://`), `AwsAuthDialog` (token management, credentials login, live connection test).
  4. **Presentation / UI**: `IbtLineItemsSheet` modal, surgical grafting into `CounterPanel` (overshoot warning `_warnIfOver`), `NewEntryScreen` (STOCKS preset IBT fetch card), `EntryDetailScreen` (IBT progress bars & badge), `LoadingSheetScreen` (header AWS sync button, truck card IBT summary). All UI styled with Daylight theme tokens (`AppColors.dynamicText*`, `GlassDecorations.glassCard(context: context)`).
  5. **Android Native**: `MainActivity.kt` MethodChannel `com.dispatchdiary.dispatch_diary/install`, `FileProvider` with `${applicationId}.fileprovider`, `file_provider_paths.xml`, `AndroidManifest.xml` intent filters for `myapp` and `dispatchdiary`, replacing `open_filex`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | `pubspec.yaml` Dependencies | Add `flutter_secure_storage`, `webview_flutter`, remove `open_filex` | M1 | Survey 1/3 |
| 2 | IBT Models | `IbtLineItem`, `IbtDocument` with target/loaded/shortage/overshoot logic | M1 | Survey 1 |
| 3 | LoadingSheetTrip Extension | `ibtDocuments` list, `effectiveTarget`, JSON serialization | M1 | Survey 1 |
| 4 | AppSync Manifest Service | Cognito auth, JWT refresh, GraphQL queries with VTL compatibility | M1 | Survey 1 |
| 5 | ViewModel IBT Operations | `updateIbtLineQuantity`, `attachIbtDocument`, `removeIbtDocument` in `LoadingSheetViewModel` | M1 | Survey 1 |
| 6 | Export Services IBT | WhatsApp and PDF export IBT breakdown tables | M1 | Survey 1/2 |
| 7 | AWS Login WebView | Cognito OAuth embedded webview with UA override and `myapp://` redirect interception | M2 | Survey 1 |
| 8 | AWS Auth Dialog | Cognito credentials login, token paste, token status, live connection test | M2 | Survey 1 |
| 9 | IBT Line Items Sheet | Modal bottom sheet with per-document line items and steppers (`-1`, `+1`, `+5`) | M3 | Survey 2 |
| 10 | CounterPanel Overshoot Guard | `_warnIfOver` warning dialog before logging over-target scans, preserving 40px/42px sizing | M3 | Survey 2 |
| 11 | NewEntryScreen STOCKS Attachment | STOCKS preset triggers IBT fetch card and initial trip creation | M3 | Survey 2 |
| 12 | EntryDetailScreen IBT Breakdown | Real-time IBT progress breakdown card and `effectiveTarget` propagation | M3 | Survey 2 |
| 13 | LoadingSheetScreen AWS & Summary | Header AWS sync button, truck card IBT summary chip and breakdown sheet trigger | M3 | Survey 2 |
| 14 | Android FileProvider | `file_provider_paths.xml` mapping cache directories for APK installation | M4 | Survey 3 |
| 15 | Android Manifest Config | FileProvider declaration and Cognito deep link intent filter (`myapp`, `dispatchdiary`) | M4 | Survey 3 |
| 16 | MainActivity MethodChannel | Native `installApk` handler on `com.dispatchdiary.dispatch_diary/install` | M4 | Survey 3 |
| 17 | UpdateService Native Refactor | Replace `open_filex` with native MethodChannel and streaming APK download | M4 | Survey 3 |
| 18 | Verification & Test Suite | `dart analyze` (0 issues), all unit/widget tests passing, `flutter build apk` succeeds | M5 | Survey 3 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Data Models & Core Services (R1) | `pubspec.yaml`, `ibt_manifest.dart`, `loading_sheet_trip.dart`, `appsync_manifest_service.dart`, `loading_sheet_viewmodel.dart`, export services, unit tests | None | PLANNED |
| M2 | AWS Auth Flow (R2) | `aws_login_webview_screen.dart`, `aws_auth_dialog.dart` | M1 | PLANNED |
| M3 | IBT UI & Surgical Grafting (R3 & R4) | `ibt_line_items_sheet.dart`, `counter_panel.dart`, `new_entry_screen.dart`, `entry_detail_screen.dart`, `loading_sheet_screen.dart` | M1, M2 | PLANNED |
| M4 | Android Native APK Installs (R5) | `file_provider_paths.xml`, `AndroidManifest.xml`, `MainActivity.kt`, `update_service.dart`, `update_dialog.dart` | M1 | PLANNED |
| M5 | Verification & Build Validation | Run `dart analyze`, all `flutter test` suites, `flutter build apk` | M1, M2, M3, M4 | PLANNED |

## Interface Contracts
### `AppSyncManifestService` ↔ Auth UI & Models
- `fetchIbtDocument(String documentNoInput, {http.Client? client, String? explicitIdToken}) -> Future<IbtDocument>`
- `loginWithCredentials({required String username, required String password, http.Client? client}) -> Future<AwsUserInfo>`
- `getHostedUiAuthorizeUrl({bool tokenFlow = true}) -> String`
- `handleRedirectUrl(String url, {http.Client? client}) -> Future<bool>`
- `getAuthDetails() -> Future<AwsUserInfo>`
- `logout() -> Future<void>`
- `testConnection() -> Future<({bool ok, String message})>`

### `MainActivity.kt` ↔ `UpdateService`
- Channel: `com.dispatchdiary.dispatch_diary/install`
- Method: `installApk`
- Arguments: `{'path': String}`
- Success: `true` (Boolean)
- Error: `PlatformException` with code `INVALID_PATH`, `FILE_NOT_FOUND`, or `INSTALL_FAILED`

## Code Layout
- `flutter_app/lib/data/models/ibt_manifest.dart` (New)
- `flutter_app/lib/data/models/loading_sheet_trip.dart` (Modified)
- `flutter_app/lib/data/services/appsync_manifest_service.dart` (New)
- `flutter_app/lib/data/services/whatsapp_export_service.dart` (Modified)
- `flutter_app/lib/data/services/pdf_export_service.dart` (Modified)
- `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart` (Modified)
- `flutter_app/lib/presentation/screens/aws_login_webview_screen.dart` (New)
- `flutter_app/lib/presentation/widgets/aws_auth_dialog.dart` (New)
- `flutter_app/lib/presentation/widgets/ibt_line_items_sheet.dart` (New)
- `flutter_app/lib/presentation/widgets/counter_panel.dart` (Modified)
- `flutter_app/lib/presentation/screens/new_entry_screen.dart` (Modified)
- `flutter_app/lib/presentation/screens/entry_detail_screen.dart` (Modified)
- `flutter_app/lib/presentation/screens/loading_sheet_screen.dart` (Modified)
- `flutter_app/android/app/src/main/res/xml/file_provider_paths.xml` (New)
- `flutter_app/android/app/src/main/AndroidManifest.xml` (Modified)
- `flutter_app/android/app/src/main/kotlin/com/dispatchdiary/dispatch_diary/MainActivity.kt` (Modified)
- `flutter_app/lib/data/services/update_service.dart` (Modified)
- `flutter_app/lib/presentation/widgets/update_dialog.dart` (Modified)
- `flutter_app/pubspec.yaml` (Modified)
