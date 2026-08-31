import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dispatch_diary/data/services/appsync_manifest_service.dart';

void main() {
  group('AppSyncManifestService TDD Tests', () {
    test('Throws exception when no authentication token is provided', () async {
      expect(
        () => AppSyncManifestService.fetchIbtDocument(
          'IBT119512',
          explicitIdToken: '',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Authentication required'),
        )),
      );
    });

    test('Sends valid GraphQL query with Bearer token and parses response cleanly', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.toString(), AppSyncManifestService.endpoint);
        expect(request.headers['Authorization'], 'Bearer TEST_JWT_TOKEN');
        expect(request.headers['Content-Type'], 'application/json');

        final payload = jsonDecode(request.body);
        expect(payload['variables']['ibt'], 'IBT119512');
        expect(payload['query'], contains('getDeliveryInfo'));

        final fakeResponse = {
          "data": {
            "getDeliveryInfo": {
              "ibt": [
                {
                  "description": "315/80R22.5 RD2+",
                  "rcs_code": "LLS039",
                  "size_id": 22,
                  "rubber_id": 12,
                  "total": 13
                },
                {
                  "description": "315/80R22.5 M90L",
                  "rcs_code": "LLS042",
                  "size_id": 22,
                  "rubber_id": 14,
                  "total": 40
                },
                {
                  "description": "11R22.5 MM84",
                  "rcs_code": "LLS018",
                  "size_id": 45,
                  "rubber_id": 18,
                  "total": 20
                }
              ]
            }
          }
        };

        return http.Response(jsonEncode(fakeResponse), 200);
      });

      final doc = await AppSyncManifestService.fetchIbtDocument(
        '119512', // test auto-prefixing IBT
        client: mockHttpClient,
        explicitIdToken: 'TEST_JWT_TOKEN',
      );

      expect(doc.documentNo, 'IBT119512');
      expect(doc.total, 73);
      expect(doc.lineItems.length, 3);

      expect(doc.lineItems[0].description, '315/80R22.5 RD2+');
      expect(doc.lineItems[0].size, '315/80R22.5');
      expect(doc.lineItems[0].rubber, 'RD2+');
      expect(doc.lineItems[0].rcsCode, 'LLS039');
      expect(doc.lineItems[0].targetTotal, 13);
      expect(doc.lineItems[0].loadedQuantity, 0);

      expect(doc.lineItems[1].rubber, 'M90L');
      expect(doc.lineItems[1].targetTotal, 40);

      expect(doc.lineItems[2].size, '11R22.5');
      expect(doc.lineItems[2].rubber, 'MM84');
      expect(doc.lineItems[2].targetTotal, 20);
    });

    test('Handles GraphQL errors and server failures by throwing descriptive exceptions', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            "errors": [
              {"message": "Unauthorized access to AppSync resource"}
            ]
          }),
          200,
        );
      });

      expect(
        () => AppSyncManifestService.fetchIbtDocument(
          'IBT999',
          client: mockHttpClient,
          explicitIdToken: 'EXPIRED_TOKEN',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Unauthorized access to AppSync resource'),
        )),
      );
    });
  });
}
