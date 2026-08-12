import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../widgets/common.dart';
import 'auth_scaffold.dart';
import 'coach_register_screen.dart';
import 'student_register_screen.dart';

/// Kayıt akışının ilk adımı: öğrenci mi koç mu?
class RegisterChoiceScreen extends StatelessWidget {
  const RegisterChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Kayıt ol',
      subtitle: 'Hangi rolle devam edeceksin?',
      children: [
        _RoleCard(
          icon: Icons.person_outline,
          title: 'Öğrenci',
          description:
              'Koç seç, sana yazılan antrenmanı uygula; öğün ve uyku verini gir.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const StudentRegisterScreen(),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gap),
        _RoleCard(
          icon: Icons.sports_outlined,
          title: 'Koç',
          description:
              'Öğrenci isteklerini yönet, antrenman programı yaz, gelişimi takip et.',
          hint: 'CV ve sertifika yüklemen gerekir.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CoachRegisterScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.avatar,
            height: AppSizes.avatar,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (hint != null) ...[
                  const SizedBox(height: 8),
                  Text(hint!, style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
