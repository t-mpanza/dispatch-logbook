# Survey Report: Android Native Code for APK Installs & Build/Test Verification (R5)

**Date**: 2026-09-01  
**Investigator**: Explorer 3  
**Working Directory**: `/home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_survey_3`  
**Target Subsystems**: Android Native Configuration, `MainActivity.kt`, `UpdateService`, `pubspec.yaml`, Test Suite (`test/`), Gradle/Kotlin Build Sanity.

---

## Executive Summary

This report delivers a thorough investigation and architectural survey for porting **Requirement R5 (Android Native Code for APK Installs)** and establishing **Build/Test Verification** from `origin/feature/ibt-manifest-tracking` into `main`.

Key takeaways:
1. **MethodChannel Channel Naming**: On `origin/feature/ibt-manifest-tracking`, the channel was renamed to `com.dispatchdiary.ibt_edition/install` because the feature branch changed `applicationId` to `com.dispatchdiary.ibt_edition`. On `main`, the `applicationId` is `com.dispatchdiary.dispatch_diary`. **The MethodChannel name must strictly be `com.dispatchdiary.dispatch_diary/install` on `main`** in both Kotlin (`MainActivity.kt`) and Dart (`update_dialog.dart` / `update_service.dart`).
2. **FileProvider & Permissions**: AndroidManifest requires `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>` (already on main), FileProvider definition `<provider android:name="androidx.core.content.FileProvider" android:authorities="${applicationId}.fileprovider" ...>`, path mapping in `res/xml/file_provider_paths.xml`, and deep link `<intent-filter>` for AWS Cognito OAuth callback schemes (`myapp` and `dispatchdiary`).
3. **Removal of `open_filex`**: The third-party dependency `open_filex: ^4.7.0` is completely replaced by native Kotlin `FileProvider` + `Intent.ACTION_VIEW` via MethodChannel, eliminating fragile intent resolution issues across Android 10–15.
4. **Test Suite Baseline**: Existing standalone unit tests (`entry_model_test.dart`, `preset_engine_test.dart`, `update_service_test.dart`, `whatsapp_export_test.dart`) pass 100% (7/7 tests passed). The port brings 3 new robust TDD test suites (`appsync_manifest_service_test.dart`, `ibt_manifest_test.dart`, `ibt_workflow_tdd_test.dart`) and updated `update_service_test.dart`.
5. **Build Sanity**: Flutter SDK 3.12.2+, AGP 9.0.1, Gradle 9.1.0, and Kotlin 2.3.20 are configured. The `compileSdk` setting in `flutter_app/android/app/build.gradle.kts` should remain `flutter.compileSdkVersion` (avoiding the hardcoded `37` present on the feature branch).

---

## 1. Native Android Configuration & Kotlin Differences

### 1.1 `android/app/src/main/AndroidManifest.xml`

#### Comparison: `main` vs `origin/feature/ibt-manifest-tracking`

| Element / Attribute | `main` Branch | `origin/feature/ibt-manifest-tracking` | Target for Porting on `main` |
|---|---|---|---|
| `application:label` | `android:label="Dispatch Diary"` | `android:label="Dispatch Diary (IBT)"` | Keep `android:label="Dispatch Diary"` |
| `REQUEST_INSTALL_PACKAGES` | Present on `main` (line 15) | Present on feature branch (line 16) | Keep existing permission |
| AWS OAuth Deep Link `<intent-filter>` | **Missing** | **Present** inside `MainActivity` | **Add** to `MainActivity` |
| FileProvider `<provider>` | **Missing** | **Present** inside `<application>` | **Add** to `<application>` |
| Package Visibility (`<queries>`) | Present (https, http, whatsapp, text) | Present | Keep existing `<queries>` block |

#### Required Deep Link Intent Filter
AWS Cognito OAuth flow redirects back to the mobile app using custom URI schemes `myapp://` and `dispatchdiary://`. This must be placed inside the `.MainActivity` `<activity>` tag:

```xml
            <!-- Deep linking for AWS Cognito OAuth redirect -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="myapp" />
                <data android:scheme="dispatchdiary" />
            </intent-filter>
```

#### Required FileProvider Declaration
To avoid `FileUriExposedException` on Android 7.0+ (API 24+) when sharing APK files with the system package installer, Android requires a `FileProvider` that generates a `content://` URI:

```xml
        <!-- FileProvider for sharing APK files with the system installer -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_provider_paths"/>
        </provider>
```

> **Note on Authority**: `${applicationId}.fileprovider` dynamically evaluates to `com.dispatchdiary.dispatch_diary.fileprovider` on `main`.

---

### 1.2 `android/app/src/main/res/xml/file_provider_paths.xml`

This file does not exist on `main` and must be created at `flutter_app/android/app/src/main/res/xml/file_provider_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <!-- For APKs downloaded to the app's cache directory (path_provider getTemporaryDirectory) -->
    <cache-path name="apk_cache" path="." />
    <!-- For APKs in external cache -->
    <external-cache-path name="external_apk_cache" path="." />
</paths>
```

