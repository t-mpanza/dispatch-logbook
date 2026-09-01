# Technical Report: Data Models & Core Services (Milestone 1)

**Working Directory**: `/home/kiddow/Desktop/Work/Despatch Diary/.agents/explorer_m1_1`  
**Target Milestone**: Milestone 1: Data Models & Core Services  
**Branches Examined**: `origin/feature/ibt-manifest-tracking` vs `origin/main` (and local working directory)  
**Timestamp**: 2026-09-01T18:52:00Z  

---

## 1. Observation

### 1.1 `flutter_app/pubspec.yaml`
Comparing `origin/main` with `origin/feature/ibt-manifest-tracking`:
```diff
--- a/flutter_app/pubspec.yaml
+++ b/flutter_app/pubspec.yaml
@@ -16,7 +16,7 @@
-version: 2.0.0+1
+version: 2.1.0-rc7+7
@@ -53,7 +53,8 @@
   photo_view: ^0.15.0
   http: ^1.2.0
   package_info_plus: ^10.2.1
-  open_filex: ^4.7.0
+  flutter_secure_storage: ^11.0.0
+  webview_flutter: ^4.10.0
```
- **Added**:
  - `flutter_secure_storage: ^11.0.0`: Used for hardware-backed, encrypted storage of AWS Cognito JWT tokens (`appsync_access_token`, `appsync_id_token`, `appsync_refresh_token`) on Android Keystore and iOS Keychain.
  - `webview_flutter: ^4.10.0`: Used by `AwsLoginWebViewScreen` to render the AWS Cognito Hosted UI OAuth2 login screen, handle redirects to `myapp://`, and extract tokens/codes.
- **Removed**:
  - `open_filex: ^4.7.0`: Deprecated and removed in favor of native Android `FileProvider` + `MainActivity.kt` MethodChannel (`com.dispatchdiary.dispatch_diary/install`) for installing downloaded APK updates without external package dependencies.
- **Version Bump**:
  - `2.0.0+1` -> `2.1.0-rc7+7`.

---

### 1.2 `flutter_app/lib/data/models/ibt_manifest.dart`
This file is newly introduced in `origin/feature/ibt-manifest-tracking` (132 lines). It contains pure Dart models representing Inter-Branch Transfer (IBT) manifest documents and individual line items.

#### Class: `IbtLineItem`
- **Fields**:
  - `final String id;` — Unique identifier (convention: `${docNo}_line_${index}`).
  - `final String description;` — Raw item description (e.g. `'315/80R22.5 RD2+'`).
  - `final String? rcsCode;` — RCS catalog code (e.g. `'LLS039'`).
  - `final int? sizeId;` — Backend Master Size ID (e.g. `22`).
  - `final int? rubberId;` — Backend Master Rubber Compound ID (e.g. `12`).
  - `final String? size;` — Normalized size string (e.g. `'315/80R22.5'`).
  - `final String? rubber;` — Normalized rubber compound string (e.g. `'RD2+'`).
  - `final int targetTotal;` — Planned tyre quantity for this specific line item.
  - `final int loadedQuantity;` — Current count of tyres loaded/scanned for this line (defaults to `0`).
- **Calculated Properties & Quotas**:
  - `int get remaining => (targetTotal - loadedQuantity).clamp(0, targetTotal);` — Tyres still needed to meet quota.
  - `int get overCount => (loadedQuantity - targetTotal).clamp(0, loadedQuantity);` — Overloaded excess count.
  - `bool get isComplete => targetTotal > 0 && loadedQuantity >= targetTotal;` — Quota satisfied or exceeded.
  - `bool get isShort => targetTotal > 0 && loadedQuantity < targetTotal;` — Quota underfilled.
  - `bool get isOverloaded => targetTotal > 0 && loadedQuantity > targetTotal;` — Quota exceeded.
  - `double get progressPercent => targetTotal > 0 ? (loadedQuantity / targetTotal).clamp(0.0, 1.0) : 0.0;` — Ratio from 0.0 to 1.0.
- **Methods**:
  - `IbtLineItem copyWith({...})` — Immutable state updates.
  - `Map<String, dynamic> toMap()` — Serialization to Map.
  - `factory IbtLineItem.fromMap(Map<String, dynamic> map)` — Safe deserialization with fallback defaults (`?.toString()`, `(map['targetTotal'] as num?)?.toInt() ?? 0`).

