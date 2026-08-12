import '../core/json_utils.dart';

/// `entities.WorkoutStatus` değerleri.
class WorkoutStatus {
  const WorkoutStatus._();

  static const String waiting = 'waiting';
  static const String done = 'done';
  static const String rejected = 'rejected';

  static String label(String value) {
    switch (value) {
      case waiting:
        return 'Bekliyor';
      case done:
        return 'Tamamlandı';
      case rejected:
        return 'Reddedildi';
      default:
        return value.isEmpty ? '-' : value;
    }
  }
}

/// Tek bir set kaydı.
///
/// DİKKAT: Bu model iki farklı biçimde taşınıyor.
/// * Cevaplarda `models.SetM` kullanıldığı için alanlar **snake_case** gelir.
/// * İsteklerde `entities.Set` bind edildiği ve o struct'ın json tag'i olmadığı
///   için alanlar **PascalCase** gönderilmek zorunda ([toApiJson]).
class WorkoutSet {
  const WorkoutSet({
    this.id = 0,
    this.workoutId = 0,
    required this.movementName,
    required this.setNumber,
    required this.reps,
    required this.weight,
    this.date,
  });

  final int id;
  final int workoutId;
  final String movementName;
  final int setNumber;
  final int reps;
  final double weight;
  final DateTime? date;

  WorkoutSet copyWith({
    String? movementName,
    int? setNumber,
    int? reps,
    double? weight,
  }) {
    return WorkoutSet(
      id: id,
      workoutId: workoutId,
      movementName: movementName ?? this.movementName,
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      date: date,
    );
  }

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: asInt(pick(json, ['id', 'ID'])),
      workoutId: asInt(pick(json, ['workout_id', 'WorkoutID'])),
      movementName: asString(pick(json, ['movement_name', 'MovementName'])),
      setNumber: asInt(pick(json, ['set_number', 'SetNumber'])),
      reps: asInt(pick(json, ['reps', 'Reps'])),
      weight: asDouble(pick(json, ['weight', 'Weight'])),
      date: DateTime.tryParse(
        asString(pick(json, ['date', 'Date'])),
      )?.toLocal(),
    );
  }

  /// `entities.Set` alan adlarıyla gönderilir.
  /// `ID`, `WorkoutID` ve `Date` bilinçli olarak gönderilmez — handler bunları
  /// kendisi dolduruyor, `Date` string olarak gönderilirse bind hatası olur.
  Map<String, dynamic> toApiJson() {
    return {
      'MovementName': movementName,
      'SetNumber': setNumber,
      'Reps': reps,
      'Weight': weight,
    };
  }
}

/// `models.WorkoutM` karşılığı.
class Workout {
  const Workout({
    required this.id,
    required this.coachId,
    required this.studentId,
    required this.notes,
    required this.status,
    required this.generator,
    this.sourcePlanId,
    this.date,
    this.sets = const [],
  });

  final int id;
  final int coachId;
  final int studentId;
  final String notes;
  final String status;

  /// true ise kaydı öğrenci girmiş, false ise koç.
  final bool generator;
  final int? sourcePlanId;
  final DateTime? date;
  final List<WorkoutSet> sets;

  bool get isWaiting => status == WorkoutStatus.waiting;
  bool get isDone => status == WorkoutStatus.done;
  bool get byStudent => generator;

  int get totalSets => sets.length;

  double get totalVolume =>
      sets.fold(0, (sum, set) => sum + (set.reps * set.weight));

  /// Plandaki farklı hareket adları (sırayı korur).
  List<String> get movements {
    final seen = <String>[];
    for (final set in sets) {
      final name = set.movementName.trim();
      if (name.isNotEmpty && !seen.contains(name)) seen.add(name);
    }
    return seen;
  }

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: asInt(pick(json, ['id', 'ID'])),
      coachId: asInt(pick(json, ['coach_id', 'CoachID'])),
      studentId: asInt(pick(json, ['student_id', 'StudentID'])),
      notes: asString(pick(json, ['notes', 'Notes', 'note'])),
      status: asString(pick(json, ['status', 'Status'])),
      generator: asBool(pick(json, ['generator', 'Generator'])),
      sourcePlanId: asIntOrNull(pick(json, ['source_plan_id', 'SourcePlanID'])),
      date: DateTime.tryParse(
        asString(pick(json, ['date', 'Date'])),
      )?.toLocal(),
      sets: asMapList(pick(json, ['sets', 'Sets']))
          .map(WorkoutSet.fromJson)
          .toList(),
    );
  }
}
