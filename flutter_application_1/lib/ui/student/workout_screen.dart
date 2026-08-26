import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_fmt.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'complete_workout_sheet.dart';
import 'workout_progress.dart';

/// Antrenman sekmesi: yapÄ±lacak antrenman ve son iki seans.
///
/// Ekran bilerek kÄ±sa: Ã¼stte sÄ±radaki antrenman, altÄ±nda en son yapÄ±lan iki
/// antrenman. Her set, aynÄ± programÄ±n bir Ã¶nceki seansÄ±ndaki deÄeriyle
/// karÅÄ±laÅtÄ±rÄ±lÄ±yor â toplam hacim gibi birleÅik bir sayÄ± gÃ¶sterilmiyor,
/// geliÅim set bazÄ±nda okunuyor.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  /// GeÃ§miÅin ne kadar geriye taranacaÄÄ±. Ekranda son iki seans gÃ¶rÃ¼nse de
  /// kÄ±yas iÃ§in aynÄ± programÄ±n daha eski seanslarÄ± gerekiyor.
  static const Duration _historyRange = Duration(days: 180);

  /// Listede gÃ¶sterilen seans sayÄ±sÄ±.
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

      // Bekleyen plan olmadÄ±ÄÄ±nda backend ayrÄ± bir durum yerine hata
      // dÃ¶ndÃ¼rÃ¼yor; bu yÃ¼zden plan hatasÄ± ekranÄ± dÃ¼ÅÃ¼rmez, bÃ¶lÃ¼m boÅ gÃ¶rÃ¼nÃ¼r.
      _plan = planResult.ok ? planResult.data as Workout? : null;

      if (historyResult.ok) {
        _history =
            (historyResult.data as List?)?.cast<Workout>() ?? const <Workout>[];
      } else if ((historyResult.message ?? '').contains('no workouts')) {
        // HiÃ§ kayÄ±t yok; backend bunu da hata olarak dÃ¶ndÃ¼rÃ¼yor.
        _history = const <Workout>[];
      } else {
        _error = historyResult.errorMessage;
      }
    });
  }

  /// ÃÄrencinin gerÃ§ekten yaptÄ±ÄÄ± antrenmanlar (yeniden eskiye).
  ///
  /// YapÄ±lmÄ±Å planlar listelenmiyor: yapÄ±lan her seans zaten kaynak planÄ±na
  /// baÄlÄ±, planÄ±n kendisi ayrÄ±ca gÃ¶sterilirse aynÄ± antrenman iki kez gÃ¶rÃ¼nÃ¼r.
  /// KÄ±yas da yalnÄ±zca bunlar Ã¼zerinden kurulur â koÃ§un yazdÄ±ÄÄ± hedef deÄerler
  /// "Ã¶nceki seans" sayÄ±lmaz.
  List<Workout> get _sessions {
    return [
      for (final workout in _history ?? const <Workout>[])
        if (workout.byStudent) workout,
    ];
  }

  /// KoÃ§un yazdÄ±ÄÄ±, henÃ¼z yapÄ±lmamÄ±Å programlar (yeniden eskiye).
  ///
  /// Ãstteki bÃ¶lÃ¼m bunlardan yalnÄ±zca birini gÃ¶steriyor; kalanÄ± burada
  /// gÃ¶rÃ¼nmezse Ã¶Ärenci kendisine kaÃ§ program yazÄ±ldÄ±ÄÄ±nÄ± hiÃ§ gÃ¶remiyor.
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
                  'YapÄ±lacak antrenman',
                  subtitle: plan == null
                      ? null
                      : 'Setlerin altÄ±nda aynÄ± programÄ±n Ã¶nceki seansÄ± yazÄ±yor.',
                ),
                if (plan == null)
                  const _InfoCard(
                    icon: Icons.fitness_center_outlined,
                    message:
                        'Bekleyen antrenman programÄ±n yok. KoÃ§un program '
                        'yazÄ±nca burada gÃ¶rÃ¼necek.',
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
                    'SÄ±radaki diÄer programlar',
                    subtitle:
                        'KoÃ§unun yazdÄ±ÄÄ±, henÃ¼z yapmadÄ±ÄÄ±n programlar.',
                  ),
                  for (final workout in pending) ...[
                    _WorkoutCard(
                      workout: workout,
                      previousSets: progress.previousSetsFor(workout),
                      // ReddedilmiÅ bir program doldurulamaz; dÃ¼Äme yalnÄ±zca
                      // gerÃ§ekten bekleyen programlarda Ã§Ä±kar.
                      onComplete: workout.isWaiting
                          ? () => _completePlan(workout, progress)
                          : null,
                    ),
                    const SizedBox(height: AppSizes.gapSmall),
                  ],
                ],
                const SizedBox(height: AppSizes.gapLarge),
                SectionTitle(
                  'Son antrenmanlarÄ±n',
                  subtitle: recent.isEmpty
                      ? null
                      : 'Her seans kendi programÄ±nÄ±n bir Ã¶ncekiyle '
                            'karÅÄ±laÅtÄ±rÄ±ldÄ±.',
                ),
                if (recent.isEmpty)
                  const EmptyState(
                    icon: Icons.history,
                    title: 'HenÃ¼z antrenman kaydÄ± yok',
                    description:
                        'KoÃ§unun programÄ±nÄ± tamamladÄ±ÄÄ±nda son antrenmanlarÄ±n '
                        'burada gÃ¶rÃ¼necek.',
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

/// EkranÄ±n yÃ¼klenirken gÃ¶rÃ¼nen hÃ¢li.
///
/// BÃ¶lÃ¼m baÅlÄ±klarÄ± gerÃ§ek metinleriyle duruyor: yÃ¼klenirken de ekranÄ±n neyi
/// gÃ¶stereceÄi okunuyor, veri gelince yalnÄ±zca kartlarÄ±n iÃ§i deÄiÅiyor.
class _WorkoutSkeleton extends StatelessWidget {
  const _WorkoutSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: const [
        SectionTitle('YapÄ±lacak antrenman'),
        _WorkoutCardSkeleton(setRows: 3),
        SizedBox(height: AppSizes.gapLarge),
        SectionTitle('Son antrenmanlarÄ±n'),
        _WorkoutCardSkeleton(setRows: 2),
      ],
    );
  }
}

