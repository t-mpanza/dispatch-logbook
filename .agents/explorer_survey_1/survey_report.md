# Survey Report: Requirements R1 (Data Models & Services) and R2 (AWS Auth Flow)

**Project:** AWS AppSync IBT Manifest Tracking Subsystem Port  
**Target Repository:** `dispatch-logbook` (`main` branch)  
**Source Branch:** `origin/feature/ibt-manifest-tracking` (Commit: `2efb499`)  
**Base Divergence:** `a28e1fae80bf4b829c10d0bcf6eb55cd67751f8e`  
**Author:** Explorer Survey 1  
**Date:** 2026-09-01  

---

## Executive Summary

This report delivers a comprehensive investigation of **Requirement R1 (Data Models & Services)** and **Requirement R2 (AWS Auth Flow)** for porting the AWS AppSync Inter-Branch Transfer (IBT) Manifest Tracking feature from `origin/feature/ibt-manifest-tracking` into `main`.

The feature branch introduces:
1. **IBT Data Models** (`IbtLineItem`, `IbtDocument`) providing granular line-item tracking, target quantities, loaded counts, shortages, and overshoots.
2. **Trip Model Extension** (`LoadingSheetTrip.ibtDocuments`) integrating IBT tracking into the daily loading sheet with automatic dynamic target calculations (`effectiveTarget`), full SQLite JSON persistence, and Supabase synchronization.
3. **AWS AppSync & Cognito Service** (`AppSyncManifestService`) supporting OAuth2 Hosted UI Web sign-in, direct Cognito username/password authentication, JWT expiration inspection, refresh token rotation, and resilient GraphQL query execution.
4. **Cognito Auth UI Components** (`AwsLoginWebViewScreen`, `AwsAuthDialog`) providing seamless in-app authentication, live connection testing, and secure credential storage.
5. **Dependency Updates in `pubspec.yaml`** adding `flutter_secure_storage` and `webview_flutter` while cleanly dropping `open_filex` in favor of native Android install handlers.

---

## 1. Requirement R1: Data Models & Services

### 1.1 `lib/data/models/ibt_manifest.dart` (New File)
- **Path:** `flutter_app/lib/data/models/ibt_manifest.dart`
- **Dependencies:** Pure Dart (`dart:core`), no external package imports.
- **Classes Defined:**
  - `IbtLineItem`: Represents an individual tyre product line within an IBT document.
  - `IbtDocument`: Represents the root IBT document containing a document number, overall quota, and line items.

#### Class Structure & Methods
```dart
class IbtLineItem {
  final String id;
  final String description;
  final String? rcsCode;
  final int? sizeId;
  final int? rubberId;
  final String? size;
  final String? rubber;
  final int targetTotal;
  final int loadedQuantity;

  const IbtLineItem({
    required this.id,
    required this.description,
    this.rcsCode,
    this.sizeId,
    this.rubberId,
    this.size,
    this.rubber,
    required this.targetTotal,
    this.loadedQuantity = 0,
  });

  // Computed Properties:
  int get remaining => (targetTotal - loadedQuantity).clamp(0, targetTotal);
  int get overCount => (loadedQuantity - targetTotal).clamp(0, loadedQuantity);
  bool get isComplete => targetTotal > 0 && loadedQuantity >= targetTotal;
  bool get isShort => targetTotal > 0 && loadedQuantity < targetTotal;
  bool get isOverloaded => targetTotal > 0 && loadedQuantity > targetTotal;
  double get progressPercent => targetTotal > 0 ? (loadedQuantity / targetTotal).clamp(0.0, 1.0) : 0.0;

  IbtLineItem copyWith({...});
  Map<String, dynamic> toMap();
  factory IbtLineItem.fromMap(Map<String, dynamic> map);
}

class IbtDocument {
  final String documentNo;
  final int total;
  final List<IbtLineItem> lineItems;

  const IbtDocument({
    required this.documentNo,
    required this.total,
    required this.lineItems,
  });

  // Computed Properties:
  int get loadedTotal => lineItems.fold(0, (sum, item) => sum + item.loadedQuantity);
  int get remainingTotal => (total - loadedTotal).clamp(0, total);
  bool get isComplete => total > 0 && loadedTotal >= total;
  bool get hasShortages => lineItems.any((item) => item.isShort);

  IbtDocument copyWith({...});
  Map<String, dynamic> toMap();
  factory IbtDocument.fromMap(Map<String, dynamic> map);
}
```

---

