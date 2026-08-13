import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/num_fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'workout_progress.dart';

/// Koçun planındaki setleri gerçek tekrar/ağırlık değerleriyle doldurup
/// antrenmanı kaydettirir. Kaydedilirse `true` döner.
///
/// [previousSets]: [setKey] anahtarlı, aynı programın önceki seansındaki
/// setler. Öğrenci yazarken farkı anında görsün diye kullanılıyor.
Future<bool> showCompleteWorkoutSheet(
  BuildContext context, {
  required Workout plan,
  required Map<String, WorkoutSet> previousSets,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radius),
      ),
    ),
    builder: (_) => _CompleteWorkoutSheet(plan: plan, previous: previousSets),
  );
  return saved ?? false;
}

class _CompleteWorkoutSheet extends StatefulWidget {
  const _CompleteWorkoutSheet({required this.plan, required this.previous});

  final Workout plan;
  final Map<String, WorkoutSet> previous;

  @override
  State<_CompleteWorkoutSheet> createState() => _CompleteWorkoutSheetState();
}

class _CompleteWorkoutSheetState extends State<_CompleteWorkoutSheet> {
  /// Plan setleriyle aynı sırada; i. set için i. denetleyiciler kullanılır.
  late final List<TextEditingController> _reps;
  late final List<TextEditingController> _weights;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Plandaki değerlerle önceden doldurulur; öğrenci sadece değişeni düzeltir.
    _reps = [
      for (final set in widget.plan.sets)
        TextEditingController(text: set.reps.toString()),
    ];
    _weights = [
      for (final set in widget.plan.sets)
        TextEditingController(text: formatNumber(set.weight)),
    ];
  }

  @override
  void dispose() {
    for (final controller in _reps) {
      controller.dispose();
    }
    for (final controller in _weights) {
      controller.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  /// Plan setinin listedeki sırası — denetleyicileri bulmak için.
  int _indexOf(WorkoutSet set) => widget.plan.sets.indexOf(set);

  int? _repsAt(int index) {
    final value = int.tryParse(_reps[index].text.trim());
    return (value == null || value <= 0) ? null : value;
  }

  double? _weightAt(int index) {
    final value = double.tryParse(
      _weights[index].text.trim().replaceAll(',', '.'),
    );
    return (value == null || value < 0) ? null : value;
  }

  Future<void> _submit() async {
    final userId = context.read<Session>().userId;
    if (userId == null) {
      setState(() => _error = 'Oturum bilgisi okunamadı, tekrar giriş yap');
      return;
    }

    final sets = <WorkoutSet>[];
    for (var i = 0; i < widget.plan.sets.length; i++) {
      final reps = _repsAt(i);
      final weight = _weightAt(i);
      if (reps == null || weight == null) {
        setState(() => _error = 'Tekrar ve ağırlık değerlerini kontrol et');
        return;
      }
      sets.add(widget.plan.sets[i].copyWith(reps: reps, weight: weight));
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await context.read<AppServices>().workouts
        .saveStudentWorkout(
          studentId: userId,
          sourcePlanId: widget.plan.id,
          note: _note.text.trim(),
          sets: sets,
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
    final byMovement = groupByMovement(widget.plan.sets);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            const SectionTitle(
              'Antrenmanı tamamla',
              subtitle:
                  'Gerçekte yaptığın tekrar ve ağırlıkları gir; fark aynı '
                  'programın önceki seansına göre hesaplanıyor.',
            ),
            for (final entry in byMovement.entries) ...[
              const SizedBox(height: AppSizes.gapSmall),
              Text(entry.key, style: Theme.of(context).textTheme.titleSmall),
              for (final set in entry.value) _buildSetRow(set),
            ],
            const SizedBox(height: AppSizes.gap),
            LabeledField(
              label: 'Not (isteğe bağlı)',
              child: TextField(
                controller: _note,
                enabled: !_busy,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Antrenman nasıl geçti?',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.gapSmall),
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
                  : const Text('Antrenmanı kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(WorkoutSet set) {
    final index = _indexOf(set);
    final before = widget.previous[setKey(set.movementName, set.setNumber)];
    final reps = _repsAt(index);
    final weight = _weightAt(index);

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.gapSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: AppSizes.setLabelWidth,
                child: Text(
                  'Set ${set.setNumber}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _reps[index],
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  // Fark rozetleri yazdıkça güncellensin.
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(suffixText: 'tekrar'),
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: TextField(
                  controller: _weights[index],
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(suffixText: 'kg'),
                ),
              ),
            ],
          ),
          if (before != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSizes.setLabelWidth,
                top: 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'önceki ${setLineShort(before)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  if (reps != null && weight != null)
                    SetDiffBadges(
                      weight: weight,
                      reps: reps,
                      previous: before,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
