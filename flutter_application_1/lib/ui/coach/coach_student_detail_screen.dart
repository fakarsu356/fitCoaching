import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_fmt.dart';
import '../../core/num_fmt.dart';
import '../../core/theme.dart';
import '../../models/relation.dart';
import '../../models/tracking.dart';
import '../../models/workout.dart';
import '../../services/services.dart';
import '../student/workout_progress.dart';
import '../widgets/common.dart';
import 'workout_editor_sheet.dart';

/// Koçun tek bir öğrenciyi izlediği ekran; üç sekme.
///
/// Profil sekmesi öğrencinin genel bilgilerini, belgelerini ve fotoğraflarını
/// taşıyor. Genel bilgiler veri sekmelerinde tekrar edilmiyor: koç günlük
/// kayıtlara bakarken ekranın üstünü sabit bir kart yemesin.
///
/// Her şey salt okunur — koçun buradan yapabildiği tek yazma işlemi yeni
/// program göndermek; öğün/uyku kayıtlarını yalnızca öğrenci girebiliyor.
class CoachStudentDetailScreen extends StatefulWidget {
  const CoachStudentDetailScreen({super.key, required this.student});

  final Student student;

  @override
  State<CoachStudentDetailScreen> createState() =>
      _CoachStudentDetailScreenState();
}