### 1.2 `lib/data/models/loading_sheet_trip.dart` (Model Evolution)
- **Path:** `flutter_app/lib/data/models/loading_sheet_trip.dart`
- **Modifications from `main`:**
  1. Imports `ibt_manifest.dart`.
  2. Adds optional field: `final List<IbtDocument>? ibtDocuments;` to `LoadingSheetTrip`.
  3. Adds getters:
     - `bool get hasIbtDocuments => ibtDocuments != null && ibtDocuments!.isNotEmpty;`
     - `int get ibtTargetTotal => ibtDocuments?.fold<int>(0, (sum, doc) => sum + doc.total) ?? 0;`
     - `int get ibtLoadedTotal => ibtDocuments?.fold<int>(0, (sum, doc) => sum + doc.loadedTotal) ?? 0;`
  4. Updates target calculations (`remainingTyres`, `overCount`, `progressPercent`, `isTargetReached`, `isTargetExceeded`):
     ```dart
     final effectiveTarget = (targetQuantity != null && targetQuantity! > 0)
         ? targetQuantity!
         : (hasIbtDocuments ? ibtTargetTotal : 0);
     ```
  5. Updates `toMap()`:
     ```dart
     'ibtDocuments': ibtDocuments?.map((e) => e.toMap()).toList(),
     ```
  6. Updates `fromMap()`:
     ```dart
     List<IbtDocument>? ibts;
     if (map['ibtDocuments'] != null) {
       final rawList = map['ibtDocuments'] as List<dynamic>;
       ibts = rawList
           .map((e) => IbtDocument.fromMap(e as Map<String, dynamic>))
           .toList();
     }
     ```
- **Database & Sync Impact:** `LoadingSheetTrip` instances are serialized as a JSON string inside `Entry.loadingSheetTrips` in SQLite and synced to Supabase as JSONB/TEXT. Adding `ibtDocuments` is non-breaking and requires zero SQL database migrations.

---

### 1.3 `lib/data/services/appsync_manifest_service.dart` (New File)
- **Path:** `flutter_app/lib/data/services/appsync_manifest_service.dart`
- **Dependencies:** `flutter_secure_storage`, `http`, `flutter/foundation.dart`, `dart:convert`.
- **Key Architectural Constants:**
  - `endpoint`: `https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql`
  - `cognitoDomain`: `cabsystem.auth.eu-central-1.amazoncognito.com`
  - `cognitoIdpEndpoint`: `https://cognito-idp.eu-central-1.amazonaws.com`
  - `clientId`: `78ikblrgsr8h27197iovkgrro6`
  - `redirectUri`: `myapp://`
  - Storage Keys: `appsync_access_token`, `appsync_id_token`, `appsync_refresh_token`
- **Lookup Master Tables:**
  - `sizeMaster`: Maps size IDs (e.g. `22: '315/80R22.5'`, `45: '11R22.5'`, `30: '295/80R22.5'`, `38: '275/70R22.5'`, `15: '385/65R22.5'`, `12: '12R22.5'`, `10: '10.00R20'`).
  - `rubberMaster`: Maps rubber IDs (e.g. `12: 'RD2+'`, `14: 'M90L'`, `18: 'MM84'`, `25: 'M3'`, `31: 'SP571'`, `40: 'K-Max S'`, `52: 'X Multiway 3D'`).
  - Fallback regex extractors: `extractSize(String text)` and `extractRubber(String text)` when IDs are omitted by backend resolvers.
- **GraphQL Schema & Critical VTL Handling:**
  The AppSync GraphQL query signature is:
  ```graphql
  query MyQuery($inv: String, $ibt: String, $dibt: String, $amsInv: String) {
    getDeliveryInfo(getDeliveryInfo: {amsInv: $amsInv, dibt: $dibt, ibt: $ibt, inv: $inv}) {
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
  **CRITICAL FIX (Commit `d570aac`):** The AWS AppSync VTL mapping template crashes with a null pointer / `.substring()` error if unused parameters are `null`. The client MUST pass empty strings `""` for optional parameters:
  ```dart
  'variables': {
    'ibt': docNo,
    'inv': '',
    'dibt': '',
    'amsInv': '',
  }
  ```
- **Document Fetching & Parsing:**
  - `fetchIbtDocument(String documentNoInput, {http.Client? client, String? explicitIdToken})`: Auto-prefixes numeric document numbers (e.g. `"119512"` -> `"IBT119512"`), validates JWT authorization headers (`Bearer $idToken`), checks for GraphQL `errors` payload, and delegates to `parseIbtLines`.
  - `parseIbtLines(String docNo, List<dynamic> rawLines)`: Maps raw JSON items to `IbtLineItem` entities with target counts and unique IDs.

---

## 2. Requirement R2: AWS Auth Flow & Tokens

### 2.1 Supported Authentication Flows
The service supports dual authentication flows to guarantee accessibility across all network and corporate SSO constraints:

1. **Cognito Hosted UI (OAuth2 Authorization Code / Implicit Token Flow):**
   - URL: `AppSyncManifestService.getHostedUiAuthorizeUrl(tokenFlow: true)`
   - Generated Auth URL:
     `https://cabsystem.auth.eu-central-1.amazoncognito.com/oauth2/authorize?client_id=78ikblrgsr8h27197iovkgrro6&response_type=code&scope=email+openid+aws.cognito.signin.user.admin&redirect_uri=myapp://`
   - Interception: `AwsLoginWebViewScreen` listens to navigation requests and redirects to `myapp://`.
   - Token Exchange: `handleRedirectUrl()` extracts authorization code and posts to `https://cabsystem.auth.eu-central-1.amazoncognito.com/oauth2/token` (`grant_type: 'authorization_code'`).
