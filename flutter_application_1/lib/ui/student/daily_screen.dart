import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_fmt.dart';
import '../../core/num_fmt.dart';
import '../../core/theme.dart';
import '../../models/tracking.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'add_meal_sheet.dart';
import 'add_sleep_sheet.dart';

/// Günlük ekranı: seçili günün öğünleri, besin toplamları ve uykusu.
///
/// Backend öğünü sunucu saatiyle damgaladığı için ekleme yalnızca "bugün"
/// görünümünde açık; geçmiş günler salt okunur gezilir.
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  DateTime _day = DateTime.now();
  List<Meal>? _meals;

  /// Tüm uyku kayıtları (yeniden eskiye). Seçili günün kaydı ve kıyas için
  /// bir öncekisi buradan bulunur.
  List<Sleep>? _sleepRecords;
  bool _loading = true;
  String? _error;

  bool get _isToday => AppDate.isSameDay(_day, DateTime.now());

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
    final results = await Future.wait([
      services.meals.getMeals(start: _day, end: _day),
      services.sleep.getSleepRecords(),
    ]);
    final mealResult = results[0];
    final sleepResult = results[1];

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!mealResult.ok) {
        _error = mealResult.errorMessage;
        return;
      }
      _meals = (mealResult.data as List?)?.cast<Meal>() ?? const <Meal>[];
      // Uyku listesi alınamazsa gün görünümünü düşürme; bölüm boş görünür.
      _sleepRecords = sleepResult.ok
          ? (sleepResult.data as List?)?.cast<Sleep>() ?? const <Sleep>[]
          : const <Sleep>[];
    });
  }

  void _changeDay(int delta) {
    final next = _day.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _day = next);
    _load();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = picked);
    _load();
  }

  Future<void> _addMeal() async {
    final saved = await showAddMealSheet(context);
    if (!saved || !mounted) return;
    showAppSnack(context, 'Öğün eklendi');
    await _load();
  }

  Future<void> _deleteMeal(Meal meal) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Öğünü sil',
      message: '"${meal.mealName}" kaydı silinecek.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final result = await context.read<AppServices>().meals.deleteMeal(meal.id);
    if (!mounted) return;
    if (!result.ok) {
      showAppSnack(context, result.errorMessage, isError: true);
      return;
    }
    showAppSnack(context, 'Öğün silindi');
    await _load();
  }

  Future<void> _addSleep() async {
    final saved = await showAddSleepSheet(context);
    if (!saved || !mounted) return;
    showAppSnack(context, 'Uyku kaydedildi');
    await _load();
  }

  /// Seçili günde uyanılan kayıt ve kıyas için ondan önceki kayıt.
  ({Sleep? current, Sleep? previous}) get _sleepOfDay {
    final records = _sleepRecords ?? const <Sleep>[];
    for (var i = 0; i < records.length; i++) {
      final wake = records[i].wakeTime;
      if (wake != null && AppDate.isSameDay(wake, _day)) {
        return (
          current: records[i],
          previous: i + 1 < records.length ? records[i + 1] : null,
        );
      }
    }
    return (current: null, previous: null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: AsyncContent<List<Meal>>(
        loading: _loading,
        error: _error,
        data: _meals,
        onRetry: _load,
        builder: (meals) {
          final sleep = _sleepOfDay;
          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              children: [
                _DayPicker(
                  day: _day,
                  onPrevious: () => _changeDay(-1),
                  onNext: _isToday ? null : () => _changeDay(1),
                  onPick: _pickDay,
                ),
                const SizedBox(height: AppSizes.gap),
                _DailyTotals(meals: meals),
                const SizedBox(height: AppSizes.gapLarge),
                SectionTitle(
                  'Öğünler',
                  subtitle: _isToday
                      ? 'Bugün yediklerini kaydet.'
                      : AppDate.relative(_day),
                  action: _isToday
                      ? TextButton.icon(
                          onPressed: _addMeal,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ekle'),
                        )
                      : null,
                ),
                if (meals.isEmpty)
                  EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: _isToday
                        ? 'Bugün henüz öğün yok'
                        : 'Bu güne öğün girilmemiş',
                    description: _isToday
                        ? 'Yediklerini ekle ki koçun beslenmeni takip '
                              'edebilsin.'
                        : null,
                  )
                else
                  for (final meal in meals) ...[
                    _MealTile(
                      meal: meal,
                      onDelete: _isToday ? () => _deleteMeal(meal) : null,
                    ),
                    const SizedBox(height: AppSizes.gapSmall),
                  ],
                const SizedBox(height: AppSizes.gap),
                SectionTitle(
                  'Uyku',
                  subtitle: 'Gece uykun ve öncekiyle farkı.',
                  action: _isToday && sleep.current == null
                      ? TextButton.icon(
                          onPressed: _addSleep,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ekle'),
                        )
                      : null,
                ),
                _SleepCard(
                  current: sleep.current,
                  previous: sleep.previous,
                  isToday: _isToday,
                ),
                const SizedBox(height: AppSizes.gapLarge),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Bootstrap pagination görünümünde gün gezgini: ‹ 14 Ağustos 2026 ›
class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.day,
    required this.onPrevious,
    required this.onPick,
    this.onNext,
  });

  final DateTime day;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Önceki gün',
            onPressed: onPrevious,
          ),
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppDate.relative(day),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Sonraki gün',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// Günün kalori/protein/yağ toplamı — görseldeki makro halkalarının
/// Bootstrap karşılığı olarak üç metrik kutusu.
class _DailyTotals extends StatelessWidget {
  const _DailyTotals({required this.meals});

  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {
    double kcal = 0, protein = 0, oil = 0;
    for (final meal in meals) {
      kcal += meal.kcal;
      protein += meal.protein;
      oil += meal.oil;
    }

    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: 'Kalori',
            value: formatNumber(kcal),
            unit: 'kcal',
          ),
        ),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: MetricTile(
            label: 'Protein',
            value: formatNumber(protein),
            unit: 'g',
          ),
        ),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: MetricTile(
            label: 'Yağ',
            value: formatNumber(oil),
            unit: 'g',
          ),
        ),
      ],
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal, this.onDelete});

  final Meal meal;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      '${formatNumber(meal.kcal)} kcal',
      'P ${formatNumber(meal.protein)} g',
      'Y ${formatNumber(meal.oil)} g',
      if (meal.date != null) AppDate.time(meal.date),
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatar,
            height: AppSizes.avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            ),
            child: const Icon(
              Icons.restaurant_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  meal.mealName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(details, style: Theme.of(context).textTheme.bodySmall),
                if (meal.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meal.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.textSecondary,
              tooltip: 'Sil',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// Gecenin uykusu ve önceki kayıtla süre farkı.
class _SleepCard extends StatelessWidget {
  const _SleepCard({
    required this.current,
    required this.previous,
    required this.isToday,
  });

  final Sleep? current;
  final Sleep? previous;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final record = current;
    if (record == null) {
      return AppCard(
        child: Row(
          children: [
            const Icon(
              Icons.bedtime_outlined,
              size: 20,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: AppSizes.gapSmall),
            Expanded(
              child: Text(
                isToday
                    ? 'Bu gece için uyku kaydı yok. Yattığın ve uyandığın '
                          'saati ekle.'
                    : 'Bu güne uyku kaydı girilmemiş.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final duration = record.duration;
    final prevDuration = previous?.duration;

    // Önceki kayıtla dakika farkı; iki kayıt da tamsa gösterilir.
    Widget? comparison;
    if (duration != null && prevDuration != null) {
      final diff = duration.inMinutes - prevDuration.inMinutes;
      final up = diff >= 0;
      final label = diff == 0
          ? 'Önceki uykuyla aynı süre'
          : 'Önceki uykudan ${AppDate.duration(DateTime(2000), DateTime(2000).add(Duration(minutes: diff.abs())))} '
                '${up ? 'fazla' : 'az'}';
      comparison = Row(
        children: [
          Icon(
            diff == 0
                ? Icons.drag_handle
                : up
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            size: 16,
            color: up ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: up ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.avatar,
                height: AppSizes.avatar,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
                child: const Icon(
                  Icons.bedtime_outlined,
                  size: 20,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppDate.duration(record.bedTime, record.wakeTime),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${AppDate.time(record.bedTime)} - '
                      '${AppDate.time(record.wakeTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comparison != null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSizes.gapSmall),
            comparison,
          ],
        ],
      ),
    );
  }
}
