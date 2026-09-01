# Handoff Report: Android Native Layer, Update Service & Test Baseline Survey

## 1. Observation

### 1.1 Android Native Configuration
- **Application ID & Namespace**: `flutter_app/android/app/build.gradle.kts` (lines 10, 39) specifies `namespace = "com.dispatchdiary.dispatch_diary"` and `applicationId = "com.dispatchdiary.dispatch_diary"`.
- **AndroidManifest.xml**: `flutter_app/android/app/src/main/AndroidManifest.xml` (lines 1-71):
  - Line 15 already declares: `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>`.
  - Line 18 declares `android:label="Dispatch Diary"`.
  - Missing deep-link intent-filter for Cognito OAuth redirect (`<data android:scheme="myapp" />`, `<data android:scheme="dispatchdiary" />`).
  - Missing FileProvider declaration: `<provider android:name="androidx.core.content.FileProvider" android:authorities="${applicationId}.fileprovider" android:exported="false" android:grantUriPermissions="true">`.
- **FileProvider Paths**: Directory `flutter_app/android/app/src/main/res/xml/` and file `file_provider_paths.xml` do not exist on `main`. The feature branch defines:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <paths>
      <cache-path name="apk_cache" path="." />
      <external-cache-path name="external_apk_cache" path="." />
  </paths>
  ```
- **MainActivity.kt**: `flutter_app/android/app/src/main/kotlin/com/dispatchdiary/dispatch_diary/MainActivity.kt` (lines 1-6) is currently a bare `FlutterActivity` stub without MethodChannel handlers.
  - On `origin/feature/ibt-manifest-tracking`, the channel name is hardcoded to `"com.dispatchdiary.ibt_edition/install"`.
  - Requirement R5 mandates matching main's application ID: `"com.dispatchdiary.dispatch_diary/install"`.

### 1.2 Update Service & Dependency Architecture
- **Current `update_service.dart`**: `flutter_app/lib/data/services/update_service.dart` (lines 1-226):
  - Line 6: `import 'package:open_filex/open_filex.dart';`
  - Lines 173-178: Calls `OpenFilex.open(apkFile.path, type: 'application/vnd.android.package-archive');`
- **Dependencies**:
  - `flutter_app/pubspec.yaml` (line 56) includes `open_filex: ^4.7.0`.
  - Grep search confirms `open_filex` is solely referenced in `update_service.dart`, `pubspec.yaml`, and `pubspec.lock`.

### 1.3 Baseline Analysis & Test Execution
- **Static Analysis**: `dart analyze` executed in `flutter_app` completed with code `0`:
  ```
  Analyzing flutter_app...
  No issues found!
  ```
- **Test Suite**: `flutter test` executed in `flutter_app` completed with code `0`:
  - 8/8 tests passed across 5 test suites:
    1. `test/entry_model_test.dart` (1 test)
    2. `test/preset_engine_test.dart` (4 tests)
    3. `test/update_service_test.dart` (1 test)
    4. `test/whatsapp_export_test.dart` (1 test)
    5. `test/widget_test.dart` (1 test)
- **Feature Branch Test Assets**:
  - `origin/feature/ibt-manifest-tracking` contains 3 additional test files:
    - `test/appsync_manifest_service_test.dart` (5 tests)
    - `test/ibt_manifest_test.dart` (4 tests)
    - `test/ibt_workflow_tdd_test.dart` (1 test)

---

## 2. Logic Chain

1. **Native Intent & Permissions Alignment**:
   - `UpdateService` downloads APK files to `getTemporaryDirectory()`, which maps to internal cache (`/data/user/0/com.dispatchdiary.dispatch_diary/cache`).
   - Android 7.0+ (API 24+) prohibits exposing raw `file://` URIs outside the application package boundary (`FileUriExposedException`).
   - Adding `FileProvider` with `<cache-path name="apk_cache" path="." />` and `<external-cache-path name="external_apk_cache" path="." />` in `file_provider_paths.xml` enables generating secure `content://` URIs via `FileProvider.getUriForFile()`.
   - The authority in `AndroidManifest.xml` (`${applicationId}.fileprovider`) resolves to `com.dispatchdiary.dispatch_diary.fileprovider` at build time, perfectly matching `"${packageName}.fileprovider"` in `MainActivity.kt`.