#### Class: `IbtDocument`
- **Fields**:
  - `final String documentNo;` — IBT document number (e.g. `'IBT119512'`).
  - `final int total;` — Overall manifest document tyre quota.
  - `final List<IbtLineItem> lineItems;` — List of constituent line items.
- **Calculated Properties**:
  - `int get loadedTotal => lineItems.fold(0, (sum, item) => sum + item.loadedQuantity);` — Sum of `loadedQuantity` across all lines.
  - `int get remainingTotal => (total - loadedTotal).clamp(0, total);` — Document-level remaining tyres.
  - `bool get isComplete => total > 0 && loadedTotal >= total;` — Overall document completion flag.
  - `bool get hasShortages => lineItems.any((item) => item.isShort);` — Checks if any line has an unfulfilled quota.
- **Methods**:
  - `IbtDocument copyWith({...})` — Immutable state copy.
  - `Map<String, dynamic> toMap()` — Serializes `lineItems` via `lineItems.map((e) => e.toMap()).toList()`.
  - `factory IbtDocument.fromMap(Map<String, dynamic> map)` — Deserializes `lineItems` from `List<dynamic>` into `List<IbtLineItem>`.

---

### 1.3 `flutter_app/lib/data/models/loading_sheet_trip.dart`
Surgical modifications were made to `LoadingSheetTrip` to seamlessly attach IBT documents while maintaining complete backwards compatibility with existing standalone trips and older database records.

#### Key Additions & Refactorings:
1. **Model Import**:
   ```dart
   import 'ibt_manifest.dart';
   ```
2. **Field Addition**:
   ```dart
   final List<IbtDocument>? ibtDocuments;
   ```
3. **Constructor Parameter**:
   ```dart
   const LoadingSheetTrip({
     // ... existing fields ...
     this.ibtDocuments,
   });
   ```
4. **Helper Getters**:
   ```dart
   bool get hasIbtDocuments => ibtDocuments != null && ibtDocuments!.isNotEmpty;

   int get ibtTargetTotal =>
       ibtDocuments?.fold<int>(0, (sum, doc) => sum + doc.total) ?? 0;

   int get ibtLoadedTotal =>
       ibtDocuments?.fold<int>(0, (sum, doc) => sum + doc.loadedTotal) ?? 0;
   ```
5. **Effective Target Calculation Grafting**:
   Previously, calculated properties checked `targetQuantity` directly. If `targetQuantity` was null or 0, targets were treated as unset.
   With IBT support, `effectiveTarget` is derived:
   ```dart
   final effectiveTarget = (targetQuantity != null && targetQuantity! > 0)
       ? targetQuantity!
       : (hasIbtDocuments ? ibtTargetTotal : 0);
   ```
   Refactored getters:
   - `remainingTyres`: `if (effectiveTarget <= 0) return 0; final diff = effectiveTarget - quantityLoaded; return diff > 0 ? diff : 0;`
   - `overCount`: `if (effectiveTarget <= 0) return 0; final diff = quantityLoaded - effectiveTarget; return diff > 0 ? diff : 0;`
   - `progressPercent`: `if (effectiveTarget <= 0) return null; return (quantityLoaded / effectiveTarget).clamp(0.0, 1.0);`
   - `isTargetReached`: `return effectiveTarget > 0 && quantityLoaded >= effectiveTarget;`
   - `isTargetExceeded`: `return effectiveTarget > 0 && quantityLoaded > effectiveTarget;`
6. **Serialization & Deserialization Compatibility**:
   - `toMap()`:
     ```dart
     'ibtDocuments': ibtDocuments?.map((e) => e.toMap()).toList(),
     ```
   - `fromMap(Map<String, dynamic> map)`:
     ```dart
     List<IbtDocument>? ibts;
     if (map['ibtDocuments'] != null) {
       final rawList = map['ibtDocuments'] as List<dynamic>;
       ibts = rawList
           .map((e) => IbtDocument.fromMap(e as Map<String, dynamic>))
           .toList();
     }
     ```
   - Defensive Type Casting: `id`, `entryId`, `reg`, `driverName`, `tripId`, `note` use `?.toString()`, `createdAt` uses `(map['createdAt'] as num?)?.toInt() ?? 0`, and `isManual` handles both `1` (SQLite integer) and `true` (Supabase boolean).

