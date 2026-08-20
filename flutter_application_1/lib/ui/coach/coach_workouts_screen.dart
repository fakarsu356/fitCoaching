import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_fmt.dart';
import '../../core/theme.dart';
import '../../models/relation.dart';
import '../../models/workout.dart';
import '../../services/services.dart';
import '../student/workout_progress.dart';
import '../widgets/common.dart';
import 'workout_editor_sheet.dart';

/// Koçun yazdığı antrenman programları.
///
/// Liste öğrenciye göre gruplanıyor: koç genelde "şu öğrenciye ne yazmıştım"
/// diye bakıyor, tarih sırası tek başına bu soruyu cevaplamıyor.
class CoachWorkoutsScreen extends StatefulWidget {
  const CoachWorkoutsScreen({super.key, required this.relationsVersion});

  /// Öğrenci listesi değişince (istek onaylanınca) plan yazma seçenekleri de
  /// tazelensin diye dinleniyor.
  final ValueListenable<int> relationsVersion;

  @override
  State<CoachWorkoutsScreen> createState() => _CoachWorkoutsScreenState();
}

class _CoachWorkoutsScreenState extends State<CoachWorkoutsScreen> {
  List<Workout>? _workouts;
  List<Student> _students = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.relationsVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.relationsVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final services = context.read<AppServices>();
    // Öğrenci listesi plan kartlarındaki ismi ve "yeni program" formundaki
    // seçim kutusunu besliyor. İki istek birlikte başlatılıp sonra bekleniyor:
    // sırayla await edilseydi ekran iki gidiş-dönüş boyu boş kalırdı.
    final workoutFuture = services.workouts.getCoachWorkouts();
    final studentFuture = services.relations.getMyStudents();
    final workoutResult = await workoutFuture;
    final studentResult = await studentFuture;

