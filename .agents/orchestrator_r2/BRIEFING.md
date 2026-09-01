# BRIEFING — 2026-09-01T17:32:00Z

## Mission
Surgically port the AWS AppSync IBT Manifest Tracking subsystem from `origin/feature/ibt-manifest-tracking` branch into the `main` branch of `dispatch-logbook` without disturbing main's existing theme, widget sizing, layout improvements, and daylight theme.

## 🔒 My Identity
- Archetype: orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /home/kiddow/Desktop/Work/Despatch Diary/.agents/orchestrator_r2
- Original parent: parent
- Original parent conversation ID: e110da78-18a1-44c5-8ac8-c29c0e63685f

## 🔒 My Workflow
- **Pattern**: Project Orchestration
- **Scope document**: /home/kiddow/Desktop/Work/Despatch Diary/PROJECT.md
1. **Decompose**: Survey codebase & feature branch -> define milestones (M1: Models & Services + Dependencies, M2: AWS Auth Flow, M3: IBT Line Items UI, M4: Surgical UI Integration, M5: Native Android APK Install & Update Service, M6: Comprehensive Verification & E2E Validation)
2. **Dispatch & Execute**:
   - For each milestone: Explorer(s) -> Worker -> Reviewer(s) -> Challenger(s) -> Forensic Auditor -> Gate
3. **On failure**:
   - Retry: nudge stuck agent or re-send task
   - Replace: spawn fresh agent with partial progress
   - Skip: proceed without (only if non-critical)
   - Redistribute: split stuck agent's remaining work
   - Redesign: re-partition decomposition
   - Escalate: report to parent (sub-orchestrators only, last resort)
4. **Succession**: At 16 spawns, write handoff.md, spawn successor
- **Work items**:
  1. Survey & Scope Mapping [in-progress]
  2. M1: Data Models, Services & Dependencies (`ibt_manifest.dart`, `appsync_manifest_service.dart`, `loading_sheet_trip.dart`, `pubspec.yaml`) [pending]
  3. M2: AWS Auth Flow (`aws_login_webview_screen.dart`, `aws_auth_dialog.dart`) [pending]
  4. M3: IBT UI Components (`ibt_line_items_sheet.dart`) [pending]
  5. M4: Surgical UI Integration (`counter_panel.dart`, `new_entry_screen.dart`, `entry_detail_screen.dart`, `loading_sheet_screen.dart`) [pending]
  6. M5: Android Native APK Install & Update Service (`AndroidManifest.xml`, `file_provider_paths.xml`, `MainActivity.kt`, `update_service.dart`) [pending]
  7. M6: Full Verification (`dart analyze`, `flutter test`, `flutter build apk`) [pending]
- **Current phase**: 0 (Survey)
- **Current focus**: Survey and codebase analysis via 3 parallel Explorers

## 🔒 Key Constraints
- NEVER write, modify, or create source code files directly.
- NEVER run build/test commands yourself — require workers to do so.
- NEVER investigate or explore the problem at the code level directly — dispatch Explorers.
- Do NOT overwrite main's existing daylight theme, widget sizing, or layout improvements. Prioritize main's styling.
- Replace `open_filex` with native MethodChannel (`com.dispatchdiary.dispatch_diary/install`).
- Never reuse a subagent after it has delivered its handoff — always spawn fresh.

## Current Parent
- Conversation ID: e110da78-18a1-44c5-8ac8-c29c0e63685f
- Updated: 2026-09-01T17:31:00Z

## Key Decisions Made
- Orchestrator pattern selected: Project Orchestration with Survey phase followed by milestone execution.
- Dispatched 3 parallel Survey Explorers.

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| survey_explorer_1 | teamwork_preview_explorer | Survey Data Models & Services & Dependencies | in-progress | 211468c3-fe81-400b-96d2-3dd0d6d07509 |
| survey_explorer_2 | teamwork_preview_explorer | Survey UI & Styling Grafting | in-progress | c4bc167f-7c0c-44ba-a795-6c9ae1242161 |
| survey_explorer_3 | teamwork_preview_explorer | Survey Native Android & Test Baseline | in-progress | 4f1a7174-89cd-4dae-875c-03040aaaf7ab |

## Succession Status
- Succession required: no
- Spawn count: 3 / 16
- Pending subagents: 211468c3-fe81-400b-96d2-3dd0d6d07509, c4bc167f-7c0c-44ba-a795-6c9ae1242161, 4f1a7174-89cd-4dae-875c-03040aaaf7ab
- Predecessor: none
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: 79b223a0-0ba5-4b33-9fdf-73976bf98e17/task-11
- Safety timer: none
- On succession: kill all timers before spawning successor
- On context truncation: run `manage_task(Action="list")` — re-create if missing

## Artifact Index
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/orchestrator_r2/DISPATCH.md — Incoming user request record
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/ORIGINAL_REQUEST.md — User request record
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/orchestrator_r2/progress.md — Orchestrator liveness and progress tracking