---

### 1.4 `flutter_app/lib/data/services/appsync_manifest_service.dart`
A new comprehensive service (544 lines) managing AWS Cognito authentication, token lifecycle, and AppSync GraphQL communication.

#### Key Components:
1. **Constants**:
   - `endpoint`: `'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql'`
   - `cognitoDomain`: `'cabsystem.auth.eu-central-1.amazoncognito.com'`
   - `cognitoIdpEndpoint`: `'https://cognito-idp.eu-central-1.amazonaws.com'`
   - `clientId`: `'78ikblrgsr8h27197iovkgrro6'`
   - `redirectUri`: `'myapp://'`
   - Secure Storage Keys: `_keyAccessToken = 'appsync_access_token'`, `_keyIdToken = 'appsync_id_token'`, `_keyRefreshToken = 'appsync_refresh_token'`.

2. **Master Lookup Tables**:
   - `sizeMaster`: Mappings from size IDs to tyre size designations (e.g. `22: '315/80R22.5'`, `45: '11R22.5'`, `30: '295/80R22.5'`, `38: '275/70R22.5'`, `15: '385/65R22.5'`, `12: '12R22.5'`, `10: '10.00R20'`).
   - `rubberMaster`: Mappings from rubber compound IDs to compound trade names (e.g. `12: 'RD2+'`, `14: 'M90L'`, `18: 'MM84'`, `25: 'M3'`, `31: 'SP571'`, `40: 'K-Max S'`, `52: 'X Multiway 3D'`).

3. **Cognito Authentication Flows**:
   - **Hosted UI (OAuth2)**:
     - `getHostedUiAuthorizeUrl({bool tokenFlow = true})`: Generates the authorize URL (`response_type=token` for implicit token flow or `code` for code grant flow, with scopes `email openid profile aws.cognito.signin.user.admin`).
     - `handleRedirectUrl(String url, {http.Client? client})`: Intercepts redirect URLs matching scheme `myapp://` (or `localhost` / `callback`).
       - If URL fragment `#id_token=...` is present (implicit flow), extracts `id_token`, `access_token`, and `refresh_token` and saves directly.
       - If URL query parameter `code=...` is present (code grant), invokes `exchangeCodeForTokens`.
       - Fallback checks for query parameters with tokens.
     - `exchangeCodeForTokens(String code, {http.Client? client})`: POST to `https://$cognitoDomain/oauth2/token` with `grant_type=authorization_code`, saving returned tokens.
   - **Direct Credentials Auth (`USER_PASSWORD_AUTH`)**:
     - `loginWithCredentials({required String username, required String password, http.Client? client})`:
       - Posts payload `{"AuthFlow": "USER_PASSWORD_AUTH", "ClientId": clientId, "AuthParameters": {"USERNAME": username.trim(), "PASSWORD": password}}` to `cognitoIdpEndpoint` with header `X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth`.
       - Validates response: handles error responses (`NotAuthorizedException`, `UserNotFoundException`, `PasswordResetRequiredException`), extracts `AuthenticationResult` (`IdToken`, `AccessToken`, `RefreshToken`), and persists to `FlutterSecureStorage`.
       - Returns `AwsUserInfo`.

4. **JWT Decoding & Token Refresh Lifecycle**:
   - `getValidIdToken({http.Client? client})`: Reads `_keyIdToken`, decodes Base64Url JWT payload (`base64Url.decode(base64Url.normalize(parts[1]))`), extracts `exp` timestamp.
   - If `exp < now + 60` (expired or expiring within 60 seconds), automatically calls `refreshAccessToken(client: client)`.
   - `refreshAccessToken({http.Client? client})`: POSTs to Cognito `/oauth2/token` with `grant_type: refresh_token`, updating stored ID token and access token.

