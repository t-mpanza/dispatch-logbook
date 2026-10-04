import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Silent AppSync auto-login.
///
/// Internal-development convenience: the app authenticates by itself so IBT
/// manifests fetch out-of-the-box without a manual sign-in step. Credentials
/// are lightly obfuscated (XOR+base64) — acceptable for internal builds only;
/// production builds must move to the hosted-UI PKCE flow.
///
/// The SRP handshake (USER_SRP_AUTH → PASSWORD_VERIFIER) is implemented
/// exactly per the Cognito specification, verified against the live pool.
class AwsAutoLoginService {
  // ── Obfuscated identity material (internal dev builds only) ──────────────
  static const int _xorKey = 0x5A;

  static const String _poolId =
      'Py93OT80Lig7NndrBTcLEyI8Chgzaw=='; // eu-central-1_mQIxfPBi1
  static const String _clientId =
      'bm5uKWooOTc/Yzc0MDEqODBiMixtPGwpPSk='; // 444s0rcme9mnjkpbj8hv7f6sgs
  static const String _username =
      'FhsKDhUKdx9paxYLYmMX'; // LAPTOP-E31LQ89M
  static const String _password = 'a2hpbmt7Oxtr'; // 12341!aA1

  static String _reveal(String obfuscated) {
    final bytes = base64Decode(obfuscated);
    return utf8.decode(bytes.map((b) => b ^ _xorKey).toList());
  }

  // ── SRP constants ─────────────────────────────────────────────────────────
  /// Canonical RFC-5054 3072-bit group prime, verified against the live
  /// Cognito pool via a reference Python implementation.
  static const String nHex =
      'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA'
      '63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51'
      'C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5A'
      'E9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163F'
      'A8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4AB'
      'C9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28F'
      'B5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728'
      'E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D'
      '060C7DB3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6'
      'BF12FFA06D98A0864D87602733EC86A64521F2B18177B200CBBE117577A615D6C7709'
      '88C0BAD946E208E24FA074E5AB3143DB5BFCE0FD108E4B82D120A93AD2CA'
      'FFFFFFFFFFFFFFFF';

  // ignore: non_constant_identifier_names
  static final BigInt _N = BigInt.parse(nHex, radix: 16);
  // ignore: non_constant_identifier_names
  static final BigInt _g = BigInt.from(2);

  static const String _cognitoEndpoint =
      'https://cognito-idp.eu-central-1.amazonaws.com';

