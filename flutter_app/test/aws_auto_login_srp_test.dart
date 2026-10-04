import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/services/aws_auto_login_service.dart';

/// Golden vectors captured from a verified Python SRP implementation
/// against the live Cognito pool (fixed `a`, live challenge values).
void main() {
  const aHex =
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
  const aHexValue = aHex; // 128-bit fixed secret
  const srpBHex =
      'b737974551421f8688f498155db9a7b4c55596e611a65e6e2f8683a99551c423'
      '91a6ef475b423a1a8126a0101c2d8c0b00c6084bca13a4a5f546515b6c80c010'
      '6f97ed3b2046e58fb6b82cc4988467e354d276b5ad3efe45be9f317a126e5c08'
      '0f4edd5a47a5447b41094f26a71937f198c1fa7bb6231e265cdde96f2e79c0fb'
      '46340c0d315d5bb507b382a2f3f276f62bcfa1539b711523c72377f2f50d6b12'
      'bc56cab14fd5a2e617c473cb7d77fb11e4f92e050a7f8e46fa2efc8070f3bbfa'
      '233124c498da7649ea5f51e85a8ca05d060a4f74ab0dfaf45afa84a7149c7f37'
      '17200c6eef0e54a5d09c2ebd376624d7d286c70c9ae7dfa05c3f6a2f91da1fba'
      '3913d409b3873eca717566368e6059d43ed6cd19fda348dff546e23e3aaf3d3b'
      'f909bb205e8f81ded17af2241972d5b5c812eb6f0248c6bdcd6cce7d54c78f77'
      '1692e0c35256c75f991af984eb4e93eb7acd9b5c42816a81eb7b2deb9a11cc97'
      'e7c1b31d54c29c2db470e67b039a59e20cc1699e02aa34e31c87f13fc326a23e';
  const saltHex = 'd082c31126b03673cd4c6530ef31a8ea';
  const srpUsername = 'laptop-e31lq89m';
  const poolName = 'mQIxfPBi1';
  const password = '12341!aA1';

  final a = BigInt.parse(aHexValue, radix: 16);
  final B = BigInt.parse(srpBHex, radix: 16);
  final A = BigInt.from(2).modPow(
    a,
    BigInt.parse(AwsAutoLoginService.nHex, radix: 16),
  );

  test('padHex handles odd and high-bit hex correctly', () {
    expect(AwsAutoLoginService.padHexValue(BigInt.from(15)), '0f');
    expect(AwsAutoLoginService.padHexValue(BigInt.from(0xaabb)), '00aabb');
    expect(AwsAutoLoginService.padHexValue(BigInt.from(0x7aab)), '7aab');
    expect(AwsAutoLoginService.padHexValue(BigInt.from(0xffaa)), '00ffaa');
    expect(AwsAutoLoginService.padHexString('f'), '0f');
    expect(AwsAutoLoginService.padHexString('ffaa'), '00ffaa');
    expect(AwsAutoLoginService.padHexString('7faa'), '7faa');
  });

  test('u value matches golden vector', () {
    final u = AwsAutoLoginService.uValue(A, B);
    expect(
      u.toRadixString(16),
      '50f9d5c37542814a4d7aaf34405ec7a606234e5bd3ab7a4b4dbc790333ce2819',
    );
  });

  test('x value matches golden vector', () {
    final x = AwsAutoLoginService.xValue(
      saltHex: saltHex,
      poolName: poolName,
      srpUsername: srpUsername,
      password: password,
    );
    expect(
      x.toRadixString(16),
      'e64432783fbc92d5a38c194b53c726d5ec2a821850aa614642cb18b690598d0d',
    );
  });

  test('S value matches golden vector', () {
    final k = AwsAutoLoginService.kMultiplier();
    final u = AwsAutoLoginService.uValue(A, B);
    final x = AwsAutoLoginService.xValue(
      saltHex: saltHex,
      poolName: poolName,
      srpUsername: srpUsername,
      password: password,
    );
    final S = AwsAutoLoginService.sValue(B: B, k: k, x: x, a: a, u: u);
    expect(
      S.toRadixString(16),
      'e88dec1504c31c5303c95aaa30207f23d8692e2344f2621c686282ef677419af'
      'ab213f6439894a5b81364ff2ace96bce3a8b7c5c18bf524c2283719ba2859d1a'
      '15203ade4397f6ed176c6bd93908214813b4144d1a715f31d44611ef0081c4ba'
      '2856cc42ec7803bd55e8511fbfb9f1c15988dce32cde30a15be52bce0451e329'
      '649a9d36985cda485ed3d0d09c7cf0b55004fb2d528263886594f25ec3a2b5b7'
      'cca260f11dd686501a4e600f27bcd51f64d6184c1c25f3e32d0234c6c240910e'
      '016a47fb5733c53741635bfb476dc6ac5d50a714a42284a3697e49e2aa6a0942'
      'b9826af561bc8b0ec875834c8269f80da054b8dd87312aae37be48370a1b1e93'
      '47e420abe0326cbf1991125ae1775f89d026f84693cfea033bad8d7f884a8795f'
      '0789fe6efa164aebe8c6f79dc5ae9ad4c891a02b2c7ab987bdbfa173b5263714'
      '7b7bd9687f750359038015b18e6f6f36b5e4e6cc78d9b74cde9dd779cb54c1f3'
      'd65471a63a0411f43c62a6290a1bd50f3eb26586f798fd663e4f34a1e7c616e',
    );
  });

  test('HKDF key matches golden vector', () {
    final u = AwsAutoLoginService.uValue(A, B);
    final k = AwsAutoLoginService.kMultiplier();
    final x = AwsAutoLoginService.xValue(
      saltHex: saltHex,
      poolName: poolName,
      srpUsername: srpUsername,
      password: password,
    );
    final S = AwsAutoLoginService.sValue(B: B, k: k, x: x, a: a, u: u);
    final key = AwsAutoLoginService.hkdfKey(S, u);
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(hex, '8204f4e0f025582cd8f94626efa71f82');
  });

  test('signature message layout is poolName + user + secretBlock + ts', () {
    final msg = AwsAutoLoginService.signatureMessage(
      poolName: 'mQIxfPBi1',
      srpUsername: 'laptop-e31lq89m',
      secretBlock: [0xde, 0xad, 0xbe, 0xef],
      timestamp: 'Sun Oct 4 20:54:07 UTC 2026',
    );
    expect(
      msg.length,
      'mQIxfPBi1'.length +
          'laptop-e31lq89m'.length +
          4 +
          'Sun Oct 4 20:54:07 UTC 2026'.length,
    );
  });

  test('timestamp matches Cognito format', () {
    final ts = AwsAutoLoginService.nowString();
    expect(
      RegExp(r'^[A-Z][a-z]{2} [A-Z][a-z]{2} \d{1,2} \d{2}:\d{2}:\d{2} UTC \d{4}$')
          .hasMatch(ts),
      isTrue,
    );
  });
}