5. **AppSync GraphQL Query & Empty String VTL Crash Guards**:
   - `fetchIbtDocument(String documentNoInput, {http.Client? client, String? explicitIdToken})`:
     - Normalizes input: trims, converts to uppercase, and automatically prepends `IBT` if the input is purely numeric (e.g. `'119512'` -> `'IBT119512'`).
     - Checks authentication: requires valid ID token, throwing descriptive exception if missing.
     - GraphQL Query:
       ```graphql
       query MyQuery($inv: String, $ibt: String, $dibt: String, $amsInv: String) {
         getDeliveryInfo(getDeliveryInfo: {amsInv: $amsInv, dibt: $dibt, ibt: $ibt, inv: $inv}) {
           inv { ... }
           dibt { ... }
           ibt {
             description
             rcs_code
             size_id
             rubber_id
             total
           }
         }
       }
       ```
     - **Empty String VTL Crash Guard**: The AppSync Velocity Template Language (VTL) resolver on AWS backend expects all 4 parameters (`ibt`, `inv`, `dibt`, `amsInv`) to be non-null strings. If any parameter is omitted or `null`, the VTL template crashes with a 500 error.
       Therefore, `variables` explicitly supplies empty strings for unused inputs:
       ```json
       {
         "variables": {
           "ibt": docNo,
           "inv": "",
           "dibt": "",
           "amsInv": ""
         }
       }
       ```
     - Headers: `Authorization: Bearer $idToken`, `Content-Type: application/json`.
     - Validates HTTP 200 and checks for GraphQL `errors` array.
     - Extracts `ibt` list: `resData['data']['getDeliveryInfo']['ibt']`.

6. **Parsing & Heuristic Fallbacks**:
   - `parseIbtLines(String docNo, List<dynamic> rawLines)`:
     - Iterates line items: maps `size_id` via `sizeMaster[sizeId]`, falling back to `extractSize(description)`.
     - Maps `rubber_id` via `rubberMaster[rubberId]`, falling back to `extractRubber(description)`.
     - `extractSize`: Uses regex `\d{3}/\d{2}R\d{2}\.?\d?|\d{1,2}R\d{2}\.?\d?` (matches e.g. `315/80R22.5`, `11R22.5`, `12R22.5`).
     - `extractRubber`: Uses regex `(RD2\+|M90L|MM84|M3|SP571|K-Max|Multiway)` (case-insensitive).
     - Aggregates `totalCount` and returns `IbtDocument(documentNo: docNo, total: totalCount, lineItems: items)`.

7. **Diagnostics**:
   - `testConnection({http.Client? client})`: Sends probe query `{ibt: "IBT000000"}` to test GraphQL connectivity and token validity.
   - `logout()`: Clears all three secure storage keys.

---

## 2. Logic Chain

1. **Dependency Modernization**:
   - *Observation*: `pubspec.yaml` added `flutter_secure_storage` and `webview_flutter`, and removed `open_filex`.
   - *Reasoning*: Authentication with AWS Cognito requires persistent, encrypted local storage for JWT tokens, and an interactive in-app browser for Hosted UI redirects. Removing `open_filex` in favor of a native Android `FileProvider` + MethodChannel prevents APK installation failures on modern Android API levels (Android 11+ package visibility rules).

2. **Decoupled, Pure Data Modeling**:
   - *Observation*: `ibt_manifest.dart` is completely decoupled from Flutter UI and third-party frameworks, consisting purely of standard Dart classes, getters, and serialization maps.
   - *Reasoning*: Keeping `IbtLineItem` and `IbtDocument` as pure Dart immutable models allows them to be shared seamlessly across the presentation layer, background repositories, export services (PDF & WhatsApp), and unit tests without widget binding overhead.

3. **Non-Breaking Extension of `LoadingSheetTrip`**:
   - *Observation*: `loading_sheet_trip.dart` introduces `ibtDocuments` as an optional nullable list and abstracts target computation via `effectiveTarget`.
   - *Reasoning*: Existing trips (such as manual truck loads or standalone runs created before IBT integration) have `ibtDocuments == null`. By defining `effectiveTarget` to prioritize `targetQuantity` when explicitly set and fallback to `ibtTargetTotal` when `ibtDocuments` is present, all existing calculations (`remainingTyres`, `overCount`, `progressPercent`, `isTargetReached`, `isTargetExceeded`) continue to function identically for both legacy and IBT trips.

4. **Zero-Migration Database Storage**:
   - *Observation*: In SQLite and Supabase, `loadingSheetTrips` is stored as a JSON column inside the `entries` table.
   - *Reasoning*: Serializing `ibtDocuments` inside the existing trip JSON map (`toMap` / `fromMap`) means the database schema does not need altering. SQLite and Supabase store the nested structures transparently.

