import 'json_helpers.dart';

/// One registered dump customer (`listDumpCustomer`).
class DumpCustomer {
  const DumpCustomer({
    this.id,
    this.customerLookupId,
    this.name,
    this.code,
  });

  final int? id;
  final int? customerLookupId;
  final String? name;
  final String? code;

  String get displayName => name ?? code ?? 'Dump customer';

  factory DumpCustomer.fromJson(Map<String, dynamic> json) => DumpCustomer(
    id: jsonInt(json['idDump_Customer']),
    customerLookupId: jsonInt(json['customer_lookup_id']),
    name: jsonString(json['CustomerName']),
    code: jsonString(json['CustomerCode']),
  );
}

/// One registered scrap-analysis customer (`listAnalysisCustomer`).
class ScrapAnalysisCustomer {
  const ScrapAnalysisCustomer({
    this.id,
    this.customerLookupId,
    this.name,
    this.code,
  });

  final int? id;
  final int? customerLookupId;
  final String? name;
  final String? code;

  String get displayName => name ?? code ?? 'Scrap-analysis customer';

  factory ScrapAnalysisCustomer.fromJson(Map<String, dynamic> json) =>
      ScrapAnalysisCustomer(
        id: jsonInt(json['idScrap_Analysis_Customer']),
        customerLookupId: jsonInt(json['customer_lookup_id']),
        name: jsonString(json['CustomerName']),
        code: jsonString(json['CustomerCode']),
      );
}

/// One row of the master customer directory (`listCustomerLookup`).
class CustomerLookupEntry {
  const CustomerLookupEntry({this.id, this.name, this.code});

  final int? id;
  final String? name;
  final String? code;

  String get displayLabel {
    final parts = [name, code].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Customer' : parts.join(' · ');
  }

  factory CustomerLookupEntry.fromJson(Map<String, dynamic> json) =>
      CustomerLookupEntry(
        id: jsonInt(json['idCustomer_Lookup']),
        name: jsonString(json['CustomerName']),
        code: jsonString(json['CustomerCode']),
      );
}
