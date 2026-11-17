class JsonHelpers {
  /// Safely converts any dynamic value to a Map<String, dynamic>.
  /// Prevents: type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>'
  /// Prevents: type 'List<dynamic>' is not a subtype of type 'Map<String, dynamic>'
  static Map<String, dynamic> toMap(dynamic value) {
    if (value == null) return <String, dynamic>{};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  /// Safely converts any dynamic value to a List<dynamic>.
  /// Handles both bare lists `[...]` and wrapped objects `{ "data": [...] }` or `{ "items": [...] }`.
  static List<dynamic> toList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is Map) {
      if (value.containsKey('data') && value['data'] is List) {
        return value['data'] as List;
      }
      if (value.containsKey('items') && value['items'] is List) {
        return value['items'] as List;
      }
    }
    return [];
  }

  /// Safely extracts a double number from num, string with spaces/commas, or null.
  static double toDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(' ', '').replaceAll(',', '.').trim();
      return double.tryParse(clean) ?? fallback;
    }
    return fallback;
  }

  /// Safely extracts an integer from num, string, or null.
  static int toInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final clean = val.replaceAll(' ', '').trim();
      return int.tryParse(clean) ?? fallback;
    }
    return fallback;
  }

  /// Safely converts value to string with fallback.
  static String toStr(dynamic val, [String fallback = '']) {
    if (val == null) return fallback;
    if (val is String) return val;
    return val.toString();
  }

  /// Safely extracts a boolean value.
  static bool toBool(dynamic val, [bool fallback = false]) {
    if (val == null) return fallback;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final lower = val.toLowerCase().trim();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return fallback;
  }

  /// Safely parses a DateTime from string, timestamp, or null.
  static DateTime toDateTime(dynamic val, [DateTime? fallback]) {
    if (val == null) return fallback ?? DateTime.now();
    if (val is DateTime) return val;
    if (val is num) {
      return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    }
    return DateTime.tryParse(val.toString()) ?? fallback ?? DateTime.now();
  }

  /// Safely parses an optional DateTime.
  static DateTime? toOptionalDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is num) {
      return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    }
    return DateTime.tryParse(val.toString());
  }

  /// Safely extracts a string from either a nested Map (e.g. `{"name": "..."}`)
  /// or a plain String (e.g. `"ООО Ромашка"`), PREVENTING the runtime error:
  /// `type 'String' is not a subtype of type 'int' of 'index'`.
  static String extractString(
    dynamic entity, {
    List<String> preferredKeys = const ['name', 'fullName', 'title', 'content', 'message'],
    String fallback = '',
  }) {
    if (entity == null) return fallback;
    if (entity is String) return entity.isNotEmpty ? entity : fallback;
    if (entity is Map) {
      for (final key in preferredKeys) {
        final val = entity[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val.toString();
        }
      }
    }
    return entity.toString();
  }

  /// Same as extractString but returns null if empty or null.
  static String? extractOptionalString(
    dynamic entity, {
    List<String> preferredKeys = const ['name', 'fullName', 'title', 'photoUrl', 'avatarUrl', 'email'],
  }) {
    if (entity == null) return null;
    if (entity is String) return entity.isNotEmpty ? entity : null;
    if (entity is Map) {
      for (final key in preferredKeys) {
        final val = entity[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val.toString();
        }
      }
    }
    return null;
  }
}
