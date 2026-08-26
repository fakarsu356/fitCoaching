import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/num_fmt.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/relation.dart';
import '../../models/workout.dart';
import '../../services/services.dart';
import '../widgets/common.dart';

/// Koçun plan yazma / düzenleme formu. Kaydedilirse `true` döner.
///
/// [plan] verilirse güncelleme modunda açılır: öğrenci sabittir (backend planın
/// sahibini değiştirmeye izin vermiyor), sadece not ve setler düzenlenir.
Future<bool> showWorkoutEditorSheet(
  BuildContext context, {
  required List<Student> students,
  Workout? plan,
  Student? initialStudent,
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
    builder: (_) => _WorkoutEditorSheet(
      students: students,
      plan: plan,
      initialStudent: initialStudent,
    ),
  );
  return saved ?? false;
}

/// Formdaki tek bir set satırı. Denetleyiciler satırla birlikte taşınır ki
/// aradan bir satır silindiğinde kalan satırların metinleri kaymasın.
class _SetRow {
  _SetRow({String movement = '', String reps = '', String weight = ''})
    : movement = TextEditingController(text: movement),
      reps = TextEditingController(text: reps),
      weight = TextEditingController(text: weight);

  final TextEditingController movement;
  final TextEditingController reps;
  final TextEditingController weight;

  void dispose() {
    movement.dispose();
    reps.dispose();
    weight.dispose();
  }
}

class _WorkoutEditorSheet extends StatefulWidget {
  const _WorkoutEditorSheet({
    required this.students,
    this.plan,
    this.initialStudent,
  });

  final List<Student> students;
  final Workout? plan;
  final Student? initialStudent;

  @override
  State<_WorkoutEditorSheet> createState() => _WorkoutEditorSheetState();
}