- `<cache-path name="apk_cache" path="." />` grants the provider access to `Context.getCacheDir()` (e.g., `/data/user/0/com.dispatchdiary.dispatch_diary/cache/`).
- `<external-cache-path name="external_apk_cache" path="." />` grants access to `Context.getExternalCacheDir()`.

---

### 1.3 `android/app/src/main/kotlin/com/dispatchdiary/dispatch_diary/MainActivity.kt`

#### Complete Implementation for `main`

```kotlin
package com.dispatchdiary.dispatch_diary

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    // IMPORTANT: Matches main's applicationId "com.dispatchdiary.dispatch_diary"
    private val INSTALL_CHANNEL = "com.dispatchdiary.dispatch_diary/install"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_PATH", "APK path is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file not found at: $path", null)
                            return@setMethodCallHandler
                        }

                        val intent = Intent(Intent.ACTION_VIEW)
                        val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            FileProvider.getUriForFile(
                                this,
                                "${packageName}.fileprovider",
                                file
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            Uri.fromFile(file)
                        }

                        intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
```

#### Detailed Logic Breakdown:
1. **MethodChannel Listener**: Attaches to `flutterEngine.dartExecutor.binaryMessenger` with channel ID `com.dispatchdiary.dispatch_diary/install`.
2. **Argument Validation**: Extracts `'path'` from `call.arguments`. Returns `INVALID_PATH` if missing, or `FILE_NOT_FOUND` if `!file.exists()`.
3. **URI Construction**:
   - For Android 7.0+ (`SDK_INT >= 24`): Uses `FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)`.
   - Legacy fallback (`SDK_INT < 24`): Uses `Uri.fromFile(file)`.
4. **Intent Flags**:
   - `Intent.FLAG_ACTIVITY_NEW_TASK`: Required because `startActivity` is invoked from an application engine context.
   - `Intent.FLAG_GRANT_READ_URI_PERMISSION`: Grants the Android Package Installer temporary read permissions to the content URI generated by FileProvider.
5. **MIME Type**: Explicitly set to `"application/vnd.android.package-archive"`.
6. **Error Reporting**: Returns `INSTALL_FAILED` with `e.message` if `startActivity` fails (e.g. security policy blocking unknown sources).

---

## 2. MethodChannel Interface & Dart Invocation

### 2.1 Replacement of `open_filex`

#### Problem with `open_filex`:
- `open_filex` is a third-party plugin that attempts generic MIME-based file opening.
- It frequently fails on modern Android versions (Android 12/13/14/15) when launching system package installers due to package visibility rules and missing URI grant flags.
- Adding native `installApk` MethodChannel gives 100% direct control over Intent flags, FileProvider authorities, and error reporting without external package bloat.

#### Architecture in Dart:

1. **`UpdateService.downloadApk(apkUrl)`**:
   Returns a `Stream<({double progress, String? filePath, String? error})>`.
   Downloads chunks via `http.Client().send(request)`, streams live progress `(0.0 to 1.0)`, writes to `getTemporaryDirectory()`, and yields final `filePath`.

2. **Native Install Trigger**:
   Can be called via helper method or in `update_dialog.dart`:
   ```dart
   static const _installChannel = MethodChannel('com.dispatchdiary.dispatch_diary/install');

   Future<void> _triggerInstall(String apkPath) async {
     try {
       await _installChannel.invokeMethod('installApk', {'path': apkPath});
     } on PlatformException catch (e) {
       debugPrint('Install channel error: $e');
     }
   }
   ```

3. **`pubspec.yaml`**:
   Remove `open_filex: ^4.7.0` from `dependencies:`.

---

## 3. Test Suite Survey & Test Health

### 3.1 Existing Test Suite Status on `main`

We executed the existing unit tests using `flutter test`:

| Test File | Status | Duration | Description |
|---|---|---|---|
| `test/entry_model_test.dart` | **PASS** | 1.2s | Serialization & deserialization of Entry models to/from Map |
| `test/preset_engine_test.dart` | **PASS** | 1.1s | STOCKS dynamic daily incrementing, NLH preset auto-fill, and preset lookups |
| `test/update_service_test.dart` | **PASS** | 0.8s | UpdateInfo model parsing & semver initialization |
| `test/whatsapp_export_test.dart` | **PASS** | 0.9s | Markdown summary formatting for WhatsApp exports |
| `test/widget_test.dart` | **Compile Error** | N/A | Fails due to un-ported UI syntax in `counter_panel.dart`, `entry_detail_screen.dart`, `new_entry_screen.dart` (owned by R4) |

**Result**: All 4 independent unit test suites passed (7/7 tests passed).

### 3.2 New Test Suites from Feature Branch

The port introduces 3 critical TDD test suites:

