import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'services/services.dart';
import 'state/auth_controller.dart';
import 'ui/auth/login_screen.dart';
import 'ui/home/home_placeholder.dart';
import 'ui/student/student_coach_screen.dart';

void main() {
  runApp(const FitCoachingApp());
}

class FitCoachingApp extends StatefulWidget {
  const FitCoachingApp({super.key});

  @override
  State<FitCoachingApp> createState() => _FitCoachingAppState();
}

class _FitCoachingAppState extends State<FitCoachingApp> {
  late final Session _session;
  late final ApiClient _client;
  late final AppServices _services;
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _session = Session();
    _client = ApiClient(session: _session);
    _services = AppServices(_client);
    // Diskteki oturum okunana kadar AuthStatus.unknown kalır, açılışta
    // splash gösterilir.
    _auth = AuthController(session: _session, client: _client)..bootstrap();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Session>.value(value: _session),
        Provider<ApiClient>.value(value: _client),
        Provider<AppServices>.value(value: _services),
        ChangeNotifierProvider<AuthController>.value(value: _auth),
      ],
      child: MaterialApp(
        title: 'FitCoaching',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppRoot(),
      ),
    );
  }
}

/// Oturum durumuna göre doğru ekranı gösterir; ekranlar arası elle yönlendirme
/// yapılmaz, [AuthController] değişince buradan yenilenir.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthController>().status;

    switch (status) {
      case AuthStatus.unknown:
        return const _SplashScreen();
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.coach:
        return const HomePlaceholderScreen(isCoach: true);
      case AuthStatus.student:
        // Antrenman ve takip sekmeleri eklendiğinde burası alt menülü bir
        // kabuğa dönüşecek; şu an tek ekran var.
        return const StudentCoachScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
  }
}
