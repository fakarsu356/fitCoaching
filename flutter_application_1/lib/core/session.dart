import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Backend'in `entities.Role` değerleri.
class UserRole {
  const UserRole._();

  static const String student = 'Student';
  static const String coach = 'Coach';
}

/// Access/refresh token ve oturum sahibinin kimliği.
///
/// Kullanıcı id'si ayrıca saklanmıyor; access token'ın içindeki `userId`
/// claim'inden okunuyor. Birkaç endpoint (saveWorkout, workout detayı) öğrenciden
/// de kendi `student_id`'sini göndermesini istediği için bu bilgi gerekli.
class Session {
  Session({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _roleKey = 'user_role';

  final FlutterSecureStorage _storage;

  String? _accessToken;
  String? _refreshToken;
  String? _role;
  int? _userId;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get role => _role;
  int? get userId => _userId;

  bool get isLoggedIn => _accessToken != null && _accessToken!.isNotEmpty;
  bool get isCoach => _role == UserRole.coach;
  bool get isStudent => _role == UserRole.student;

  /// Uygulama açılışında diskteki oturumu belleğe alır.
  Future<void> restore() async {
    _accessToken = await _storage.read(key: _accessKey);
    _refreshToken = await _storage.read(key: _refreshKey);
    _role = await _storage.read(key: _roleKey);
    _userId = _userIdFromToken(_accessToken);
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String role,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _role = role;
    _userId = _userIdFromToken(accessToken);

    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _roleKey, value: role);
  }

  /// Sadece access token yenilendiğinde çağrılır.
  Future<void> updateAccessToken(String accessToken) async {
    _accessToken = accessToken;
    _userId = _userIdFromToken(accessToken);
    await _storage.write(key: _accessKey, value: accessToken);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _role = null;
    _userId = null;
    await _storage.deleteAll();
  }

  /// JWT payload'ındaki `userId` claim'ini okur. İmza doğrulanmaz —
  /// yetkilendirme her hâlükârda sunucuda yapılıyor, bu sadece UI için.
  static int? _userIdFromToken(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is Map && payload['userId'] is num) {
        return (payload['userId'] as num).toInt();
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
