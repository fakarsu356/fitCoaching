import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_fmt.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'complete_workout_sheet.dart';
import 'workout_progress.dart';

/// Antrenman sekmesi: yapılacak antrenman ve son iki seans.
///
/// Ekran bilerek kısa: üstte sıradaki antrenman, altında en son yapılan iki
/// antrenman. Her set, aynı programın bir önceki seansındaki değeriyle
/// karşılaştırılıyor — toplam hacim gibi birleşik bir sayı gösterilmiyor,
/// gelişim set bazında okunuyor.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  /// Geçmişin ne kadar geriye taranacağı. Ekranda son iki seans görünse de
  /// kıyas için aynı programın daha eski seansları gerekiyor.
  static const Duration _historyRange = Duration(days: 180);

  /// Listede gösterilen seans sayısı.
  static const int _visibleSessions = 2;

  Workout? _plan;
  List<Workout>? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final services = context.read<AppServices>();
    final now = DateTime.now();
    final results = await Future.wait([
      services.workouts.getTodayPlan(),
      services.workouts.getWorkoutsByDate(
        start: now.subtract(_historyRange),
        end: now,
      ),
    ]);
    final planResult = results[0];
    final historyResult = results[1];

    if (!mounted) return;
    setState(() {
      _loading = false;

      // Bekleyen plan olmadığında backend ayrı bir durum yerine hata
      // döndürüyor; bu yüzden plan hatası ekranı düşürmez, bölüm boş görünür.
      _plan = planResult.ok ? planResult.data as Workout? : null;

      if (historyResult.ok) {
        _history =
            (historyResult.data as List?)?.cast<Workout>() ?? const <Workout>[];
      } else if ((historyResult.message ?? '').contains('no workouts')) {
        // Hiç kayıt yok; backend bunu da hata olarak döndürüyor.
        _history = const <Workout>[];
      } else {
        _error = historyResult.errorMessage;
      }
    });
  }

  /// Öğrencinin gerçekten yaptığı antrenmanlar (yeniden eskiye).
  ///
  /// Koçun planları listelenmiyor: yapılan her seans zaten kaynak planına
  /// bağlı, planın kendisi ayrıca gösterilirse aynı antrenman iki kez görünür.
  List<Workout> get _sessions {
    return [
      for (final workout in _history ?? const <Workout>[])
        if (workout.byStudent) workout,
    ];
  }

  Future<void> _completePlan(Workout plan, WorkoutProgress progress) async {
    final saved = await showCompleteWorkoutSheet(
      context,
      plan: plan,
      previousSets: progress.previousSetsFor(plan),
    );
    if (!saved || !mounted) return;
    showAppSnack(context, 'Antrenman kaydedildi');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrenman'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: AsyncContent<List<Workout>>(
        loading: _loading,
        error: _error,
        data: _history,
        onRetry: _load,
        builder: (_) {
          final plan = _plan;
          final sessions = _sessions;
          final progress = WorkoutProgress(sessions);
          final recent = sessions.take(_visibleSessions).toList();

          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              children: [
                SectionTitle(
                  'Yapılacak antrenman',
                  subtitle: plan == null
                      ? null
                      : 'Setlerin altında aynı programın önceki seansı yazıyor.',
                ),
                if (plan == null)
                  const _InfoCard(
                    icon: Icons.fitness_center_outlined,
                    message:
                        'Bekleyen antrenman programın yok. Koçun program '
                        'yazınca burada görünecek.',
                  )
                else
                  _PlanCard(
                    plan: plan,
                    previousSets: progress.previousSetsFor(plan),
                    onComplete: () => _completePlan(plan, progress),
                  ),
                const SizedBox(height: AppSizes.gapLarge),
                SectionTitle(
                  'Son antrenmanların',
                  subtitle: recent.isEmpty
                      ? null
                      : 'Her seans kendi programının bir öncekiyle '
                            'karşılaştırıldı.',
                ),
                if (recent.isEmpty)
                  const EmptyState(
                    icon: Icons.history,
                    title: 'Henüz antrenman kaydı yok',
                    description:
                        'Koçunun programını tamamladığında son antrenmanların '
                        'burada görünecek.',
                  )
                else
                  for (final session in recent) ...[
                    _SessionCard(
                      session: session,
                      previousSets: progress.previousSetsFor(session),
                    ),
                    const SizedBox(height: AppSizes.gapSmall),
                  ],
                const SizedBox(height: AppSizes.gapLarge),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Antrenmanın hareketlerinden okunur bir başlık üretir.
String _workoutTitle(Workout workout) {
  final movements = workout.movements;
  return movements.isEmpty ? 'Antrenman' : movements.join(', ');
}

/// İkon + açıklama satırından oluşan bilgi kartı.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kart başlığı: renkli ikon kutusu + başlık/alt başlık + sağ aksiyon.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppSizes.avatar,
          height: AppSizes.avatar,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Koçun not kutusu — plan ve seans kartlarında aynı görünür.
class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.label, required this.note});

  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSizes.gapSmall),
      padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Text(
        '$label: $note',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// Sıradaki antrenman: koç notu, set set plan ve tamamlama düğmesi.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.previousSets,
    required this.onComplete,
  });

  final Workout plan;
  final Map<String, WorkoutSet> previousSets;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final byMovement = groupByMovement(plan.sets);
    final note = plan.notes.trim();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.fitness_center,
            iconColor: AppColors.primary,
            iconBackground: AppColors.primarySoft,
            title: _workoutTitle(plan),
            subtitle:
                '${AppDate.relative(plan.date)} · ${byMovement.length} hareket '
                '· ${plan.totalSets} set',
            trailing: const StatusPill.warning('Bekliyor'),
          ),
          if (note.isNotEmpty) _NoteBox(label: 'Koç notu', note: note),
          const SizedBox(height: AppSizes.gapSmall),
          const Divider(height: 1, color: AppColors.border),
          for (final entry in byMovement.entries)
            _MovementSets(
              name: entry.key,
              sets: entry.value,
              previousSets: previousSets,
            ),
          const SizedBox(height: AppSizes.gapSmall),
          ElevatedButton(
            onPressed: onComplete,
            child: const Text('Antrenmanı tamamla'),
          ),
        ],
      ),
    );
  }
}

