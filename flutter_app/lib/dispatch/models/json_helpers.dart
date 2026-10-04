/// Defensive JSON primitives for the live AppSync backend.
///
/// Live payloads may return numbers as strings (SQL-backed lambdas) or omit
/// fields. Parsing must tolerate everything — never crash the operator's
/// screen because the backend changed a casing.
int? jsonInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}

String? jsonString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

String jsonStringOr(Object? value, String fallback) =>
    jsonString(value) ?? fallback;

int jsonIntOr(Object? value, int fallback) => jsonInt(value) ?? fallback;

List<Map<String, dynamic>> jsonMapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}

Map<String, dynamic> jsonMap(Object? value) {
  if (value is! Map<String, dynamic>) return const {};
  return value;
}

/// Accepts either a map or a single-element list wrapping the map — live
/// lambdas have returned both shapes for object-typed fields.
Map<String, dynamic> jsonMapField(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is List) {
    for (final item in value) {
      if (item is Map<String, dynamic>) return item;
    }
  }
  return const {};
}
