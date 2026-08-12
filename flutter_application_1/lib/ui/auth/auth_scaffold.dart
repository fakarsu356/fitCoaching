import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Giriş/kayıt ekranlarının ortak iskeleti: dar kolonlu, beyaz.
///
/// [title] verilmezse başlık bloğu hiç çizilmez; giriş ekranı başlık yerine
/// [AppWordmark] kullanıyor. [alignTop] içeriği dikeyde ortalamak yerine
/// yukarı yaslar.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.showBack = true,
    this.alignTop = false,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Align(
          alignment: alignTop ? Alignment.topCenter : Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.gapLarge,
              AppSizes.pagePadding,
              AppSizes.gapLarge,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSizes.gapLarge),
                  ],
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uygulama adı + kısa açıklama. Sadece giriş ekranında kullanılıyor.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppSizes.avatar,
          height: AppSizes.avatar,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppSizes.radius),
          ),
          child: const Icon(
            Icons.fitness_center,
            size: 22,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'FitCoaching',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Koç ve öğrenci tek yerde',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// Form üstünde gösterilen sunucu hatası.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Form alanları arasında kullanılan standart boşluk.
const SizedBox formGap = SizedBox(height: AppSizes.gap);
const SizedBox formGapLarge = SizedBox(height: AppSizes.gapLarge);
