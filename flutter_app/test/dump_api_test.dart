import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/dispatch/dump_api.dart';
import 'package:dispatch_diary/dispatch/models/dump_customer.dart';

void main() {
  group('DumpApi — mutation contract', () {
    test('dump mark payload matches updateSlip exactly', () {
      final payload = DumpApi.buildDumpMarkPayload(501);
      expect(payload, {'idSlip': 501, 'dump': 1});
    });

    test('dump mark payload honours the un-dump flag', () {
      final payload = DumpApi.buildDumpMarkPayload(501, dumped: false);
      expect(payload['dump'], 0);
    });

    test('dump customer valid payload toggles 1/0', () {
      expect(DumpApi.buildDumpCustomerValidPayload(7, true), {
        'idDump_Customer': 7,
        'valid': 1,
      });
      expect(DumpApi.buildDumpCustomerValidPayload(7, false), {
        'idDump_Customer': 7,
        'valid': 0,
      });
    });

    test('scrap-analysis customer valid payload toggles 1/0', () {
      expect(DumpApi.buildScrapAnalysisCustomerValidPayload(9, true), {
        'idScrap_Analysis_Customer': 9,
        'valid': 1,
      });
      expect(DumpApi.buildScrapAnalysisCustomerValidPayload(9, false), {
        'idScrap_Analysis_Customer': 9,
        'valid': 0,
      });
    });

    test('add-customer payload carries the lookup id', () {
      expect(DumpApi.buildAddCustomerPayload(123), {'customer_lookup_id': 123});
    });
  });

  group('dump customer models', () {
    test('DumpCustomer parses the live row shape', () {
      final customer = DumpCustomer.fromJson({
        'idDump_Customer': 7,
        'customer_lookup_id': 123,
        'CustomerName': 'Scrap Metal Co',
        'CustomerCode': 'SMC',
      });
      expect(customer.id, 7);
      expect(customer.customerLookupId, 123);
      expect(customer.displayName, 'Scrap Metal Co');
    });

    test('DumpCustomer falls back to code when name is missing', () {
      final customer = DumpCustomer.fromJson({
        'idDump_Customer': 7,
        'CustomerCode': 'SMC',
      });
      expect(customer.displayName, 'SMC');
    });

    test('ScrapAnalysisCustomer parses the live row shape', () {
      final customer = ScrapAnalysisCustomer.fromJson({
        'idScrap_Analysis_Customer': 9,
        'customer_lookup_id': 456,
        'CustomerName': 'Analysis Lab',
        'CustomerCode': 'ALB',
      });
      expect(customer.id, 9);
      expect(customer.displayName, 'Analysis Lab');
    });

    test('CustomerLookupEntry builds the search label', () {
      final entry = CustomerLookupEntry.fromJson({
        'idCustomer_Lookup': 123,
        'CustomerName': 'Scrap Metal Co',
        'CustomerCode': 'SMC',
      });
      expect(entry.displayLabel, 'Scrap Metal Co · SMC');
    });

    test('CustomerLookupEntry tolerates missing fields', () {
      final entry = CustomerLookupEntry.fromJson(const {});
      expect(entry.id, isNull);
      expect(entry.displayLabel, 'Customer');
    });
  });
}
