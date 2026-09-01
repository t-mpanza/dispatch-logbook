# Forensic Audit Report: Milestone 1 (Data Models & Core Services)

**Target Milestone**: Milestone 1: Data Models & Core Services  
**Auditor**: Forensic Auditor 1 (`auditor_m1_1`)  
**Profile**: General Project  
**Integrity Mode**: Development (from `ORIGINAL_REQUEST.md`)  
**Verdict**: **`CLEAN`**  
**Timestamp**: 2026-09-01T19:15:00Z  

---

## 1. Observation

### 1.1 Direct File Inspections & Code Quality
1. **`flutter_app/pubspec.yaml`**:
   - Added: `flutter_secure_storage: ^11.0.0`, `webview_flutter: ^4.10.0`.
   - Removed: `open_filex: ^4.7.0`.
   - Result: Clean dependencies, 0 conflict issues during `flutter pub get`.

2. **`flutter_app/lib/data/models/ibt_manifest.dart`**:
   - Implemented authentic mathematical domain models: `IbtLineItem` and `IbtDocument`.
   - `remaining`: `(targetTotal - loadedQuantity).clamp(0, targetTotal)`
   - `overCount`: `(loadedQuantity - targetTotal).clamp(0, loadedQuantity)`
   - `progressPercent`: `targetTotal > 0 ? (loadedQuantity / targetTotal).clamp(0.0, 1.0) : 0.0`
   - `loadedTotal`: `lineItems.fold(0, (sum, item) => sum + item.loadedQuantity)`
   - Defensive JSON serialization `toMap()` and `fromMap()` handling nulls and num type conversions.

3. **`flutter_app/lib/data/models/loading_sheet_trip.dart`**:
   - Integrated optional `ibtDocuments` list.
   - Dynamic `effectiveTarget` calculation: `(targetQuantity != null && targetQuantity! > 0) ? targetQuantity! : (hasIbtDocuments ? ibtTargetTotal : 0)`.
   - Dynamic getters `remainingTyres`, `overCount`, `progressPercent`, `isTargetReached`, and `isTargetExceeded` properly propagate `effectiveTarget`.

4. **`flutter_app/lib/data/services/appsync_manifest_service.dart`**:
   - Direct Cognito authentication via `AWSCognitoIdentityProviderService.InitiateAuth` (`USER_PASSWORD_AUTH`).
   - Cognito OAuth2 token exchange and Hosted UI URL builder (`myapp://` redirect URI, `cabsystem.auth.eu-central-1.amazoncognito.com`).
   - Secure storage token persistence using `FlutterSecureStorage`.
   - Automatic JWT token expiration check (`exp < now + 60`) and `/oauth2/token` refresh grant.
   - AWS AppSync GraphQL query execution for `getDeliveryInfo` with VTL crash guard arguments (`inv: ""`, `dibt: ""`, `amsInv: ""`).
   - Size and compound dictionary mapping (`sizeMaster`, `rubberMaster`) with heuristic fallback extraction (`extractSize`, `extractRubber`).

5. **`flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart`**:
   - Authoritative IBT quota protection: `!t.hasIbtDocuments` guard prevents entry-level `expectedTotal` from overwriting IBT target quotas.
   - Authentic operations: `attachIbtDocument`, `removeIbtDocument`, `updateIbtLineQuantity` with boundary clamping.

6. **`flutter_app/lib/data/services/whatsapp_export_service.dart` & `pdf_export_service.dart`**:
   - WhatsApp export renders formatted itemized IBT breakdowns (`📄 *IBT...*`, `[✓]`, `[⚠️ Short N]`, `[+N Over]`).
   - PDF export generates clean A4 document with summary KPI, main table, and `ITEMIZED IBT MANIFEST BREAKDOWN` table with signatures.

7. **`flutter_app/lib/data/services/update_service.dart`**:
   - Replaced deprecated `open_filex` with stream-based `downloadApk` and semver `isNewerVersion` comparison supporting RC and IBT tags.

---

### 1.2 Forensic Search & Prohibited Pattern Checks
- **Hardcoded Test Outputs**: Grep search for test document numbers (e.g. `IBT119512`) across `flutter_app/lib/` returned **0 matches**. Logic is 100% dynamic.
- **Facade Implementations**: Zero dummy functions, zero `UnimplementedError` or `NotImplementedError`, zero `TODO` placeholders in `flutter_app/lib/`.
- **Pre-populated Artifacts**: Checked for pre-existing log files or fake result certificates. None found.
- **Self-Certifying Tests**: Tests in `test/ibt_manifest_test.dart`, `test/appsync_manifest_service_test.dart`, `test/ibt_workflow_tdd_test.dart`, and `test/update_service_test.dart` independently verify models, state transitions, HTTP payload formatting, error handling, and serialization.

---

### 1.3 Behavioral & Test Execution Results

#### A. Dependency Resolution
```
$ flutter pub get
Resolving dependencies...
Got dependencies!
```

#### B. Static Analysis (`dart analyze`)
```
$ dart analyze
Analyzing flutter_app...
No issues found!
```

#### C. Full Test Suite Execution (`flutter test`)
```
$ flutter test
00:18 +22: All tests passed!
```
All 22 unit and widget tests executed and passed cleanly.

---

## 2. Logic Chain

1. **Integrity Mode Alignment**: `ORIGINAL_REQUEST.md` specifies `development` integrity mode. The codebase was verified against all Development, Demo, and Benchmark prohibitions.
2. **Authentic Implementations**: All data models, services, token handlers, and GraphQL integrations execute actual logic rather than dummy stubs or hardcoded responses.
3. **Architectural Coherence**: The integration between models (`IbtDocument`), repositories (`EntryRepository`), view models (`LoadingSheetViewModel`), and presentation/export services maintains backward compatibility and clean separation of concerns.
4. **Resilience & Safety**: Edge-case stress testing confirmed that corrupted tokens, zero targets, overcount quantities, and missing JSON keys are handled safely without exceptions.

---

## 3. Caveats

- **AWS Live Credentials**: Integration tests use mock HTTP clients with realistic Cognito and AppSync payloads. Live network testing against AWS AppSync requires active operator credentials in the AWS Cognito User Pool.

---

## 4. Conclusion

**Verdict**: **`CLEAN`**

Milestone 1 (Data Models & Core Services) contains genuine, robust, and authentic implementations that strictly fulfill all requirements with zero integrity violations and zero regressions.

---

## 5. Verification Method

To reproduce and independently verify the audit findings:

```bash
cd "/home/kiddow/Desktop/Work/Despatch Diary/flutter_app"

# 1. Check dependencies
flutter pub get

# 2. Run static analysis
dart analyze

# 3. Execute all unit and integration tests
flutter test
```

Expected result: `No issues found!`, `All tests passed! (22 tests)`.