2. **Direct Cognito Identity Provider API (`USER_PASSWORD_AUTH`):**
   - Direct HTTP POST to `https://cognito-idp.eu-central-1.amazonaws.com` with `X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth`.
   - `loginWithCredentials({required String username, required String password, http.Client? client})` returns `AwsUserInfo`.
3. **Manual Token Entry:**
   - Users can paste existing JWT ID and Refresh tokens directly in `AwsAuthDialog`.

### 2.2 Token Lifecycle & Auto-Refresh
- **Token Inspection:** `getAuthDetails()` decodes the Base64Url-encoded JWT payload of `idToken` to inspect `exp`, `email`, and `cognito:username`.
- **Auto-Refresh Mechanism:**
  - `getValidIdToken()` checks if the token expiration timestamp is within 60 seconds (`exp < now + 60`).
  - Automatically triggers `refreshAccessToken()` using the stored `refresh_token` via `grant_type: 'refresh_token'`.
  - Stored tokens in `FlutterSecureStorage` are updated atomically.

### 2.3 `lib/presentation/screens/aws_login_webview_screen.dart` (New File)
- **Path:** `flutter_app/lib/presentation/screens/aws_login_webview_screen.dart`
- **Features:**
  - Embedded `WebViewWidget` with unrestricted JavaScript.
  - **User-Agent Customization:** Sets a modern Android Chrome UA (`Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36`) to bypass Google / Cognito OAuth embedded browser security blocks (`disallowed_useragent`).
  - **Redirect Interception:** `NavigationDelegate(onNavigationRequest: (req) { if (url.startsWith('myapp://')) { _interceptIfRedirect(url); return NavigationDecision.prevent; } return NavigationDecision.navigate; })`.
  - **Error Handling:** Gracefully handles WebResource errors caused by the custom URL scheme and provides an inline retry prompt.
  - Returns `true` on successful login via `Navigator.pop(context, true)`.

### 2.4 `lib/presentation/widgets/aws_auth_dialog.dart` (New File)
- **Path:** `flutter_app/lib/presentation/widgets/aws_auth_dialog.dart`
- **Features:**
  - Bottom sheet modal (`AwsAuthDialog.show(context)`).
  - Status header showing active authentication status, email/username, and token expiration countdown.
  - Quick action button to trigger `AwsLoginWebViewScreen.push(context)`.
  - Two-tab layout:
    - Tab 1: **Direct Login** (Work email & Password).
    - Tab 2: **Paste Token / SSO** (ID Token, Refresh Token, and external browser link).
  - Live query test button (`AppSyncManifestService.testConnection()`) sending a mock AppSync GraphQL query to verify live network and permission viability.
  - Secure logout button (`AppSyncManifestService.logout()`).

---

## 3. `pubspec.yaml` Dependency Audit

| Package | Action | Version | Rationale |
|---|---|---|---|
| `flutter_secure_storage` | **Add** | `^11.0.0` | Secure encrypted storage of AWS Cognito ID, Access, and Refresh tokens across Android Keystore and iOS Keychain. |
| `webview_flutter` | **Add** | `^4.10.0` | In-app WebView presentation for Cognito Hosted UI OAuth login flow and redirect interception. |
| `open_filex` | **Remove** | `^4.7.0` | Deprecated and replaced by native Android `FileProvider` and `MethodChannel` (`com.dispatchdiary.dispatch_diary/install`) in `MainActivity.kt` / `update_service.dart`. |

---

## 4. Downstream Integration Points & Touchpoints with `main`

