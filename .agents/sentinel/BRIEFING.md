# BRIEFING — 2026-09-01T20:48:00+02:00

## Mission
Surgically port the AWS AppSync IBT Manifest Tracking subsystem from origin/feature/ibt-manifest-tracking branch into the main branch of dispatch-logbook without disturbing main's existing theme and UI refactors.

## 🔒 My Identity
- Archetype: sentinel
- Working directory: /home/kiddow/Desktop/Work/Despatch Diary/.agents/sentinel
- Orchestrator: 311e8ea0-1d5f-4056-bb91-f9475206b139
- Victory Auditor: to be spawned on victory claim
- Active Orchestrator: 145dee95-3ffe-49e0-a5b4-a5226aa49fd5 (workspace: .agents/orchestrator_r7)

## 🔒 Key Constraints
- No technical decisions — relay only
- Victory Audit is MANDATORY before reporting completion
- Must record user request to ORIGINAL_REQUEST.md
- Must run crons for progress reporting and liveness check
- Must handle victory audit flow before notifying user

## Routing Decision
- **Route**: General (`teamwork_preview_orchestrator`)
- **Rationale**: Full-featured subsystem port across models, services, AWS auth flow, UI components, surgical screen integrations, and Android native APK install handler with strict verification criteria (dart analyze, flutter test, flutter build apk).

## User Context
- **Last user request**: Port AWS AppSync IBT Manifest Tracking subsystem (R1: Data Models & Services, R2: AWS Auth Flow, R3: IBT UI Components, R4: Surgical UI Integration, R5: Android Native Code for APK Installs) and verify via dart analyze, flutter test, flutter build apk.
- **Pending clarifications**: none
- **Delivered results**: none

## Project Status
- **Phase**: in progress

## Victory Audit Status
- **Triggered**: no
- **Verdict**: pending
- **Retry count**: 0

## Artifact Index
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/ORIGINAL_REQUEST.md — Verbatim user request record
- /home/kiddow/Desktop/Work/Despatch Diary/.agents/PROJECT.md — Master Project Architecture & Milestones

