import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/ibt_manifest.dart';

class AwsUserInfo {
  final bool isAuthenticated;
  final String? email;
  final String? username;
  final DateTime? expiresAt;

  const AwsUserInfo({
    required this.isAuthenticated,
    this.email,
    this.username,
    this.expiresAt,
  });
}

class AppSyncManifestService {
  static const String endpoint =
      'https://w2jsgqhlgngcfn3d27xvl2r6iq.appsync-api.eu-central-1.amazonaws.com/graphql';
  static const String cognitoDomain =
      'cabsystem.auth.eu-central-1.amazoncognito.com';
  static const String cognitoIdpEndpoint =
      'https://cognito-idp.eu-central-1.amazonaws.com';
  static const String clientId = '78ikblrgsr8h27197iovkgrro6';
  static const String redirectUri = 'myapp://';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _keyAccessToken = 'appsync_access_token';
  static const String _keyIdToken = 'appsync_id_token';
  static const String _keyRefreshToken = 'appsync_refresh_token';

  // Master size and rubber master mapping tables from backend
  static const Map<int, String> sizeMaster = {
    22: '315/80R22.5',
    45: '11R22.5',
    30: '295/80R22.5',
    38: '275/70R22.5',
    15: '385/65R22.5',
    12: '12R22.5',
    10: '10.00R20',
  };

  static const Map<int, String> rubberMaster = {
    12: 'RD2+',
    14: 'M90L',
    18: 'MM84',
    25: 'M3',
    31: 'SP571',
    40: 'K-Max S',
    52: 'X Multiway 3D',
  };

  /// Build official Cognito Hosted UI Authorize URL for in-app browser
  static String getHostedUiAuthorizeUrl({bool tokenFlow = true}) {
    final responseType = tokenFlow ? 'token' : 'code';
    final encodedRedirect = Uri.encodeComponent(redirectUri);
    return 'https://$cognitoDomain/oauth2/authorize?client_id=$clientId&response_type=$responseType&scope=email+openid+profile+aws.cognito.signin.user.admin&redirect_uri=$encodedRedirect';
  }