5. **AWS AppSync VTL Resolver Compatibility**:
   - *Observation*: `AppSyncManifestService.fetchIbtDocument` explicitly passes `inv: ""`, `dibt: ""`, and `amsInv: ""` alongside `ibt: docNo`.
   - *Reasoning*: The backend Velocity Template Language (VTL) resolver crashes when any of the expected variable keys are null or absent. Passing empty strings satisfies the backend template requirements while retrieving the manifest data for the specified IBT.

6. **Dual Authentication Support & Resilient Parsing**:
   - *Observation*: `AppSyncManifestService` supports both Cognito Hosted UI OAuth2 redirect flows (in-app webview) and direct `USER_PASSWORD_AUTH` credentials login, coupled with JWT expiry checks and master dictionary lookups.
   - *Reasoning*: Field operators can either log in via enterprise SSO / Hosted UI or directly enter their Cognito username and password in the settings dialog. Token expiration is handled automatically via refresh tokens, and size/compound IDs from the ERP database are mapped to human-readable strings with regex fallbacks.

---

## 3. Caveats

1. **No Backend Scheme Migrations Needed**: Because SQLite stores trips as a serialized JSON string in the `entries` table and Supabase uses a JSONB column, no SQL migration scripts are required for SQLite or Supabase.
2. **Cognito Hosted UI Scopes**: The OAuth URL requires `scope=email+openid+profile+aws.cognito.signin.user.admin`. If Cognito App Client settings on AWS alter these allowed scopes, the Hosted UI will display an `invalid_scope` error.
3. **Regex Master Fallbacks**: If new tyre sizes (e.g. non-standard low-profile sizes) or new rubber compounds are introduced in the ERP without updating `sizeMaster` and `rubberMaster`, `extractSize` and `extractRubber` will attempt regex extraction from the description string; unparsed values will retain `null` for size/rubber while preserving the full `description`.

---

## 4. Conclusion

The data models and core services for Milestone 1 are completely specified and verified:
1. `pubspec.yaml` contains `flutter_secure_storage: ^11.0.0` and `webview_flutter: ^4.10.0`, with `open_filex` removed.
2. `ibt_manifest.dart` cleanly defines `IbtLineItem` and `IbtDocument` with comprehensive calculation getters, `copyWith`, and map serialization.
3. `loading_sheet_trip.dart` safely extends `LoadingSheetTrip` with `ibtDocuments`, `hasIbtDocuments`, `ibtTargetTotal`, `ibtLoadedTotal`, `effectiveTarget` computation logic, and robust backward-compatible JSON serialization.
4. `appsync_manifest_service.dart` provides production-grade AWS Cognito authentication (`USER_PASSWORD_AUTH` and OAuth Hosted UI), JWT decoding with automated refresh, AppSync GraphQL queries with empty-string VTL guards, master table lookups, and connection testing.

---

## 5. Verification Method

To independently verify all data models, services, and integration workflows:

1. **Run Dedicated Milestone 1 Unit Test Suites**:
   ```bash
   cd flutter_app
   flutter test test/ibt_manifest_test.dart test/appsync_manifest_service_test.dart test/ibt_workflow_tdd_test.dart
   ```
   - `test/ibt_manifest_test.dart`: Validates `IbtLineItem` calculations (`remaining`, `overCount`, `progressPercent`, `isComplete`, `isShort`, `isOverloaded`), `IbtDocument` quota aggregations, `LoadingSheetTrip` JSON roundtrip serialization inside `Entry`, and WhatsApp export formatting.
   - `test/appsync_manifest_service_test.dart`: Validates authentication error handling, `USER_PASSWORD_AUTH` InitiateAuth API calls, JWT claim parsing, GraphQL query execution with Bearer tokens and empty-string VTL parameters, and error responses.
   - `test/ibt_workflow_tdd_test.dart`: Validates attaching IBT documents to trips, stepping line item quantities (`+13`, `+40`), progress calculation updates, and complete workflow state transitions.

2. **Run Static Analysis**:
   ```bash
   cd flutter_app
   flutter analyze lib/data/models/ibt_manifest.dart lib/data/models/loading_sheet_trip.dart lib/data/services/appsync_manifest_service.dart
   ```
   Ensure 0 issues / warnings reported.
