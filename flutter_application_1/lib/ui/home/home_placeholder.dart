import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../widgets/common.dart';

/// Giriş sonrası geçici ekran. Koç ve öğrenci panelleri sonraki adımda
/// yazılacak; şu an sadece oturumun kurulduğunu doğrulamaya yarıyor.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key, required this.isCoach});

  final bool isCoach;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isCoach ? 'Koç paneli' : 'Öğrenci paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış yap',
            onPressed: () async {
              final confirmed = await confirmDialog(
                context,
                title: 'Çıkış yap',
                message: 'Oturumun kapatılacak. Devam edilsin mi?',
                confirmLabel: 'Çıkış yap',
                destructive: true,
              );
              if (confirmed) await auth.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: EmptyState(
          icon: Icons.construction_outlined,
          title: 'Giriş başarılı',
          description: isCoach
              ? 'Öğrenci istekleri, antrenman programı ve takip ekranları '
                    'bir sonraki adımda eklenecek.'
              : 'Koç seçimi, antrenman, öğün ve uyku ekranları bir sonraki '
                    'adımda eklenecek.',
        ),
      ),
    );
  }
}
