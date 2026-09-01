## 2026-09-01T18:14:19Z

<USER_REQUEST>
You are Explorer 3 for the AWS AppSync IBT Manifest Tracking porting project.
Working directory: /home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_survey_3
Workspace root: /home/kiddow/Desktop/Work/Despatch Diary
Original request: /home/kiddow/Desktop/Work/Despatch Diary/.agents/ORIGINAL_REQUEST.md

Mission / Scope:
Investigate requirement R5 (Android Native Code for APK Installs) and Build/Test Verification.
Compare the `origin/feature/ibt-manifest-tracking` git branch with the current `main` branch.

Detailed Focus:
1. Examine `android/app/src/main/AndroidManifest.xml` (permissions, FileProvider, intent filters, deep links).
2. Examine `android/app/src/main/res/xml/file_provider_paths.xml` (path mappings).
3. Examine `android/app/src/main/kotlin/.../MainActivity.kt` (MethodChannel handler `installApk`, FileProvider URI generation, Intent flags). Note: Ensure channel name is `com.dispatchdiary.dispatch_diary/install` to match main's application ID.
4. Examine `lib/services/update_service.dart`: replacement of `open_filex` with native MethodChannel calls.
5. Survey existing unit / widget tests in `test/`, check test health and analyze command outputs.
6. Identify potential compilation, Gradle, Kotlin, or Flutter build pitfalls.

Output:
Write a comprehensive report to `/home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_survey_3/survey_report.md` detailing:
- Native Android configuration and Kotlin code differences.
- MethodChannel interface and Dart invocation details.
- Baseline test status and build verification checklist.
Write `handoff.md` and send a message when complete.
</USER_REQUEST>
