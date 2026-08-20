import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/core/api_client.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/core/theme.dart';
import 'package:flutter_application_1/services/services.dart';
import 'package:flutter_application_1/state/auth_controller.dart';
import 'package:flutter_application_1/ui/coach/coach_shell.dart';

/// Koç sekmeleri açılır açılmaz sunucuya gidiyor. Testte sunucu yok; istekler
/// hataya düşerken arkada dio'nun zamanlayıcıları kalıyor ve test çatısı
/// "A Timer is still pending" diye şikâyet ediyor. [tester.runAsync] içinde
/// gerçek zamanı akıtmak, isteklerin bitmesine izin veriyor.
Widget _wrap(Widget child) {
  final session = Session();
  // Ulaşılamayan adres: istek hızlı düşsün, test ağ beklemesin.
  final client = ApiClient(session: session, baseUrl: 'http://127.0.0.1:1');
  return MultiProvider(
    providers: [
      Provider<Session>.value(value: session),
      Provider<ApiClient>.value(value: client),
      Provider<AppServices>.value(value: AppServices(client)),
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(session: session, client: client),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: child),
  );
}

void main() {
  testWidgets('Koç kabuğu dört sekmeyle hatasız çizilir', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(_wrap(const CoachShell()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Öğrencilerim'), findsWidgets);
      expect(find.text('İstekler'), findsWidgets);
      expect(find.text('Programlar'), findsWidgets);
      expect(find.text('Profil'), findsWidgets);

      // İstekler düşene kadar bekle ki geride zamanlayıcı kalmasın.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Profil sekmesi yerleşim hatası vermeden açılır', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(_wrap(const CoachShell()));
      await tester.pump();

      await tester.tap(find.text('Profil').last);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Sunucu olmadığı için profil hata durumunda çiziliyor; testin amacı
      // ekranın yerleşim hatası vermeden bağlanması.
    });
  });
}
