import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, signedOut, student, coach }

/// Oturum durumunu tutan tek kaynak. [AppRoot] bunu dinleyip doğru ekranı
/// gösterir, böylece ekranlar arası elle yönlendirme gerekmez.
class AuthController extends ChangeNotifier {
  AuthController({required this.session, required this.client})
    : _authService = AuthService(client) {
    client.onSessionExpired = () {
      // Sunucu oturumu düşürdüyse kullanıcıyı giriş ekranına al.
      signOut();
    };
  }

  final Session session;
  final ApiClient client;
  final AuthService _authService;

  AuthStatus _status = AuthStatus.unknown;
  bool _busy = false;

  AuthStatus get status => _status;
  bool get busy => _busy;
  int? get userId => session.userId;
  bool get isCoach => _status == AuthStatus.coach;
  bool get isStudent => _status == AuthStatus.student;

  /// Uygulama açılışında diskteki oturumu yükler.
  Future<void> bootstrap() async {
    await session.restore();
    _status = _statusFromRole(session.isLoggedIn ? session.role : null);
    notifyListeners();
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _setBusy(true);
    final result = await _authService.login(email: email, password: password);
    if (!result.ok || result.data == null) {
      _setBusy(false);
      return result.errorMessage;
    }

    await session.save(
      accessToken: result.data!.accessToken,
      refreshToken: result.data!.refreshToken,
      role: result.data!.role,
    );
    _status = _statusFromRole(result.data!.role);
    _setBusy(false);
    return null;
  }

  Future<void> signOut() async {
    await session.clear();
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  static AuthStatus _statusFromRole(String? role) {
    switch (role) {
      case UserRole.coach:
        return AuthStatus.coach;
      case UserRole.student:
        return AuthStatus.student;
      default:
        return AuthStatus.signedOut;
    }
  }
}
