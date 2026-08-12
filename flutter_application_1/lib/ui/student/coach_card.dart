import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/coach.dart';
import '../widgets/common.dart';

/// Koç bilgisini gösteren kart.
///
/// İki görünümü var:
/// * [compact] — koç arama listesi için tek satırlık, ince kart. Kartın kendisi
///   tıklanabilir, ayrı bir buton yer kaplamasın diye.
/// * varsayılan — "Koçum" ekranındaki ayrıntılı kart (iletişim bilgisi ve
///   alttaki aksiyon düğmesiyle).
///
/// Koçun kaç öğrencisi olduğu hiçbir görünümde yazılmıyor; sadece kalan
/// kontenjan gösteriliyor.
class CoachCard extends StatelessWidget {
  const CoachCard({
    super.key,
    required this.coach,
    this.action,
    this.onTap,
    this.showContact = false,
    this.compact = false,
  });

  final Coach coach;
  final Widget? action;
  final VoidCallback? onTap;

  /// Aktif koç için e-posta da gösterilir.
  final bool showContact;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        _Avatar(name: coach.displayName),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                coach.displayName,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (coach.speciality.isNotEmpty) coach.speciality,
                  if (coach.gender.isNotEmpty) Gender.label(coach.gender),
                ].join(' · '),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.gapSmall),
        if (coach.isFull)
          const StatusPill.warning('Kontenjan dolu')
        else
          StatusPill.success('${coach.freeSlots} boş yer'),
        if (compact) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.person_add_alt_1_outlined,
            size: 20,
            color: AppColors.primary,
          ),
        ],
      ],
    );

    if (compact) {
      return AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
        child: header,
      );
    }

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (showContact && coach.email.isNotEmpty) ...[
            const SizedBox(height: AppSizes.gapSmall),
            InfoRow('E-posta', coach.email),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSizes.gap),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Baş harften oluşan basit avatar — profil fotoğrafı henüz yok.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();

    return Container(
      width: AppSizes.avatar,
      height: AppSizes.avatar,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