/// Antrenman kartÄ±nÄ±n iskeleti: baÅlÄ±k satÄ±rÄ±, ayraÃ§ ve set satÄ±rlarÄ±.
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
                  // Align olmadan Expanded geniÅliÄi dayatÄ±r ve bloklar
                  // satÄ±rÄ±n tamamÄ±nÄ± kaplar; metin izlenimi kaybolur.
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

/// BaÅlÄ±k: koÃ§ programa ad verdiyse o, vermediyse hareket adlarÄ±.
String _workoutTitle(Workout workout) => workout.displayName;

/// KartÄ±n baÅlÄ±k ikonu ve rozeti kaydÄ±n kendi durumundan Ã¼retilir.
///
/// Sabit etiket yazÄ±lmÄ±yor: aksi hÃ¢lde bekleyen bir program da "TamamlandÄ±"
/// gÃ¶rÃ¼nÃ¼r ve ekran veriyle Ã§eliÅir.
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

/// Kart alt baÅlÄ±ÄÄ±: "BugÃ¼n Â· 3 hareket Â· 9 set".
String _workoutSubtitle(Workout workout, int movementCount) {
  return '${AppDate.relative(workout.date)} Â· $movementCount hareket '
      'Â· ${workout.totalSets} set';
}

/// Seti olmayan antrenmanÄ±n uyarÄ±sÄ±.
///
/// Backend setsiz bir programÄ± da baÅarÄ±yla dÃ¶ndÃ¼rebiliyor; kart sessizce
/// "0 set" gÃ¶stermek yerine durumu aÃ§Ä±kÃ§a yazÄ±yor.
const _emptySetsMessage =
    'Bu programda hiÃ§ set kayÄ±tlÄ± deÄil. KoÃ§unun program yazarken setleri '
    'kaydedememiÅ olmasÄ± muhtemel, koÃ§una haber ver.';

