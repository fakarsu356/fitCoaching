/// JSON alanlarını güvenli okuma yardımcıları.
///
/// Backend aynı veriyi bazı uçlarda PascalCase (`entities.*` — json tag'i yok),
/// bazılarında snake_case (`models.WorkoutM`) döndürüyor. [pick] birden fazla
/// olası anahtarı sırayla deneyerek bu farkı tek noktada soğuruyor.
dynamic pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
  }
  return null;
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

/// Cevap gövdesindeki listeyi normalize eder; `null` gelirse boş liste döner
/// (backend birçok yerde boş slice yerine `null` gönderiyor).
List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

Map<String, dynamic>? asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
