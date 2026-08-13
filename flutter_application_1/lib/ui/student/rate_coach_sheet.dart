import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/coach.dart';
import '../../services/services.dart';
import '../widgets/common.dart';

/// Ayrılınan koça puan/yorum bırakma. Kaydedilirse `true` döner.
/// Backend puanlamaya yalnızca ilişki `breakup` durumundayken izin veriyor.
Future<bool> showRateCoachSheet(BuildContext context, Coach coach) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radius),
      ),
    ),
    builder: (_) => _RateCoachSheet(coach: coach),
  );
  return saved ?? false;
}

class _RateCoachSheet extends StatefulWidget {
  const _RateCoachSheet({required this.coach});

  final Coach coach;

  @override
  State<_RateCoachSheet> createState() => _RateCoachSheetState();
}

class _RateCoachSheetState extends State<_RateCoachSheet> {
  final _description = TextEditingController();
  int _score = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score == 0) {
      setState(() => _error = 'Puan seçmelisin');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await context.read<AppServices>().ratings.addRating(
      coachId: widget.coach.userId,
      score: _score,
      description: _description.text.trim(),
    );

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.errorMessage;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.pagePadding,
        right: AppSizes.pagePadding,
        top: AppSizes.pagePadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.pagePadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Koçunu değerlendir',
            subtitle: widget.coach.displayName,
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Row(
            children: List.generate(5, (index) {
              final value = index + 1;
              final filled = value <= _score;
              return IconButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _score = value;
                        _error = null;
                      }),
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 34,
                  color: filled ? AppColors.rating : AppColors.borderStrong,
                ),
                tooltip: '$value puan',
              );
            }),
          ),
          const SizedBox(height: AppSizes.gapSmall),
          LabeledField(
            label: 'Yorumun',
            hint: 'İstersen boş bırakabilirsin.',
            child: TextField(
              controller: _description,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Süreç nasıl geçti?',
                counterText: '',
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSizes.gap),
            Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSizes.gap),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Puanı gönder'),
          ),
        ],
      ),
    );
  }
}
