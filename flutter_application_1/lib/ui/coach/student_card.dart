import 'package:flutter/material.dart';

import '../../core/num_fmt.dart';
import '../../core/theme.dart';
import '../../models/relation.dart';
import '../widgets/common.dart';

/// Koç tarafındaki öğrenci satırı.
///
/// `CoachCard`'ın öğrenci karşılığı: aynı kart ölçüleri ve avatar boyutu
/// kullanılır ki iki tarafın listeleri aynı ritimde görünsün.
class StudentCard extends StatelessWidget {
  const StudentCard({
    super.key,
    required this.student,
    this.onTap,
    this.trailing,
  });

  final Student student;
  final VoidCallback? onTap;

  /// Sağ taraftaki aksiyon alanı (istek ekranında onay/ret butonları).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bmi = student.bmi;

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
      onTap: onTap,
      child: Row(
        children: [
          const _StudentAvatar(),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  student.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  _summary(student),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_bodySummary(student, bmi) case final body?) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSizes.gapSmall),
            trailing!,
          ] else if (onTap != null)
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textMuted,
            ),
        ],
      ),
    );
  }

  /// Yaş / kilo / boy tek satırda; eksik alanlar (0 gelenler) atlanır ki
  /// "0 kg" gibi anlamsız değerler listede durmasın.
  String _summary(Student student) {
    final parts = <String>[
      if (student.age > 0) '${student.age} yaş',
      if (student.bodyWeight > 0) '${formatNumber(student.bodyWeight)} kg',
      if (student.bodyHeight > 0) '${formatNumber(student.bodyHeight)} cm',
    ];
    return parts.isEmpty ? 'Bilgileri henüz girilmemiş' : parts.join(' · ');
  }

  /// Yağ oranı ve VKİ ikinci satırda: hepsi tek satıra sığdırılınca uzun
  /// isimlerde kırpılıp koçun listede görmesi gereken bilgi kayboluyordu.
  String? _bodySummary(Student student, double? bmi) {
    final parts = <String>[
      if (student.fatPercentage > 0)
        '%${formatNumber(student.fatPercentage)} yağ',
      if (bmi != null) 'VKİ ${formatNumber(bmi)}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.avatar,
      height: AppSizes.avatar,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: const Icon(
        Icons.person_outline,
        color: AppColors.primary,
        size: 22,
      ),
    );
  }
}