class _WorkoutEditorSheetState extends State<_WorkoutEditorSheet> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  final List<_SetRow> _rows = [];
  int? _studentId;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.plan != null;

  @override
  void initState() {
    super.initState();

    final plan = widget.plan;
    if (plan != null) {
      _studentId = plan.studentId;
      _name.text = plan.name;
      _note.text = plan.notes;
      for (final set in plan.sets) {
        _rows.add(
          _SetRow(
            movement: set.movementName,
            reps: set.reps.toString(),
            weight: formatNumber(set.weight),
          ),
        );
      }
    } else {
      _studentId = widget.initialStudent?.userId ?? _singleStudentId();
    }

    // Boş formda tek bir satır açık gelsin: koç "set ekle"ye basmadan yazmaya
    // başlayabilsin.
    if (_rows.isEmpty) _rows.add(_SetRow());
  }

  /// Koçun tek öğrencisi varsa seçim beklemenin anlamı yok.
  int? _singleStudentId() =>
      widget.students.length == 1 ? widget.students.first.userId : null;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _addRow() {
    // Yeni satır bir öncekinin hareket adını devralır: aynı hareketin 2. ve 3.
    // setini girmek plan yazarken en sık yapılan iş.
    final last = _rows.isEmpty ? '' : _rows.last.movement.text.trim();
    setState(() => _rows.add(_SetRow(movement: last)));
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index).dispose());
  }

  /// Formu `WorkoutSet` listesine çevirir; eksik/hatalı alan varsa null döner
  /// ve [_error] doldurulur.
  ///
  /// Set numaraları burada hareket bazında yeniden üretiliyor: koçtan sıra
  /// numarası istemek gereksiz, aynı hareketin kaçıncı satırı olduğu zaten
  /// listedeki yerinden belli.
  List<WorkoutSet>? _collectSets() {
    final sets = <WorkoutSet>[];
    final counters = <String, int>{};

    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final movement = row.movement.text.trim();
      final reps = int.tryParse(row.reps.text.trim());
      // Ağırlık boş bırakılabilir: vücut ağırlığıyla yapılan hareketler
      // 0 kg olarak kaydedilir.
      final weightText = row.weight.text.trim().replaceAll(',', '.');
      final weight = weightText.isEmpty ? 0.0 : double.tryParse(weightText);

      if (movement.isEmpty) {
        _error = '${i + 1}. satırda hareket adı boş';
        return null;
      }
      if (reps == null || reps <= 0 || reps > Validators.maxReps) {
        _error =
            '${i + 1}. satırda tekrar 1 ile ${Validators.maxReps} arasında '
            'tam sayı olmalı';
        return null;
      }
      if (weight == null || weight < 0 || weight > Validators.maxSetWeight) {
        _error =
            '${i + 1}. satırda ağırlık 0 ile '
            '${formatNumber(Validators.maxSetWeight)} kg arasında olmalı '
            '(vücut ağırlığı hareketiyse boş bırak)';
        return null;
      }

      final next = (counters[movement] ?? 0) + 1;
      counters[movement] = next;
      sets.add(
        WorkoutSet(
          movementName: movement,
          setNumber: next,
          reps: reps,
          weight: weight,
        ),
      );
    }
    return sets;
  }

  Future<void> _submit() async {
    final studentId = _studentId;
    if (studentId == null) {
      setState(() => _error = 'Önce öğrenci seç');
      return;
    }
    if (_rows.isEmpty) {
      setState(() => _error = 'En az bir set ekle');
      return;
    }

    setState(() => _error = null);
    final sets = _collectSets();
    if (sets == null) {
      setState(() {});
      return;
    }

    setState(() => _busy = true);

    final workouts = context.read<AppServices>().workouts;
    final name = _name.text.trim();
    final note = _note.text.trim();
    final result = _isEdit
        ? await workouts.updateWorkout(
            workoutId: widget.plan!.id,
            studentId: studentId,
            name: name,
            note: note,
            sets: sets,
          )
        : await workouts.addWorkout(
            studentId: studentId,
            name: name,
            note: note,
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
            SectionTitle(
              _isEdit ? 'Programı düzenle' : 'Yeni program',
              subtitle: _isEdit
                  ? 'Öğrenci antrenmanı kaydetmeden önce plan değiştirilebilir.'
                  : 'Hareket, tekrar ve ağırlıkları gir; set numaraları '
                        'sıraya göre kendiliğinden verilir.',
            ),
            const SizedBox(height: AppSizes.gapSmall),
            _buildStudentField(),
            const SizedBox(height: AppSizes.gap),
            LabeledField(
              label: 'Program adı',
              child: TextField(
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                maxLength: Validators.maxWorkoutNameLength,
                decoration: const InputDecoration(
                  hintText: 'örn. Push Day, Bacak günü',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: AppSizes.gap),
            Text('Setler', style: Theme.of(context).textTheme.titleSmall),
            for (var i = 0; i < _rows.length; i++) _buildSetRow(i),
            const SizedBox(height: AppSizes.gapSmall),
            OutlinedButton.icon(
              onPressed: _busy ? null : _addRow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Set ekle'),
            ),
            const SizedBox(height: AppSizes.gap),
            LabeledField(
              label: 'Not (isteğe bağlı)',
              child: TextField(
                controller: _note,
                enabled: !_busy,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Isınma, tempo, dinlenme süresi...',
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
                  : Text(_isEdit ? 'Değişiklikleri kaydet' : 'Programı gönder'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentField() {
    if (_isEdit) {
      return InfoRow('Öğrenci', _studentLabel(_studentId));
    }
    if (widget.students.isEmpty) {
      return Text(
        'Aktif öğrencin yok; program yazabilmek için önce bir isteği onayla.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return LabeledField(
      label: 'Öğrenci',
      child: DropdownButtonFormField<int>(
        initialValue: _studentId,
        isExpanded: true,
        decoration: const InputDecoration(hintText: 'Öğrenci seç'),
        items: [
          for (final student in widget.students)
            DropdownMenuItem<int>(
              value: student.userId,
              child: Text(student.displayName, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _busy ? null : (value) => setState(() => _studentId = value),
      ),
    );
  }

  String _studentLabel(int? id) {
    if (id == null) return '-';
    for (final student in widget.students) {
      if (student.userId == id) return student.displayName;
    }
    return 'Öğrenci #$id';
  }

  Widget _buildSetRow(int index) {
    final row = _rows[index];

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.gapSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: TextField(
              controller: row.movement,
              enabled: !_busy,
              textCapitalization: TextCapitalization.sentences,
              maxLength: Validators.maxMovementNameLength,
              decoration: const InputDecoration(
                labelText: 'Hareket',
                hintText: 'örn. Bench Press',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.reps,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: repsInputFormatters,
              decoration: const InputDecoration(
                labelText: 'Tekrar',
                hintText: 'kaç kez',
              ),
            ),
          ),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.weight,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: weightInputFormatters,
              decoration: const InputDecoration(
                labelText: 'Ağırlık',
                hintText: 'kaç kg',
                suffixText: 'kg',
              ),
            ),
          ),
          // Tek satır kalınca silme kapalı: setsiz plan gönderilemiyor.
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Satırı sil',
            color: AppColors.textMuted,
            onPressed: (_busy || _rows.length == 1)
                ? null
                : () => _removeRow(index),
          ),
        ],
      ),
    );
  }
}