/// Ä°kon + aÃ§Ä±klama satÄ±rÄ±ndan oluÅan bilgi kartÄ±.
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
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Kart baÅlÄ±ÄÄ±: renkli ikon kutusu + baÅlÄ±k/alt baÅlÄ±k + saÄ aksiyon.
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

/// KoÃ§un not kutusu â plan ve seans kartlarÄ±nda aynÄ± gÃ¶rÃ¼nÃ¼r.
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

/// Bir antrenman kaydÄ±: tarihi, notu ve Ã¶nceki seansa gÃ¶re farklarÄ±yla setleri.
///
/// Hem Ã¶Ärencinin yaptÄ±ÄÄ± seanslar hem de koÃ§un bekleyen programlarÄ± bu kartla
/// Ã§iziliyor. Bekleyen her programda tamamlama dÃ¼Ämesi bulunur â ayrÄ± bir
/// "plan kartÄ±" tutulduÄunda dÃ¼Äme yalnÄ±zca en Ã¼stteki programa konuyordu ve
/// alttaki programlar doldurulamÄ±yordu.
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.previousSets,
    this.onComplete,
  });

  final Workout workout;
  final Map<String, WorkoutSet> previousSets;

  /// YalnÄ±zca doldurulabilir (bekleyen) programlarda verilir; yapÄ±lmÄ±Å
  /// seanslarda null.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final byMovement = groupByMovement(workout.sets);
    final note = workout.notes.trim();
    final style = _statusStyle(workout.status);

    // Seti olmayan program tamamlanamaz: form boÅ aÃ§Ä±lÄ±r ve kaydedilirse
    // geriye setsiz bir seans kaydÄ± kalÄ±r.
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
              label: workout.byStudent ? 'Notun' : 'KoÃ§ notu',
              note: note,
            ),
          // YalnÄ±zca yapÄ±lmÄ±Å seanslarda: koÃ§un yazdÄ±ÄÄ± plan henÃ¼z bir sonuÃ§
          // deÄil, onu geÃ§en seansla kÄ±yaslamak yanÄ±ltÄ±cÄ± olur.
          if (workout.byStudent)
            SessionProgressBanner(
              comparison: SessionComparison.of(workout, previousSets),
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
                showDiff: workout.byStudent,
              ),
          if (onComplete != null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            ElevatedButton(
              onPressed: hasSets ? onComplete : null,
              child: const Text('AntrenmanÄ± tamamla'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bir hareketin adÄ± ve altÄ±ndaki set satÄ±rlarÄ±.
class _MovementSets extends StatelessWidget {
  const _MovementSets({
    required this.name,
    required this.sets,
    required this.previousSets,
    required this.showDiff,
  });

  final String name;
  final List<WorkoutSet> sets;
  final Map<String, WorkoutSet> previousSets;
  final bool showDiff;

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
              showDiff: showDiff,
            ),
        ],
      ),
    );
  }
}

/// "Set 1 Â· 10 tekrar Ã 40 kg Â· Ã¶nceki 10 Ã 37,5 kg Â· +2,5 kg" satÄ±rÄ±.
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.previous,
    required this.showDiff,
  });

  final WorkoutSet set;
  final WorkoutSet? previous;

  /// Fark rozeti yalnızca yapılmış seanslarda çizilir. Koçun yazdığı plan bir
  /// sonuç değil hedef; onu geçen seansla kıyaslayıp kırmızı/yeşil basmak
  /// öğrenci daha fazlasını yaptığında "düştü" izlenimi veriyordu.
  final bool showDiff;

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
                    'Ã¶nceki ${setLineShort(before)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          if (showDiff) ...[
            const SizedBox(width: AppSizes.gapSmall),
            SetDiffBadges(weight: set.weight, reps: set.reps, previous: before),
          ],
        ],
      ),
    );
  }
}
