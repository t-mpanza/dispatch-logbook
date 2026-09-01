## 2026-09-01T18:09:24Z
You are the Project Orchestrator for this task.

Working directory: /home/kiddow/Desktop/Work/Despatch Diary/.agents/orchestrator_r5
Workspace root: /home/kiddow/Desktop/Work/Despatch Diary
User request reference: /home/kiddow/Desktop/Work/Despatch Diary/.agents/ORIGINAL_REQUEST.md

Mission:
Surgically port the AWS AppSync IBT Manifest Tracking subsystem from the `origin/feature/ibt-manifest-tracking` branch into the `main` branch of `dispatch-logbook`. The implementation must follow the detailed implementation plan to avoid disturbing main's existing theme and UI refactors.

Requirements:
- R1. Implement Data Models and Services: Port `ibt_manifest.dart`, `appsync_manifest_service.dart`, and selectively update `loading_sheet_trip.dart` to support IBT documents. Add `flutter_secure_storage` and `webview_flutter` to `pubspec.yaml` and remove `open_filex`.
- R2. Implement AWS Auth Flow: Port `aws_login_webview_screen.dart` and `aws_auth_dialog.dart` to handle Cognito OAuth and token persistence.
- R3. Port IBT UI Components: Port `ibt_line_items_sheet.dart` verbatim.
- R4. Surgical UI Integration: Carefully graft IBT-specific logic into `counter_panel.dart`, `new_entry_screen.dart`, `entry_detail_screen.dart`, and `loading_sheet_screen.dart`. You must NOT overwrite main's existing daylight theme, widget sizing, or layout improvements. Prioritize main's styling over the feature branch's styling.
- R5. Update Android Native Code for APK Installs: Update `AndroidManifest.xml` and add `file_provider_paths.xml` for deep linking. In `MainActivity.kt`, implement the `installApk` MethodChannel handler using the native `FileProvider` approach from the feature branch, but name the channel `com.dispatchdiary.dispatch_diary/install` to match main's application ID. Completely replace the `open_filex` package usage with this native channel approach in `update_service.dart`.

Acceptance Criteria:
- `dart analyze` reports 0 issues.
- `flutter test` passes all existing test suites without regressions.
- The app compiles successfully via `flutter build apk`.