  /// Intercept and parse redirect URI from OAuth flow (both token and code response types)
  static Future<bool> handleRedirectUrl(String url, {http.Client? client}) async {
    try {
      final uri = Uri.parse(url);

      // Check if redirect matches our scheme or localhost
      if (uri.scheme == 'myapp' || uri.host == 'localhost' || uri.path.contains('callback')) {
        // 1. Implicit Token Flow (tokens in URL fragment)
        if (uri.fragment.isNotEmpty) {
          final fragParams = Uri.splitQueryString(uri.fragment);
          final idToken = fragParams['id_token'];
          final accessToken = fragParams['access_token'];
          final refreshToken = fragParams['refresh_token'];

          if (idToken != null && idToken.isNotEmpty) {
            await saveAuthTokens(
              accessToken: accessToken ?? idToken,
              idToken: idToken,
              refreshToken: refreshToken,
            );
            return true;
          }
        }

        // 2. Authorization Code Flow (code in query parameters)
        final code = uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          return await exchangeCodeForTokens(code, client: client);
        }

        // 3. Fallback: check query params directly for tokens
        final idTokenQuery = uri.queryParameters['id_token'];
        if (idTokenQuery != null && idTokenQuery.isNotEmpty) {
          final accessTokenQuery = uri.queryParameters['access_token'];
          await saveAuthTokens(
            accessToken: accessTokenQuery ?? idTokenQuery,
            idToken: idTokenQuery,
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error handling OAuth redirect: $e');
    }
    return false;
  }

  /// Exchange authorization code for ID and access tokens
  static Future<bool> exchangeCodeForTokens(String code, {http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.https(cognitoDomain, '/oauth2/token');
      final res = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': code,
          'redirect_uri': redirectUri,
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final idToken = data['id_token'] as String?;
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;

        if (idToken != null && idToken.isNotEmpty) {
          await saveAuthTokens(
            accessToken: accessToken ?? idToken,
            idToken: idToken,
            refreshToken: refreshToken,
          );
          return true;
        }
      } else {
        debugPrint('Token exchange failed (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      debugPrint('Error exchanging auth code: $e');
    } finally {
      if (client == null) httpClient.close();
    }
    return false;
  }

  /// Authenticate directly with Cognito using Username / Email & Password
  static Future<AwsUserInfo> loginWithCredentials({
    required String username,
    required String password,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.post(
        Uri.parse(cognitoIdpEndpoint),
        headers: {
          'Content-Type': 'application/x-amz-json-1.1',
          'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
        },
        body: jsonEncode({
          'AuthFlow': 'USER_PASSWORD_AUTH',
          'ClientId': clientId,
          'AuthParameters': {
            'USERNAME': username.trim(),
            'PASSWORD': password,
          },
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final errorType = data['__type']?.toString().split('#').last ?? 'AuthError';
        final message = data['message'] ?? data['Message'] ?? 'Cognito authentication failed';
        throw Exception('$errorType: $message');
      }

      final authResult = data['AuthenticationResult'];
      if (authResult == null) {
        throw Exception('Cognito challenge required: ${data['ChallengeName'] ?? "Unknown Challenge"}');
      }

      final idToken = authResult['IdToken'] as String;
      final accessToken = authResult['AccessToken'] as String;
      final refreshToken = authResult['RefreshToken'] as String?;

      await saveAuthTokens(
        accessToken: accessToken,
        idToken: idToken,
        refreshToken: refreshToken,
      );

      return await getAuthDetails();
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Save tokens directly (from Hosted UI redirect or manual entry)
  static Future<void> saveAuthTokens({
    required String accessToken,
    required String idToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyIdToken, value: idToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
  }

  /// Get current authentication details & token metadata
  static Future<AwsUserInfo> getAuthDetails() async {
    final idToken = await _storage.read(key: _keyIdToken);
    if (idToken == null || idToken.isEmpty) {
      return const AwsUserInfo(isAuthenticated: false);
    }

    try {
      final parts = idToken.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        final exp = (payload['exp'] as num?)?.toInt() ?? 0;
        final email = payload['email'] as String? ?? payload['cognito:username'] as String?;
        final username = payload['cognito:username'] as String? ?? email;
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);

        final isExpired = DateTime.now().isAfter(expiresAt);
        if (isExpired) {
          // Attempt automatic token refresh
          final refreshed = await refreshAccessToken();
          if (refreshed != null) {
            return await getAuthDetails();
          }
          return AwsUserInfo(
            isAuthenticated: false,
            email: email,
            username: username,
            expiresAt: expiresAt,
          );
        }

        return AwsUserInfo(
          isAuthenticated: true,
          email: email,
          username: username,
          expiresAt: expiresAt,
        );
      }
    } catch (e) {
      debugPrint('Error inspecting JWT token: $e');
    }

    return const AwsUserInfo(isAuthenticated: false);
  }

  /// Read active ID Token (with automated refresh if expired)
  static Future<String?> getValidIdToken({http.Client? client}) async {
    final idToken = await _storage.read(key: _keyIdToken);
    if (idToken == null || idToken.isEmpty) return null;

    try {
      final parts = idToken.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        final exp = (payload['exp'] as num?)?.toInt() ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (exp < now + 300) {
          // Token expired or expiring within 60s, refresh token
          final refreshed = await refreshAccessToken(client: client);
          if (refreshed != null) return refreshed;
        }
      }
    } catch (e) {
      debugPrint('Error inspecting JWT token: $e');
    }

    return idToken;
  }

  /// Refresh token via Cognito OAuth2 endpoint
  static Future<String?> refreshAccessToken({http.Client? client}) async {
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.https(cognitoDomain, '/oauth2/token');
      final res = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': clientId,
          'refresh_token': refreshToken,
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newIdToken = data['id_token'] as String?;
        final newAccessToken = data['access_token'] as String?;
        if (newIdToken != null) {
          await _storage.write(key: _keyIdToken, value: newIdToken);
          if (newAccessToken != null) {
            await _storage.write(key: _keyAccessToken, value: newAccessToken);
          }
          return newIdToken;
        }
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    } finally {
      if (client == null) httpClient.close();
    }
    return null;
  }

  /// Check if session is authenticated and valid
  static Future<bool> isAuthenticated() async {
    final token = await getValidIdToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear stored credentials
  static Future<void> logout() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyIdToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  /// Test live AppSync connectivity with current token
  static Future<bool> testConnection({http.Client? client}) async {
    final idToken = await getValidIdToken(client: client);
    if (idToken == null || idToken.isEmpty) return false;

    const query = r'''
    query TestQuery {
      getDeliveryInfo(getDeliveryInfo: {ibt: "IBT000000"}) {
        ibt {
          total
        }
      }
    }
    ''';

    final httpClient = client ?? http.Client();
    try {
      final res = await httpClient.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'query': query}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Fetch IBT document contents directly from AWS AppSync GraphQL API
  static Future<IbtDocument> fetchIbtDocument(
    String documentNoInput, {
    http.Client? client,
    String? explicitIdToken,
  }) async {
    var docNo = documentNoInput.trim().toUpperCase();
    if (!docNo.startsWith('IBT') && RegExp(r'^\d+$').hasMatch(docNo)) {
      docNo = 'IBT$docNo';
    }

    final idToken = explicitIdToken ?? await getValidIdToken(client: client);
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Authentication required: No valid AWS session token found. Please sign in with your AWS / Cognito credentials in Settings.',
      );
    }

    const query = r'''
    query MyQuery($inv: String, $ibt: String, $dibt: String, $amsInv: String) {
      getDeliveryInfo(getDeliveryInfo: {amsInv: $amsInv, dibt: $dibt, ibt: $ibt, inv: $inv}) {
        inv {
          customerCode 
          customerName
          total
          slips {
            dump
            loaded
            location_code
            make
            name
            pattern     
            previous_reg
            scan_time
            size
            slip_number
            serial
            uid
          }
        }
        dibt {
          customerCode
          customerName
          total
          slips {
            dump
            loaded
            location_code
            make
            name
            pattern
            previous_reg
            scan_time
            size
            slip_number 
            serial
            uid
          }
        }
        ibt {
          description
          rcs_code
          size_id
          rubber_id
          total
        }
      }
    }
    ''';

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'query': query,
          'variables': {
            'ibt': docNo,
            'inv': '',
            'dibt': '',
            'amsInv': '',
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'AppSync error (${response.statusCode}): ${response.body}',
        );
      }

      final resData = jsonDecode(response.body);
      if (resData['errors'] != null && (resData['errors'] as List).isNotEmpty) {
        final errorMsg = resData['errors'][0]['message'] ?? 'GraphQL error';
        throw Exception('AppSync GraphQL Error: $errorMsg');
      }

      final ibtList =
          resData['data']?['getDeliveryInfo']?['ibt'] as List<dynamic>?;

      if (ibtList == null || ibtList.isEmpty) {
        throw Exception('No line items found for IBT document: $docNo');
      }

      return parseIbtLines(docNo, ibtList);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Parse AppSync response into IbtDocument and IbtLineItem entities
  static IbtDocument parseIbtLines(String docNo, List<dynamic> rawLines) {
    int totalCount = 0;
    final List<IbtLineItem> items = [];

    for (int i = 0; i < rawLines.length; i++) {
      final map = rawLines[i] as Map<String, dynamic>;
      final desc = map['description']?.toString() ?? 'Tyre Item';
      final rcs = map['rcs_code']?.toString();
      final sizeId = (map['size_id'] as num?)?.toInt();
      final rubberId = (map['rubber_id'] as num?)?.toInt();
      final lineTotal = (map['total'] as num?)?.toInt() ?? 0;

      final sizeStr = sizeId != null ? sizeMaster[sizeId] : extractSize(desc);
      final rubberStr =
          rubberId != null ? rubberMaster[rubberId] : extractRubber(desc);

      totalCount += lineTotal;

      items.add(
        IbtLineItem(
          id: '${docNo}_line_$i',
          description: desc,
          rcsCode: rcs,
          sizeId: sizeId,
          rubberId: rubberId,
          size: sizeStr,
          rubber: rubberStr,
          targetTotal: lineTotal,
          loadedQuantity: 0,
        ),
      );
    }

    return IbtDocument(
      documentNo: docNo,
      total: totalCount,
      lineItems: items,
    );
  }

  static String? extractSize(String text) {
    final match = RegExp(r'\d{3}/\d{2}R\d{2}\.?\d?|\d{1,2}R\d{2}\.?\d?')
        .firstMatch(text);
    return match?.group(0);
  }

  static String? extractRubber(String text) {
    final match = RegExp(
      r'(RD2\+|M90L|MM84|M3|SP571|K-Max|Multiway)',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(0)?.toUpperCase();
  }
}