    if (!mounted) return;
    setState(() {
      _loading = false;
      // Öğrenci listesi hata verirse plan listesi yine gösterilir; isimlerin
      // yerine "Öğrenci #id" yazılması ekranı komple kapatmaktan iyi.
      _students = studentResult.data ?? const <Student>[];
      if (workoutResult.ok) {
        _workouts = workoutResult.data ?? const <Workout>[];
      } else {
        _error = workoutResult.errorMessage;
      }
    });
  }

  String _studentLabel(int studentId) {
    for (final student in _students) {
      if (student.userId == studentId) return student.displayName;
    }
    return 'Öğrenci #$studentId';
  }

  Future<void> _create({Student? student}) async {
    if (_students.isEmpty) {
      showAppSnack(
        context,
        'Aktif öğrencin yok; önce bir bağlanma isteğini onayla',
        isError: true,
      );
      return;
    }
    final saved = await showWorkoutEditorSheet(
      context,
      students: _students,
      initialStudent: student,
    );
    if (saved && mounted) {
      showAppSnack(context, 'Program gönderildi');
      await _load();
    }
  }

  Future<void> _edit(Workout plan) async {
    final saved = await showWorkoutEditorSheet(
      context,
      students: _students,
      plan: plan,
    );
    if (saved && mounted) {
      showAppSnack(context, 'Program güncellendi');
      await _load();
    }
  }

  /// Geçmiş bir planı aynı ya da başka bir öğrenciye yeniden gönderir.
  Future<void> _copy(Workout plan) async {
    if (_students.isEmpty) {
      showAppSnack(context, 'Kopyalanacak öğrenci yok', isError: true);
      return;
    }

    final targetId = await _pickStudent(plan.studentId);
    if (targetId == null || !mounted) return;

    final result = await context.read<AppServices>().workouts.copyWorkout(
      workoutId: plan.id,
      studentId: targetId,
    );
    if (!mounted) return;

    if (!result.ok) {
      showAppSnack(context, result.errorMessage, isError: true);
      return;
    }
    showAppSnack(context, '${_studentLabel(targetId)} için kopyalandı');
    await _load();
  }

  Future<int?> _pickStudent(int initialId) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            const SectionTitle(
              'Kime kopyalansın?',
              subtitle: 'Plan seçilen öğrenciye yeni bir program olarak gider.',
            ),
            for (final student in _students)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  student.userId == initialId
                      ? Icons.person
                      : Icons.person_outline,
                  color: student.userId == initialId
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                title: Text(student.displayName),
                onTap: () => Navigator.of(sheetContext).pop(student.userId),
              ),
          ],
        ),
      ),
    );
  }

  /// Planları öğrenciye göre gruplar; her grup kendi içinde tarihe göre yeniden
  /// sıralanır (yeni plan üstte).
  Map<int, List<Workout>> _groupByStudent(List<Workout> workouts) {
    final grouped = <int, List<Workout>>{};
    for (final workout in workouts) {
      grouped.putIfAbsent(workout.studentId, () => []).add(workout);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final aDate = a.date ?? DateTime(1970);
        final bDate = b.date ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _create(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni program'),
      ),
      body: AsyncContent<List<Workout>>(
        loading: _loading,
        error: _error,
        data: _workouts,
        onRetry: _load,
        builder: (workouts) {
          if (workouts.isEmpty) {
            return EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Henüz program yazmadın',
              description: _students.isEmpty
                  ? 'Önce "İstekler" sekmesinden bir öğrenciyi onayla, sonra '
                        'buradan program yazabilirsin.'
                  : 'Aşağıdaki "Yeni program" düğmesiyle öğrencilerine '
                        'antrenman planı gönder.',
              action: _students.isEmpty
                  ? null
                  : ElevatedButton(
                      onPressed: () => _create(),
                      child: const Text('Yeni program'),
                    ),
            );
          }

          final grouped = _groupByStudent(workouts);
          final studentIds = grouped.keys.toList()
            ..sort((a, b) => _studentLabel(a).compareTo(_studentLabel(b)));

          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.pagePadding,
                AppSizes.pagePadding,
                // FAB listenin son kartını kapatmasın.
                AppSizes.pagePadding + 72,
              ),
              children: [
                for (final studentId in studentIds) ...[
                  SectionTitle(
                    _studentLabel(studentId),
                    subtitle: '${grouped[studentId]!.length} program',
                    action: TextButton(
                      onPressed: () => _create(student: _studentOf(studentId)),
                      child: const Text('Program yaz'),
                    ),
                  ),
                  for (final plan in grouped[studentId]!) ...[
                    _PlanCard(
                      plan: plan,
                      onEdit: plan.isWaiting && !plan.byStudent
                          ? () => _edit(plan)
                          : null,
                      onCopy: () => _copy(plan),
                    ),
                    const SizedBox(height: AppSizes.gapSmall),
                  ],
                  const SizedBox(height: AppSizes.gapSmall),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Student? _studentOf(int studentId) {
    for (final student in _students) {
      if (student.userId == studentId) return student;
    }
    return null;
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onCopy, this.onEdit});

  final Workout plan;

  /// Öğrenci antrenmanı kaydettikten sonra plan değiştirilemez; o durumda null.
  final VoidCallback? onEdit;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final byMovement = groupByMovement(plan.sets);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppDate.readable(plan.date),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _statusPill(plan),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${byMovement.length} hareket · ${plan.totalSets} set',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (plan.notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              plan.notes.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (byMovement.isNotEmpty) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Wrap(
              spacing: AppSizes.gapSmall,
              runSpacing: 4,
              children: [
                for (final entry in byMovement.entries)
                  StatusPill('${entry.key} ×${entry.value.length}'),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.gap),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Kopyala'),
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzenle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(Workout plan) {
    // Öğrencinin kaydettiği seans "tamamlandı" demek; koçun bekleyen planı
    // henüz cevaplanmamış olan.
    if (plan.byStudent || plan.isDone) {
      return StatusPill.success(WorkoutStatus.label(WorkoutStatus.done));
    }
    if (plan.isWaiting) {
      return StatusPill.warning(WorkoutStatus.label(plan.status));
    }
    return StatusPill(WorkoutStatus.label(plan.status));
  }
}