/// Yapılmış bir seans: tarihi, notu ve önceki seansa göre farklarıyla setleri.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.previousSets});

  final Workout session;
  final Map<String, WorkoutSet> previousSets;

  @override
  Widget build(BuildContext context) {
    final byMovement = groupByMovement(session.sets);
    final note = session.notes.trim();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.check_circle_outline,
            iconColor: AppColors.success,
            iconBackground: AppColors.successSoft,
            title: _workoutTitle(session),
            subtitle:
                '${AppDate.relative(session.date)} · ${byMovement.length} '
                'hareket · ${session.totalSets} set',
            trailing: const StatusPill.success('Tamamlandı'),
          ),
          if (note.isNotEmpty) _NoteBox(label: 'Notun', note: note),
          const SizedBox(height: AppSizes.gapSmall),
          const Divider(height: 1, color: AppColors.border),
          for (final entry in byMovement.entries)
            _MovementSets(
              name: entry.key,
              sets: entry.value,
              previousSets: previousSets,
            ),
        ],
      ),
    );
  }
}

/// Bir hareketin adı ve altındaki set satırları.
class _MovementSets extends StatelessWidget {
  const _MovementSets({
    required this.name,
    required this.sets,
    required this.previousSets,
  });

  final String name;
  final List<WorkoutSet> sets;
  final Map<String, WorkoutSet> previousSets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.gapSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleSmall),
          for (final set in sets)
            _SetRow(
              set: set,
              previous: previousSets[setKey(set.movementName, set.setNumber)],
            ),
        ],
      ),
    );
  }
}

/// "Set 1 · 10 tekrar × 40 kg · önceki 10 × 37,5 kg · +2,5 kg" satırı.
class _SetRow extends StatelessWidget {
  const _SetRow({required this.set, required this.previous});

  final WorkoutSet set;
  final WorkoutSet? previous;

  @override
  Widget build(BuildContext context) {
    final before = previous;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSizes.setLabelWidth,
            child: Text(
              'Set ${set.setNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setLine(set),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (before != null)
                  Text(
                    'önceki ${setLineShort(before)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.gapSmall),
          SetDiffBadges(
            weight: set.weight,
            reps: set.reps,
            previous: before,
          ),
        ],
      ),
    );
  }
}
