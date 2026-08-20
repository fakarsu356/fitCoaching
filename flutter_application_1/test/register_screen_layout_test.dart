import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/core/api_client.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/core/theme.dart';
import 'package:flutter_application_1/services/services.dart';
import 'package:flutter_application_1/ui/auth/coach_register_screen.dart';
import 'package:flutter_application_1/ui/auth/email_verification_field.dart';
import 'package:flutter_application_1/ui/auth/student_register_screen.dart';

/// Kayıt ekranları servisleri yalnızca kullanıcı bir düğmeye bastığında
/// çağırıyor; çizim için gerçek bir ağ katmanı gerekmiyor, sağlayıcıların
/// yerinde olması yeterli.
Widget _wrap(Widget child) {
  final session = Session();
  final client = ApiClient(session: session);

  return MultiProvider(
    providers: [
      Provider<Session>.value(value: session),
      Provider<ApiClient>.value(value: client),
      Provider<AppServices>.value(value: AppServices(client)),
    ],
    child: MaterialApp(theme: AppTheme.light, home: child),
  );
}

void main() {
  // Doğrulama alanı satır içinde bir OutlinedButton taşıyor; temadaki
  // `minimumSize: Size.fromHeight(48)` en küçük genişliği sonsuz yaptığı için
  // bu düğme yerleşimi patlatabiliyor. Test ekranların hatasız çizildiğini
  // doğruluyor.
  testWidgets('Koç kayıt ekranı yerleşim hatası vermeden çizilir', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const CoachRegisterScreen()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(EmailVerificationField), findsOneWidget);
    expect(find.text('Kod gönder'), findsOneWidget);
  });

  testWidgets('Öğrenci kayıt ekranı yerleşim hatası vermeden çizilir', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const StudentRegisterScreen()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(EmailVerificationField), findsOneWidget);
  });

  testWidgets('Dar ekranda da taşma olmuyor', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const CoachRegisterScreen()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
