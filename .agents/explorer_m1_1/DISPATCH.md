## 2026-09-01T18:49:51Z
You are Explorer 1 for Milestone 1: Data Models & Core Services.
Your working directory: /home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_m1_1
Project root: /home/kiddow/Desktop/Work/Despatch Diary

Read:
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/ORIGINAL_REQUEST.md
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/PROJECT.md

Task:
Investigate the differences between `origin/feature/ibt-manifest-tracking` and `main` in `dispatch-logbook` regarding data models and core services:
1. `flutter_app/pubspec.yaml`: additions (`flutter_secure_storage`, `webview_flutter`) and removal (`open_filex`).
2. `flutter_app/lib/data/models/ibt_manifest.dart`: full specification, fields, classes (`IbtLineItem`, `IbtDocument`), serialization, calculations.
3. `flutter_app/lib/data/models/loading_sheet_trip.dart`: surgical additions for `ibtDocuments`, `effectiveTarget`, JSON serialization for SQLite and Supabase, ensuring backward compatibility with main.
4. `flutter_app/lib/data/services/appsync_manifest_service.dart`: Cognito OAuth & USER_PASSWORD_AUTH, JWT decoding, AppSync GraphQL queries, error handling, empty string VTL guards.

Output:
Write a comprehensive technical report to `/home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_m1_1/handoff.md`.
Send a completion message back to the orchestrator when finished.