### 4.1 `LoadingSheetViewModel` Integration
- **Path:** `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart`
- **Added Methods:**
  1. `Future<void> updateIbtLineQuantity({required LoadingSheetTrip trip, required String documentNo, required String lineItemId, required int newQuantity})`: Updates specific line loaded quantity and synchronizes parent `trip.quantityLoaded`.
  2. `Future<void> attachIbtDocument({required LoadingSheetTrip trip, required IbtDocument ibtDoc})`: Attaches an IBT document, recalculates total target, and updates trip.
  3. `Future<void> removeIbtDocument({required LoadingSheetTrip trip, required String documentNo})`: Detaches an IBT document.
- **Surgical Consideration with `main`:**
  On `main`, `getTruckLoads()` has logic syncing `e.expectedTotal` to `t.targetQuantity` for counter-created entries. When merging, ensure trips with `hasIbtDocuments` prioritize `t.ibtTargetTotal` over `e.expectedTotal` while retaining `main`'s expectedTotal sync for non-IBT trips.

### 4.2 Export Services Integration
- **`flutter_app/lib/data/services/whatsapp_export_service.dart`**:
  Adds itemized IBT document breakdown with completion indicators (`[✓]`, `[⚠️ Short N]`, `[+N Over]`).
- **`flutter_app/lib/data/services/pdf_export_service.dart`**:
  Appends secondary table `"IBT MANIFEST BREAKDOWN & SHORTAGES"` when any trip on the sheet has attached IBT documents.

---

## 5. Potential Conflicts & Pitfalls

1. **Theme Incompatibilities in Ported UI:**
   - *Risk:* The feature branch uses `AppColors.backgroundSecondary` and hardcoded white text for some dialog backgrounds. `main` has introduced Daylight Sunlight Mode and dynamic `Theme.of(context)` color resolution.
   - *Mitigation:* Ensure `AwsAuthDialog` and `AwsLoginWebViewScreen` utilize `AppColors` tokens that adapt cleanly or maintain dark glass aesthetics without clashing with daylight theme tokens.
2. **`LoadingSheetTrip.fromMap` Parsing Rigor:**
   - *Risk:* On `main`, `reg` is parsed with `.toUpperCase()` and `createdAt` falls back to `DateTime.now().millisecondsSinceEpoch`.
   - *Mitigation:* Maintain `main`'s uppercase reg logic: `reg: (map['reg']?.toString() ?? '').toUpperCase()` and resilient timestamp fallback.
3. **AppSync Resolver Crashes from Missing Variables:**
   - *Risk:* Omitting variables in `getDeliveryInfo` GraphQL request causes AppSync VTL crashes.
   - *Mitigation:* Ensure all 4 parameters (`ibt`, `inv`, `dibt`, `amsInv`) are provided with empty strings `""` for unused keys.

---

## 6. Step-by-Step Porting Recommendations

1. **Step 1: Update `pubspec.yaml`**
   - Add `flutter_secure_storage: ^11.0.0` and `webview_flutter: ^4.10.0`.
   - Remove `open_filex: ^4.7.0`.
   - Run `flutter pub get`.
2. **Step 2: Port Models**
   - Create `flutter_app/lib/data/models/ibt_manifest.dart`.
   - Update `flutter_app/lib/data/models/loading_sheet_trip.dart` with `ibtDocuments` and `effectiveTarget` calculations, maintaining uppercase `reg` formatting.
3. **Step 3: Port AppSync Service**
   - Create `flutter_app/lib/data/services/appsync_manifest_service.dart`.
4. **Step 4: Port AWS Auth UI**
   - Create `flutter_app/lib/presentation/screens/aws_login_webview_screen.dart`.
   - Create `flutter_app/lib/presentation/widgets/aws_auth_dialog.dart`.
5. **Step 5: Port Export Extensions & ViewModel Methods**
   - Update `whatsapp_export_service.dart` and `pdf_export_service.dart` with IBT itemization.
   - Update `loading_sheet_viewmodel.dart` with `updateIbtLineQuantity`, `attachIbtDocument`, and `removeIbtDocument`.
6. **Step 6: Port Tests & Validate**
   - Port `test/ibt_manifest_test.dart`, `test/appsync_manifest_service_test.dart`, and `test/ibt_workflow_tdd_test.dart`.
   - Run `flutter test` and `dart analyze` to ensure 0 errors.

---

## Conclusion

Requirements R1 and R2 are cleanly architected and highly modular. The data models and AWS AppSync services do not touch core database schemas and integrate seamlessly with `main`'s existing state management architecture. All necessary code, test suites, and integration steps are cataloged and ready for execution.
