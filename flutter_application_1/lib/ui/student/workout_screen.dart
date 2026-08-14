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
  /// Yapılmış planlar listelenmiyor: yapılan her seans zaten kaynak planına
  /// bağlı, planın kendisi ayrıca gösterilirse aynı antrenman iki kez görünür.
  /// Kıyas da yalnızca bunlar üzerinden kurulur — koçun yazdığı hedef değerler
  /// "önceki seans" sayılmaz.
  List<Workout> get _sessions {
    return [
      for (final workout in _history ?? const <Workout>[])
        if (workout.byStudent) workout,
    ];
  }

  /// Koçun yazdığı, henüz yapılmamış programlar (yeniden eskiye).
  ///
  /// Üstteki bölüm bunlardan yalnızca birini gösteriyor; kalanı burada
  /// görünmezse öğrenci kendisine kaç program yazıldığını hiç göremiyor.
  List<Workout> get _pendingPlans {
    final currentId = _plan?.id;
    return [
      for (final workout in _history ?? const <Workout>[])
        if (!workout.byStudent && !workout.isDone && workout.id != currentId)
          workout,
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
        skeleton: const _WorkoutSkeleton(),
        builder: (_) {
          final plan = _plan;
          final sessions = _sessions;
          final progress = WorkoutProgress(sessions);
          final recent = sessions.take(_visibleSessions).toList();
          final pending = _pendingPlans;

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
                  _WorkoutCard(
                    workout: plan,
                    previousSets: progress.previousSetsFor(plan),
                    onComplete: () => _completePlan(plan, progress),
                  ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.gapLarge),
                  const SectionTitle(
                    'Sıradaki diğer programlar',
                    subtitle: 'Koçunun yazdığı, henüz yapmadığın programlar.',
                  ),
                  for (final workout in pending) ...[
                    _WorkoutCard(
                      workout: workout,
                      previousSets: progress.previousSetsFor(workout),
                      // Reddedilmiş bir program doldurulamaz; düğme yalnızca
                      // gerçekten bekleyen programlarda çıkar.
                      onComplete: workout.isWaiting
                          ? () => _completePlan(workout, progress)
                          : null,
                    ),
                    const SizedBox(height: AppSizes.gapSmall),
                  ],
                ],
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
                    _WorkoutCard(
                      workout: session,
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

/// Ekranın yüklenirken görünen hâli.
///
/// Bölüm başlıkları gerçek metinleriyle duruyor: yüklenirken de ekranın neyi
/// göstereceği okunuyor, veri gelince yalnızca kartların içi değişiyor.
class _WorkoutSkeleton extends StatelessWidget {
  const _WorkoutSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: const [
        SectionTitle('Yapılacak antrenman'),
        _WorkoutCardSkeleton(setRows: 3),
        SizedBox(height: AppSizes.gapLarge),
        SectionTitle('Son antrenmanların'),
        _WorkoutCardSkeleton(setRows: 2),
      ],
    );
  }
}

/// Antrenman kartının iskeleti: başlık satırı, ayraç ve set satırları.
class _WorkoutCardSkeleton extends StatelessWidget {
  const _WorkoutCardSkeleton({required this.setRows});

  final int setRows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Skeleton(
                width: AppSizes.avatar,
                height: AppSizes.avatar,
                radius: AppSizes.radiusSmall,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 168, height: 15),
                    SizedBox(height: 6),
                    Skeleton(width: 128, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              const Skeleton(
                width: 68,
                height: 22,
                radius: AppSizes.radiusSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gapSmall),
          const Divider(height: 1, color: AppColors.border),
          for (var i = 0; i < setRows; i++)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.gapSmall),
              child: Row(
                children: [
                  const SizedBox(
                    width: AppSizes.setLabelWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Skeleton(width: 34, height: 11),
                    ),
                  ),
                  // Align olmadan Expanded genişliği dayatır ve bloklar
                  // satırın tamamını kaplar; metin izlenimi kaybolur.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Skeleton(width: 120 + i * 28, height: 13),
                    ),
                  ),
                  const SizedBox(width: AppSizes.gapSmall),
                  const Skeleton(width: 58, height: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Antrenmanın hareketlerinden okunur bir başlık üretir.
String _workoutTitle(Workout workout) {
  final movements = workout.movements;
  return movements.isEmpty ? 'Antrenman' : movements.join(', ');
}

/// Kartın başlık ikonu ve rozeti kaydın kendi durumundan üretilir.
///
/// Sabit etiket yazılmıyor: aksi hâlde bekleyen bir program da "Tamamlandı"
/// görünür ve ekran veriyle çelişir.
({IconData icon, Color color, Color background, Widget pill}) _statusStyle(
  String status,
) {
  final label = WorkoutStatus.label(status);
  switch (status) {
    case WorkoutStatus.done:
      return (
        icon: Icons.check_circle_outline,
        color: AppColors.success,
        background: AppColors.successSoft,
        pill: StatusPill.success(label),
      );
    case WorkoutStatus.rejected:
      return (
        icon: Icons.cancel_outlined,
        color: AppColors.danger,
        background: AppColors.dangerSoft,
        pill: StatusPill.danger(label),
      );
    case WorkoutStatus.waiting:
      return (
        icon: Icons.fitness_center,
        color: AppColors.primary,
        background: AppColors.primarySoft,
        pill: StatusPill.warning(label),
      );
    default:
      return (
        icon: Icons.help_outline,
        color: AppColors.textSecondary,
        background: AppColors.surfaceMuted,
        pill: StatusPill(label),
      );
  }
}

/// Kart alt başlığı: "Bugün · 3 hareket · 9 set".
String _workoutSubtitle(Workout workout, int movementCount) {
  return '${AppDate.relative(workout.date)} · $movementCount hareket '
      '· ${workout.totalSets} set';
}

/// Seti olmayan antrenmanın uyarısı.
///
/// Backend setsiz bir programı da başarıyla döndürebiliyor; kart sessizce
/// "0 set" göstermek yerine durumu açıkça yazıyor.
const _emptySetsMessage =
    'Bu programda hiç set kayıtlı değil. Koçunun program yazarken setleri '
    'kaydedememiş olması muhtemel, koçuna haber ver.';

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

/// Bir antrenman kaydı: tarihi, notu ve önceki seansa göre farklarıyla setleri.
///
/// Hem öğrencinin yaptığı seanslar hem de koçun bekleyen programları bu kartla
/// çiziliyor. Bekleyen her programda tamamlama düğmesi bulunur — ayrı bir
/// "plan kartı" tutulduğunda düğme yalnızca en üstteki programa konuyordu ve
/// alttaki programlar doldurulamıyordu.
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.previousSets,
    this.onComplete,
  });

  final Workout workout;
  final Map<String, WorkoutSet> previousSets;

  /// Yalnızca doldurulabilir (bekleyen) programlarda verilir; yapılmış
  /// seanslarda null.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final byMovement = groupByMovement(workout.sets);
    final note = workout.notes.trim();
    final style = _statusStyle(workout.status);

    // Seti olmayan program tamamlanamaz: form boş açılır ve kaydedilirse
    // geriye setsiz bir seans kaydı kalır.
    final hasSets = workout.sets.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: style.icon,
            iconColor: style.color,
            iconBackground: style.background,
            title: _workoutTitle(workout),
            subtitle: _workoutSubtitle(workout, byMovement.length),
            trailing: style.pill,
          ),
          if (note.isNotEmpty)
            _NoteBox(
              label: workout.byStudent ? 'Notun' : 'Koç notu',
              note: note,
            ),
          const SizedBox(height: AppSizes.gapSmall),
          const Divider(height: 1, color: AppColors.border),
          if (!hasSets)
            const Padding(
              padding: EdgeInsets.only(top: AppSizes.gapSmall),
              child: _InfoCard(
                icon: Icons.error_outline,
                message: _emptySetsMessage,
              ),
            )
          else
            for (final entry in byMovement.entries)
              _MovementSets(
                name: entry.key,
                sets: entry.value,
                previousSets: previousSets,
              ),
          if (onComplete != null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            ElevatedButton(
              onPressed: hasSets ? onComplete : null,
              child: const Text('Antrenmanı tamamla'),
            ),
          ],
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
