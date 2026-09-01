# Handoff Report: Explorer Survey 1 (R1 Data Models & Services, R2 AWS Auth Flow)

**Task:** Survey and analyze Requirements R1 and R2 comparing `origin/feature/ibt-manifest-tracking` with `main`.  
**Agent:** Explorer Survey 1  
**Working Directory:** `/home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_survey_1`  
**Target Report:** `/home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_survey_1/survey_report.md`  

---

## 1. Observation

1. **Feature Branch Divergence & Commits:**
   - Merge base with `main` is commit `a28e1fae80bf4b829c10d0bcf6eb55cd67751f8e`.
   - Feature branch `origin/feature/ibt-manifest-tracking` contains 11 commits up to `2efb499` including:
     - `eb8069b` feat: integrate IBT manifest tracking, multi-line counter, and AppSync GraphQL client
     - `05d57a7` feat: add in-app AWS Cognito authentication dialog and restrict IBT section strictly to STOCKS preset
     - `171f0ba` feat: add in-app AWS Web Sign-In with automated OAuth token interception and storage
     - `2e6ff3d` fix(auth): correct Cognito Hosted UI authorization URL flow and user agent for WebView sign-in
     - `9306bbb` fix(appsync): align getDeliveryInfo GraphQL query signature with exact production schema
     - `d570aac` fix(appsync): pass empty strings for optional VTL variables to prevent .substring() crash
2. **Data Models (`ibt_manifest.dart` & `loading_sheet_trip.dart`):**
   - `flutter_app/lib/data/models/ibt_manifest.dart` is a new file defining `IbtLineItem` (with `id`, `description`, `rcsCode`, `sizeId`, `rubberId`, `size`, `rubber`, `targetTotal`, `loadedQuantity`, `remaining`, `overCount`, `isComplete`, `isShort`, `isOverloaded`, `progressPercent`) and `IbtDocument` (with `documentNo`, `total`, `lineItems`, `loadedTotal`, `remainingTotal`, `isComplete`, `hasShortages`).
   - `flutter_app/lib/data/models/loading_sheet_trip.dart` adds `final List<IbtDocument>? ibtDocuments;`, getters `hasIbtDocuments`, `ibtTargetTotal`, `ibtLoadedTotal`, and updates target calculations to use `effectiveTarget = (targetQuantity != null && targetQuantity! > 0) ? targetQuantity! : (hasIbtDocuments ? ibtTargetTotal : 0)`.
3. **AppSync & Auth Services (`appsync_manifest_service.dart`):**
   - `flutter_app/lib/data/services/appsync_manifest_service.dart` implements:
     - AppSync GraphQL Endpoint: `https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql`
     - Cognito domain: `cabsystem.auth.eu-central-1.amazoncognito.com`, IDP endpoint: `https://cognito-idp.eu-central-1.amazonaws.com`, Client ID: `78ikblrgsr8h27197iovkgrro6`
     - Hosted UI authorization URL generator and redirect interceptor for `myapp://` scheme.
     - Direct `USER_PASSWORD_AUTH` login via `AWSCognitoIdentityProviderService.InitiateAuth`.
     - Automatic token refresh via `/oauth2/token` when JWT is within 60s of expiry.
     - GraphQL query `getDeliveryInfo` with safe variables `{ibt: docNo, inv: '', dibt: '', amsInv: ''}`.
4. **Auth UI Screens & Dialogs:**
   - `flutter_app/lib/presentation/screens/aws_login_webview_screen.dart` utilizes `webview_flutter` with custom mobile Chrome User-Agent and interceptor for `myapp://` redirects.
   - `flutter_app/lib/presentation/widgets/aws_auth_dialog.dart` provides a modal bottom sheet with status inspection, 1-tap web sign-in, direct username/password login, manual token pasting, live connection test, and logout.
5. **Dependencies (`pubspec.yaml`):**
   - Adds `flutter_secure_storage: ^11.0.0` and `webview_flutter: ^4.10.0`.
   - Drops `open_filex: ^4.7.0` (which is replaced by native Android `FileProvider` MethodChannel in R5).
6. **Tests Available:**
   - `flutter_app/test/ibt_manifest_test.dart` (224 lines)
   - `flutter_app/test/appsync_manifest_service_test.dart` (212 lines)
   - `flutter_app/test/ibt_workflow_tdd_test.dart` (120 lines)

---

## 2. Logic Chain

1. From **Observation 1 & 2**, `ibt_manifest.dart` is self-contained and purely functional. `LoadingSheetTrip` maps `ibtDocuments` cleanly to JSON in SQLite and Supabase, so porting these files introduces zero database schema friction.
2. From **Observation 3 & 4**, `AppSyncManifestService` and `AwsAuthDialog` / `AwsLoginWebViewScreen` encapsulate the full AWS Cognito authentication and AppSync query lifecycle without coupling to specific theme implementations.
3. From **Observation 5**, the dependency changes in `pubspec.yaml` are clean, modern, and directly satisfy the requirements of R1 and R2 while removing the deprecated `open_filex` dependency.
4. From **Observation 6**, the feature branch contains thorough unit and integration test suites that can be ported directly to verify functionality on `main`.

---

## 3. Caveats

- R3 (IBT UI Line Items Sheet), R4 (UI Surgical Integration into Counter Panel / Entry Detail / Today screens), and R5 (Android Native FileProvider APK installer) are surveyed by other agents and were only examined here in relation to their data model and service contracts.
- In `loading_sheet_viewmodel.dart`, `main`'s `expectedTotal` synchronization must be preserved alongside `ibtTargetTotal` logic.
- In `loading_sheet_trip.dart`, `main`'s `.toUpperCase()` formatting for `reg` should be retained during deserialization.

---

## 4. Conclusion

Requirements R1 and R2 are thoroughly investigated, documented, and ready for immediate porting. All source files, method signatures, GraphQL queries, auth mechanisms, dependencies, and unit tests have been mapped out in detail in `/home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_survey_1/survey_report.md`.

---

## 5. Verification Method

1. **Inspect Survey Report:**
   - Review `/home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_survey_1/survey_report.md`.
2. **Run Unit Tests (after implementing files):**
   - `cd flutter_app && flutter test test/ibt_manifest_test.dart`
   - `cd flutter_app && flutter test test/appsync_manifest_service_test.dart`
   - `cd flutter_app && flutter test test/ibt_workflow_tdd_test.dart`
3. **Static Analysis:**
   - `cd flutter_app && dart analyze` (must yield 0 errors/warnings).