2. **MethodChannel Contract & Package Discrepancy Resolution**:
   - The feature branch uses `com.dispatchdiary.ibt_edition/install` because its package ID was altered on that branch.
   - For `main`, the Application ID is `com.dispatchdiary.dispatch_diary`.
   - Therefore, both `MainActivity.kt` (`INSTALL_CHANNEL`) and `update_service.dart` (or `update_dialog.dart`) must use `com.dispatchdiary.dispatch_diary/install`.
   - The handler must accept `path: String`, verify `File(path).exists()`, create `Intent.ACTION_VIEW` with `FLAG_GRANT_READ_URI_PERMISSION` and `FLAG_ACTIVITY_NEW_TASK`, and call `startActivity(intent)`.

3. **`open_filex` Elimination**:
   - Replacing `OpenFilex.open` with native `MethodChannel.invokeMethod('installApk', {'path': path})` eliminates the third-party binary dependency, removes background service vulnerabilities, and aligns with modern Android package installer standards.
   - `open_filex` can be safely removed from `pubspec.yaml` without breaking any other module.

4. **Testing & Quality Assurance Baseline**:
   - The current baseline is 100% clean (`0` analyzer diagnostics, `8/8` test pass rate).
   - Any ported IBT components or updated services can be validated against this baseline, and the new tests (`appsync_manifest_service_test.dart`, `ibt_manifest_test.dart`, `ibt_workflow_tdd_test.dart`) should be ported to maintain comprehensive regression coverage.

---

## 3. Caveats

- **Android 8.0+ Unknown Sources Permission**: When `REQUEST_INSTALL_PACKAGES` is invoked for the first time, Android OS prompts the user to "Allow from this source". `MainActivity.kt`'s `startActivity(intent)` handles this by delegating to the OS package installer UI.
- **Cognito OAuth Deep Links**: The intent filter for `myapp` and `dispatchdiary` schemes is necessary for the AWS Cognito browser redirect callback in `aws_login_webview_screen.dart`.
- **Pre-existing Working Directory Edits**: `flutter_app/lib/data/services/update_service.dart` currently contains unstaged edits for release tag filtering. Implementers must ensure clean integration of MethodChannel installer while preserving required update check logic.

---

## 4. Conclusion

The Android native layer and update service requirements are precise and well-isolated:
1. Create `flutter_app/android/app/src/main/res/xml/file_provider_paths.xml`.
2. Add the Cognito OAuth `<intent-filter>` and `FileProvider` `<provider>` to `flutter_app/android/app/src/main/AndroidManifest.xml` (retaining `android:label="Dispatch Diary"`).
3. Implement `installApk` MethodChannel with channel `com.dispatchdiary.dispatch_diary/install` in `flutter_app/android/app/src/main/kotlin/com/dispatchdiary/dispatch_diary/MainActivity.kt`.
4. Update `flutter_app/lib/data/services/update_service.dart` to invoke `com.dispatchdiary.dispatch_diary/install` and remove `open_filex` dependency from `pubspec.yaml`.
5. Existing baseline is green (`dart analyze`: 0 issues, `flutter test`: 8/8 passing).

---

## 5. Verification Method

To verify these changes upon implementation:

1. **Static Analysis**:
   ```bash
   cd flutter_app && dart analyze
   ```
   *Expected result*: 0 issues reported.

2. **Test Suite Execution**:
   ```bash
   cd flutter_app && flutter test
   ```
   *Expected result*: All unit and widget tests pass.

3. **Android Build Verification**:
   ```bash
   cd flutter_app && flutter build apk --debug
   ```
   *Expected result*: Gradle compiles the Kotlin `MainActivity.kt`, processes `AndroidManifest.xml` and `file_provider_paths.xml`, and outputs the APK without manifest merger or Kotlin compilation errors.

4. **Code Inspection**:
   - Verify `flutter_app/android/app/src/main/kotlin/com/dispatchdiary/dispatch_diary/MainActivity.kt` contains `INSTALL_CHANNEL = "com.dispatchdiary.dispatch_diary/install"`.
   - Verify `open_filex` is absent from `flutter_app/pubspec.yaml` and `flutter_app/lib/data/services/update_service.dart`.