class _CoachStudentDetailScreenState extends State<CoachStudentDetailScreen>
    with SingleTickerProviderStateMixin {
  /// Antrenman sekmesi tek güne değil bir pencereye bakıyor. İleriye de
  /// bakılıyor çünkü koç ileri bir güne program yazabiliyor.
  static const Duration _workoutWindow = Duration(days: 30);

  late final TabController _tabs;

  DateTime _day = DateTime.now();

  List<Workout>? _workouts;
  List<Meal>? _meals;

  /// Tüm uyku kayıtları (yeniden eskiye). Seçili günün kaydı ve kıyas için bir
  /// öncekisi buradan bulunur — öğrenci tarafındaki günlük ekranıyla aynı kural.
  List<Sleep>? _sleepRecords;

  List<DocumentItem>? _documents;
  bool _documentsLoading = true;

  /// İndirilen görseller sekme değiştikçe yeniden çekilmesin diye belge
  /// kimliğine göre saklanıyor; indirilemeyen için null yazılıyor ki tekrar
  /// denenmesin.
  final Map<int, Uint8List?> _imageCache = {};

  bool _loading = true;
  String? _error;

  /// Art arda gün değiştirildiğinde önceki isteğin geç gelen cevabı ekrana
  /// yazılmasın diye her yüklemeye sıra numarası veriliyor.
  int _requestId = 0;

  int get _studentId => widget.student.userId;

  bool get _isToday => AppDate.isSameDay(_day, DateTime.now());

  @override
  void initState() {
    super.initState();
    // Program yaz butonu yalnızca Antrenman sekmesinde görünsün diye sekme
    // değişimi dinleniyor.
    _tabs = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
    _load();
    _loadDocuments();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    final services = context.read<AppServices>();
    final now = DateTime.now();
    // Üç uç de bağımsız; birlikte başlatılıp birlikte bekleniyor.
    final workoutFuture = services.workouts.getWorkoutsByDate(
      start: now.subtract(_workoutWindow),
      end: now.add(_workoutWindow),
      studentId: _studentId,
    );
    final mealFuture = services.meals.getMeals(
      start: _day,
      end: _day,
      studentId: _studentId,
    );
    final sleepFuture = services.sleep.getSleepRecords(studentId: _studentId);

    final workoutResult = await workoutFuture;
    final mealResult = await mealFuture;
    final sleepResult = await sleepFuture;

    if (!mounted || requestId != _requestId) return;
    setState(() {
      _loading = false;
      _workouts = workoutResult.data ?? const <Workout>[];
      _meals = mealResult.data ?? const <Meal>[];
      _sleepRecords = sleepResult.data ?? const <Sleep>[];

      // Üçü birden başarısızsa ekranı hata durumuna al; biri boş dönerse
      // diğer bölümler yine gösterilir.
      if (!workoutResult.ok && !mealResult.ok && !sleepResult.ok) {
        _error = workoutResult.errorMessage;
      }
    });
  }

  /// Belgeler güne bağlı olmadığı için gün değiştikçe değil, yalnızca ekran
  /// açılırken ve profil sekmesi aşağı çekildiğinde yükleniyor.
  Future<void> _loadDocuments() async {
    setState(() => _documentsLoading = true);
    final result = await context.read<AppServices>().documents.getList(
      studentId: _studentId,
    );
    if (!mounted) return;
    setState(() {
      _documentsLoading = false;
      _documents = result.data ?? const <DocumentItem>[];
    });
  }

  Future<Uint8List?> _imageBytes(int fileId) async {
    if (_imageCache.containsKey(fileId)) return _imageCache[fileId];
    final result = await context.read<AppServices>().documents.download(fileId);
    final data = result.data;
    final bytes = result.ok && data != null && data.isNotEmpty
        ? Uint8List.fromList(data)
        : null;
    _imageCache[fileId] = bytes;
    return bytes;
  }

  void _shiftDay(int days) {
    setState(() => _day = _day.add(Duration(days: days)));
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
    await _load();
  }

  Future<void> _writePlan() async {
    final saved = await showWorkoutEditorSheet(
      context,
      students: [widget.student],
      initialStudent: widget.student,
    );
    if (saved && mounted) {
      showAppSnack(context, 'Program gönderildi');
      await _load();
    }
  }

  Future<void> _openImage(DocumentItem document) async {
    final bytes = await _imageBytes(document.id);
    if (!mounted) return;
    if (bytes == null) {
      showAppSnack(context, 'Resim açılamadı');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
              child: Text(
                document.docName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Flexible(child: InteractiveViewer(child: Image.memory(bytes))),
          ],
        ),
      ),
    );
  }

  /// Seçili güne ait uyku kaydı ve ondan bir önceki kayıt.
  ///
  /// Liste yeniden eskiye sıralı olduğu için "önceki", bulunan kaydın hemen
  /// sonrasındaki eleman oluyor.
  (Sleep?, Sleep?) _sleepOfDay() {
    final records = _sleepRecords;
    if (records == null) return (null, null);
    for (var i = 0; i < records.length; i++) {
      final bedTime = records[i].bedTime;
      if (bedTime != null && AppDate.isSameDay(bedTime, _day)) {
        final previous = i + 1 < records.length ? records[i + 1] : null;
        return (records[i], previous);
      }
    }
    return (null, null);
  }

  EdgeInsets get _tabPadding => const EdgeInsets.fromLTRB(
    AppSizes.pagePadding,
    AppSizes.pagePadding,
    AppSizes.pagePadding,
    AppSizes.pagePadding + 72,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student.displayName),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Profil'),
            Tab(text: 'Beslenme & Uyku'),
            Tab(text: 'Antrenman'),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 2
          ? FloatingActionButton.extended(
              onPressed: _writePlan,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Program yaz'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [_profileTab(), _dailyTab(), _workoutTab()],
      ),
    );
  }

  Widget _profileTab() {
    final documents = _documents ?? const <DocumentItem>[];
    final images = documents.where((document) => document.isImage).toList();
    final files = documents.where((document) => !document.isImage).toList();

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      color: AppColors.primary,
      child: ListView(
        padding: _tabPadding,
        children: [
          _StudentSummaryCard(student: widget.student),
          const SizedBox(height: AppSizes.gapLarge),
          const SectionTitle(
            'Belgeler',
            subtitle: 'Öğrencinin yüklediği tahlil ve raporlar.',
          ),
          if (_documentsLoading)
            const _SectionSkeleton()
          else if (files.isEmpty)
            const _EmptyCard(
              icon: Icons.description_outlined,
              message: 'Yüklenmiş belge yok.',
            )
          else
            for (final document in files) ...[
              _StudentDocumentTile(document: document),
              const SizedBox(height: AppSizes.gapSmall),
            ],
          const SizedBox(height: AppSizes.gapLarge),
          const SectionTitle(
            'Resimler',
            subtitle: 'Gelişim ve öğün fotoğrafları — kontrol için.',
          ),
          if (_documentsLoading)
            const _SectionSkeleton()
          else if (images.isEmpty)
            const _EmptyCard(
              icon: Icons.image_outlined,
              message: 'Yüklenmiş resim yok.',
            )
          else
            _ImageGrid(images: images, loader: _imageBytes, onOpen: _openImage),
        ],
      ),
    );
  }

  Widget _dailyTab() {
    final (sleep, previousSleep) = _sleepOfDay();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: _tabPadding,
        children: [
          DayPicker(
            day: _day,
            onPrevious: () => _shiftDay(-1),
            onPick: _pickDay,
            // Geleceğe gidilemiyor: o günlerin kaydı zaten olamaz.
            onNext: _isToday ? null : () => _shiftDay(1),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSizes.gap),
            ErrorState(message: _error!, onRetry: _load),
          ] else ...[
            const SizedBox(height: AppSizes.gapLarge),
            const SectionTitle('Beslenme'),
            _MealSection(meals: _meals, loading: _loading),
            const SizedBox(height: AppSizes.gapLarge),
            const SectionTitle('Uyku'),
            _SleepSection(
              sleep: sleep,
              previous: previousSleep,
              loading: _loading,
            ),
          ],
        ],
      ),
    );
  }

  Widget _workoutTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: _tabPadding,
        children: [
          const SectionTitle(
            'Programlar',
            subtitle: 'Son bir ay ve ileri tarihli programlar.',
          ),
          if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else
            _WorkoutSection(workouts: _workouts, loading: _loading),
        ],
      ),
    );
  }
}
/// Öğrencinin sabit vücut bilgileri.
class _StudentSummaryCard extends StatelessWidget {
  const _StudentSummaryCard({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final bmi = student.bmi;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            student.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Yaş',
                  value: student.age > 0 ? student.age.toString() : '-',
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: MetricTile(
                  label: 'Kilo',
                  value: student.bodyWeight > 0
                      ? formatNumber(student.bodyWeight)
                      : '-',
                  unit: 'kg',
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: MetricTile(
                  label: 'Boy',
                  value: student.bodyHeight > 0
                      ? formatNumber(student.bodyHeight)
                      : '-',
                  unit: 'cm',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Yağ oranı',
                  value: student.fatPercentage > 0
                      ? formatNumber(student.fatPercentage)
                      : '-',
                  unit: '%',
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: MetricTile(
                  label: 'VKİ',
                  value: bmi == null ? '-' : formatNumber(bmi),
                ),
              ),
              // Üçüncü sütun boş bırakıldı: kutular üstteki satırla aynı
              // genişlikte kalsın, iki satır kaymasın.
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutSection extends StatelessWidget {
  const _WorkoutSection({required this.workouts, required this.loading});

  final List<Workout>? workouts;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _SectionSkeleton();

    final list = workouts ?? const <Workout>[];
    if (list.isEmpty) {
      return const _EmptyCard(
        icon: Icons.fitness_center_outlined,
        message: 'Bu güne ait antrenman kaydı yok.',
      );
    }

    return Column(
      children: [
        for (final workout in list) ...[
          _WorkoutCard(workout: workout),
          const SizedBox(height: AppSizes.gapSmall),
        ],
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final byMovement = groupByMovement(workout.sets);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // Öğrencinin kaydı ile koçun planı aynı listede geliyor;
                  // hangisi olduğu ayırt edilmezse kartlar birbirine karışır.
                  workout.byStudent ? 'Öğrencinin kaydı' : 'Koç planı',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (workout.byStudent || workout.isDone)
                StatusPill.success(WorkoutStatus.label(WorkoutStatus.done))
              else
                StatusPill.warning(WorkoutStatus.label(workout.status)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${AppDate.time(workout.date)} · ${byMovement.length} hareket · '
            '${workout.totalSets} set',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (workout.notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              workout.notes.trim(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          for (final entry in byMovement.entries) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Text(entry.key, style: Theme.of(context).textTheme.titleSmall),
            for (final set in entry.value)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: AppSizes.setLabelWidth,
                      child: Text(
                        'Set ${set.setNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      setLineShort(set),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({required this.meals, required this.loading});

  final List<Meal>? meals;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _SectionSkeleton();

    final list = meals ?? const <Meal>[];
    if (list.isEmpty) {
      return const _EmptyCard(
        icon: Icons.restaurant_outlined,
        message: 'Bu güne ait öğün kaydı yok.',
      );
    }

    // Toplamlar burada hesaplanıyor: /meal/dailyMeals ucu geçmiş tarih şartı
    // koyduğu için bugün seçiliyken kullanılamıyor, aynı sayıyı iki farklı
    // yoldan almak da tutarsızlık riski.
    double kcal = 0, protein = 0, karb = 0, oil = 0, lif = 0;
    for (final meal in list) {
      kcal += meal.kcal;
      protein += meal.protein;
      karb += meal.karb;
      oil += meal.oil;
      lif += meal.lif;
    }

    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
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
                      label: 'Karbonhidrat',
                      value: formatNumber(karb),
                      unit: 'g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.gapSmall),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Yağ',
                      value: formatNumber(oil),
                      unit: 'g',
                    ),
                  ),
                  const SizedBox(width: AppSizes.gapSmall),
                  Expanded(
                    child: MetricTile(
                      label: 'Lif',
                      value: formatNumber(lif),
                      unit: 'g',
                    ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        for (final meal in list) ...[
          AppCard(
            padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        meal.mealName.trim().isEmpty
                            ? 'Öğün'
                            : meal.mealName.trim(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${AppDate.time(meal.date)} · '
                        '${formatNumber(meal.kcal)} kcal · '
                        'P ${formatNumber(meal.protein)}g',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.gapSmall),
        ],
      ],
    );
  }
}

class _SleepSection extends StatelessWidget {
  const _SleepSection({
    required this.sleep,
    required this.previous,
    required this.loading,
  });

  final Sleep? sleep;
  final Sleep? previous;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _SectionSkeleton();

    final record = sleep;
    if (record == null) {
      return const _EmptyCard(
        icon: Icons.bedtime_outlined,
        message: 'Bu güne ait uyku kaydı yok.',
      );
    }

    final duration = record.duration;
    final previousDuration = previous?.duration;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bedtime_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: Text(
                  '${AppDate.time(record.bedTime)} - '
                  '${AppDate.time(record.wakeTime)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (duration != null)
                StatusPill.info(
                  AppDate.duration(
                    DateTime(2000),
                    DateTime(2000).add(duration),
                  ),
                ),
            ],
          ),
          if (duration != null && previousDuration != null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            _SleepComparison(
              minutes: duration.inMinutes - previousDuration.inMinutes,
            ),
          ],
        ],
      ),
    );
  }
}

/// Bir önceki uyku kaydına göre fark — öğrenci tarafındaki kıyasla aynı kural.
class _SleepComparison extends StatelessWidget {
  const _SleepComparison({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    if (minutes == 0) {
      return Text(
        'Önceki uykuyla aynı süre',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final up = minutes > 0;
    final color = up ? AppColors.success : AppColors.danger;
    final gap = AppDate.duration(
      DateTime(2000),
      DateTime(2000).add(Duration(minutes: minutes.abs())),
    );

    return Row(
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          'Önceki uykudan $gap ${up ? 'fazla' : 'az'}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

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

/// Bölümlerin ortak iskeleti: gün değişirken kartın yeri korunsun diye
/// yükseklik sabit.
class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 140, height: 14),
          SizedBox(height: AppSizes.gapSmall),
          Skeleton(width: double.infinity, height: 12),
          SizedBox(height: 6),
          Skeleton(width: 180, height: 12),
        ],
      ),
    );
  }
}

/// Öğrencinin yüklediği resim dışı belge (tahlil, rapor).
///
/// Liste ucu dosya içeriğini göndermediği için burada önizleme yok; koç
/// belgenin varlığını, türünü ve tarihini görüyor.
class _StudentDocumentTile extends StatelessWidget {
  const _StudentDocumentTile({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatar,
            height: AppSizes.avatar,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            ),
            child: Icon(
              document.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.description_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSizes.cardPaddingCompact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document.docName.trim().isEmpty
                      ? 'Belge #${document.id}'
                      : document.docName.trim(),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${document.typeLabel} · ${AppDate.short(document.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gelişim/öğün fotoğrafları. Üçlü ızgara, dokununca tam boy açılıyor.
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.images,
    required this.loader,
    required this.onOpen,
  });

  final List<DocumentItem> images;

  /// Bayt indirmeyi ekranın state'ine bırakıyoruz ki önbellek sekmeler
  /// arasında korunsun.
  final Future<Uint8List?> Function(int fileId) loader;
  final void Function(DocumentItem document) onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSizes.gapSmall,
        mainAxisSpacing: AppSizes.gapSmall,
      ),
      itemBuilder: (context, index) {
        final document = images[index];
        return _ImageTile(
          document: document,
          loader: loader,
          onOpen: () => onOpen(document),
        );
      },
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.document,
    required this.loader,
    required this.onOpen,
  });

  final DocumentItem document;
  final Future<Uint8List?> Function(int fileId) loader;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        child: ColoredBox(
          color: AppColors.surfaceMuted,
          child: FutureBuilder<Uint8List?>(
            future: loader(document.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Skeleton(
                  width: double.infinity,
                  height: double.infinity,
                );
              }
              final bytes = snapshot.data;
              if (bytes == null) {
                // İndirilemeyen görsel ızgarada boşluk bırakmasın diye yerine
                // bir simge konuyor.
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                );
              }
              return Image.memory(bytes, fit: BoxFit.cover);
            },
          ),
        ),
      ),
    );
  }
}