  /// Authenticate silently and return the session ID token, or null.
  /// [onTokens] receives (accessToken, idToken, refreshToken) for storage.
  static Future<String?> login({
    http.Client? client,
    Future<void> Function(String access, String id, String? refresh)?
    onTokens,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final poolId = _reveal(_poolId);
      final clientId = _reveal(_clientId);
      final username = _reveal(_username);
      final password = _reveal(_password);

      // Step 1: USER_SRP_AUTH
      final a = _randomSmallA();
      final A = _g.modPow(a, _N);
      final initRes = await httpClient.post(
        Uri.parse(_cognitoEndpoint),
        headers: {
          'Content-Type': 'application/x-amz-json-1.1',
          'X-Amz-Target':
              'AWSCognitoIdentityProviderService.InitiateAuth',
        },
        body: jsonEncode({
          'AuthFlow': 'USER_SRP_AUTH',
          'ClientId': clientId,
          'AuthParameters': {
            'USERNAME': username,
            'SRP_A': A.toRadixString(16),
          },
        }),
      );

      if (initRes.statusCode != 200) {
        debugPrint('AWS auto-login init failed (${initRes.statusCode})');
        return null;
      }

      final initData = jsonDecode(initRes.body) as Map<String, dynamic>;
      final challenge = initData['ChallengeParameters'];
      if (challenge == null) return null;

      final srpUsername = challenge['USER_ID_FOR_SRP'] as String? ?? username;
      final saltHex = challenge['SALT'] as String;
      final srpBHex = challenge['SRP_B'] as String;
      final secretBlockB64 = challenge['SECRET_BLOCK'] as String;
      final secretBlock = base64Decode(secretBlockB64);
      final B = BigInt.parse(srpBHex, radix: 16);
      final poolName = poolId.split('_')[1];

      // Step 2: derive the shared key
      final k = kMultiplier();
      final u = uValue(A, B);
      final x = xValue(
        saltHex: saltHex,
        poolName: poolName,
        srpUsername: srpUsername,
        password: password,
      );
      final S = sValue(B: B, k: k, x: x, a: a, u: u);
      final hkdf = hkdfKey(S, u);

      // Step 3: sign the password claim
      final ts = nowString();
      final msg = signatureMessage(
        poolName: poolName,
        srpUsername: srpUsername,
        secretBlock: secretBlock,
        timestamp: ts,
      );
      final signature = base64Encode(
        Hmac(sha256, hkdf).convert(msg).bytes,
      );


      final respondRes = await httpClient.post(
        Uri.parse(_cognitoEndpoint),
        headers: {
          'Content-Type': 'application/x-amz-json-1.1',
          'X-Amz-Target':
              'AWSCognitoIdentityProviderService.RespondToAuthChallenge',
        },
        body: jsonEncode({
          'ChallengeName': 'PASSWORD_VERIFIER',
          'ClientId': clientId,
          'ChallengeResponses': {
            'USERNAME': srpUsername,
            'PASSWORD_CLAIM_SECRET_BLOCK': secretBlockB64,
            'PASSWORD_CLAIM_SIGNATURE': signature,
            'TIMESTAMP': ts,
          },
        }),
      );

      if (respondRes.statusCode != 200) {
        debugPrint(
          'AWS auto-login verify failed (${respondRes.statusCode}): '
          '${respondRes.body}',
        );
        return null;
      }

      final data = jsonDecode(respondRes.body) as Map<String, dynamic>;
      final authResult = data['AuthenticationResult'];
      if (authResult == null) return null;

      final accessToken = authResult['AccessToken'] as String? ?? '';
      final idToken = authResult['IdToken'] as String?;
      final refreshToken = authResult['RefreshToken'] as String?;

      if (idToken == null || idToken.isEmpty) return null;
      await onTokens?.call(accessToken, idToken, refreshToken);
      return idToken;
    } catch (e) {
      debugPrint('AWS auto-login error: $e');
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  // ── SRP helpers (pure, unit-testable) ────────────────────────────────────

  static BigInt _randomSmallA() {
    final rng = Random.secure();
    final hex = List.generate(256, (_) {
      return '0123456789abcdef'[rng.nextInt(16)];
    }).join();
    return BigInt.parse(hex, radix: 16) % _N;
  }

  /// SHA256 of hex-decoded input, returned as hex.
  static String hexHashHex(String hexStr) {
    final bytes = <int>[];
    for (var i = 0; i < hexStr.length; i += 2) {
      bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
    }
    return sha256.convert(bytes).toString();
  }

  /// padHex for a BigInt value.
  static String padHexValue(BigInt value) {
    var s = value.toRadixString(16);
    if (s.length % 2 == 1) {
      s = '0$s';
    } else if ('89abcdefABCDEF'.contains(s[0])) {
      s = '00$s';
    }
    return s;
  }

  /// padHex for an already-hex string (SALT arrives as hex from Cognito).
  static String padHexString(String hexStr) {
    var s = hexStr;
    if (s.length % 2 == 1) {
      s = '0$s';
    } else if ('89abcdefABCDEF'.contains(s[0])) {
      s = '00$s';
    }
    return s;
  }

  /// k = H('00' + N + '0' + g)
  static BigInt kMultiplier() {
    return BigInt.parse(
      hexHashHex('00${_N.toRadixString(16)}0${_g.toRadixString(16)}'),
      radix: 16,
    );
  }

  /// u = H(padHex(A) || padHex(B))
  static BigInt uValue(BigInt A, BigInt B) {
    return BigInt.parse(
      hexHashHex(padHexValue(A) + padHexValue(B)),
      radix: 16,
    );
  }

  /// x = H(padHex(salt) || SHA256(poolName + srpUsername + ':' + password))
  static BigInt xValue({
    required String saltHex,
    required String poolName,
    required String srpUsername,
    required String password,
  }) {
    final inner = sha256
        .convert(utf8.encode('$poolName$srpUsername:$password'))
        .toString();
    return BigInt.parse(hexHashHex(padHexString(saltHex) + inner), radix: 16);
  }

  /// S = (B - k*g^x)^(a + u*x) mod N
  static BigInt sValue({
    required BigInt B,
    required BigInt k,
    required BigInt x,
    required BigInt a,
    required BigInt u,
  }) {
    final inner = (B - k * _g.modPow(x, _N)) % _N;
    return inner.modPow(a + u * x, _N) % _N;
  }

  /// Hex-decode a hex string to raw bytes (like Python's bytes.fromhex).
  static List<int> hexToBytes(String hexStr) {
    final bytes = <int>[];
    for (var i = 0; i < hexStr.length; i += 2) {
      bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// HKDF-SHA256 with info "Caldera Derived Key", 16-byte output.
  /// ikm/salt are taken as PADDED HEX STRINGS and hex-decoded to raw bytes —
  /// exactly what the reference implementation (and the server) expect.
  static List<int> hkdfKey(BigInt S, BigInt u) {
    final prk = Hmac(
      sha256,
      hexToBytes(padHexValue(u)),
    ).convert(hexToBytes(padHexValue(S))).bytes;
    final info = <int>[
      ...utf8.encode('Caldera Derived Key'),
      0x01,
    ];
    return Hmac(sha256, prk).convert(info).bytes.sublist(0, 16);
  }

  /// Signature message for the PASSWORD_VERIFIER challenge.
  static List<int> signatureMessage({
    required String poolName,
    required String srpUsername,
    required List<int> secretBlock,
    required String timestamp,
  }) {
    return <int>[
      ...utf8.encode(poolName),
      ...utf8.encode(srpUsername),
      ...secretBlock,
      ...utf8.encode(timestamp),
    ];
  }

  static const List<String> _weekNames = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _monthNames = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "ddd MMM D HH:mm:ss UTC YYYY" — Cognito's expected timestamp format.
  static String nowString() {
    final now = DateTime.now().toUtc();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '${_weekNames[now.weekday]} ${_monthNames[now.month]} '
        '${now.day} $hh:$mm:$ss UTC ${now.year}';
  }
}