1. **`test/appsync_manifest_service_test.dart`** (5 tests):
   - Mocks FlutterSecureStorage via `TestDefaultBinaryMessengerBinding`.
   - Tests Cognito `USER_PASSWORD_AUTH` flow and JWT ID token parsing.
   - Tests AppSync GraphQL `getDeliveryInfo` query execution and JSON mapping into `IbtDocument`.
   - Tests error handling (expired tokens, invalid credentials, unauthorized access).

2. **`test/ibt_manifest_test.dart`** (4 tests):
   - Tests `IbtLineItem` calculations: `remaining`, `overCount`, `isComplete`, `isShort`, `isOverloaded`, `progressPercent`.
   - Tests `IbtDocument` aggregations: `loadedTotal`, `remainingTotal`, `isComplete`, `hasShortages`.
   - Tests `LoadingSheetTrip` integration: `hasIbtDocuments`, `ibtTargetTotal`, `ibtLoadedTotal`, `isTargetReached`.
   - Tests WhatsApp export breakdown with IBT items and shortages (`[✓]`, `[⚠️ Short N]`).

3. **`test/ibt_workflow_tdd_test.dart`** (1 end-to-end test):
   - Uses `InMemoryEntryRepository`.
   - Tests attaching an IBT document to a trip via `LoadingSheetViewModel.attachIbtDocument`.
   - Tests incrementing line item quantities via `LoadingSheetViewModel.updateIbtLineQuantity` and verifies real-time target recalculation.

4. **`test/update_service_test.dart`** (Updated, 4 tests):
   - Tests `isNewerVersion` across semver formats (`v2.1.0-rc1` vs `v2.1.0-rc2`).
   - Tests filtering of mainline vs IBT release candidates with `MockClient`.

---

## 4. Build Configurations & Pitfall Analysis

### 4.1 Gradle & Kotlin Build Sanity

1. **Android Gradle Plugin**: Version `9.0.1` (`settings.gradle.kts`).
2. **Kotlin Gradle Plugin**: Version `2.3.20` (`settings.gradle.kts`).
3. **Gradle Wrapper**: Version `9.1.0-all.zip`.
4. **Compile SDK**:
   - In `flutter_app/android/app/build.gradle.kts`:
     ```kotlin
     compileSdk = flutter.compileSdkVersion
     ```
   - **Pitfall**: On `origin/feature/ibt-manifest-tracking`, this was hardcoded to `compileSdk = 37`. We must preserve `flutter.compileSdkVersion` so Flutter's build toolchain manages SDK versions correctly.
5. **Application ID**:
   - `applicationId = "com.dispatchdiary.dispatch_diary"`
   - Must NOT be changed to `com.dispatchdiary.ibt_edition`.
6. **JVM / Java Version**:
   - Both Java compile options and Kotlin compiler options are set to `JVM_17` / `JavaVersion.VERSION_17`.
7. **`gradle.properties` Warnings**:
   - Gradle emits deprecation notices regarding `android.builtInKotlin=false` and `android.newDsl=false`. These are standard Flutter template defaults in AGP 9.0 and do not prevent successful compilation.

---

## 5. Implementation & Verification Checklist for Implementers

### Android Native Tasks:
- [ ] Create `flutter_app/android/app/src/main/res/xml/file_provider_paths.xml` with `<cache-path>` and `<external-cache-path>`.
- [ ] Update `flutter_app/android/app/src/main/AndroidManifest.xml`:
  - [ ] Add deep link `<intent-filter>` for `myapp` and `dispatchdiary` inside `.MainActivity`.
  - [ ] Add FileProvider `<provider>` with `${applicationId}.fileprovider`.
  - [ ] Keep `android:label="Dispatch Diary"`.
- [ ] Update `flutter_app/android/app/src/main/kotlin/com/dispatchdiary/dispatch_diary/MainActivity.kt`:
  - [ ] Implement `configureFlutterEngine` with `MethodChannel("com.dispatchdiary.dispatch_diary/install")`.
  - [ ] Implement `installApk` handler with `FileProvider.getUriForFile` and `Intent.FLAG_ACTIVITY_NEW_TASK | FLAG_GRANT_READ_URI_PERMISSION`.
- [ ] In `flutter_app/pubspec.yaml`:
  - [ ] Remove `open_filex: ^4.7.0`.
  - [ ] Add `flutter_secure_storage: ^11.0.0` and `webview_flutter: ^4.10.0`.

### Dart / Service Tasks:
- [ ] In `flutter_app/lib/data/services/update_service.dart`:
  - [ ] Remove `import 'package:open_filex/open_filex.dart';`.
  - [ ] Replace `downloadAndInstallApk` with streaming `downloadApk` and native channel invocation.
  - [ ] Update `update_dialog.dart` to invoke `com.dispatchdiary.dispatch_diary/install`.

### Verification Commands:
- [ ] `dart analyze` — reports 0 issues.
- [ ] `flutter test` — all test suites pass.
- [ ] `flutter build apk --debug` — builds successfully without compilation errors.
