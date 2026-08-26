import 'package:flutter_application_1/models/workout.dart';
import 'package:flutter_application_1/ui/student/workout_progress.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSet s(String name, int n, int reps, double w) =>
    WorkoutSet(movementName: name, setNumber: n, reps: reps, weight: w);

Workout wk({
  required int id,
  required int studentId,
  required bool generator,
  int? source,
  required String status,
  required String date,
  List<WorkoutSet> sets = const [],
}) => Workout(
  id: id,
  coachId: 30,
  studentId: studentId,
  notes: '',
  status: status,
  generator: generator,
  sourcePlanId: source,
  date: DateTime.parse(date),
  sets: sets,
);

const mv = 'dumbell press houlder';

void main() {
  // Veritabanındaki gerçek satırlar (workouts 20/52/54, sets tablosu).
  final plan20 = wk(
    id: 20, studentId: 26, generator: false, status: 'waiting',
    date: '2026-08-20 06:53:04',
    sets: [s(mv, 1, 12, 15), s(mv, 2, 10, 17.5)],
  );
  final copy52 = wk(
    id: 52, studentId: 26, generator: false, source: 20, status: 'done',
    date: '2026-08-23 18:40:13',
    sets: [s(mv, 1, 12, 15), s(mv, 2, 10, 17.5)],
  );
  final session54 = wk(
    id: 54, studentId: 26, generator: true, source: 20, status: 'done',
    date: '2026-08-24 16:59:12',
    sets: [s(mv, 1, 14, 15), s(mv, 2, 10, 17.5)],
  );

  test('DB durumu: programın tek seansı var, kıyas kurulamaz', () {
    final progress = WorkoutProgress([session54]);
    expect(progress.previousSetsFor(session54), isEmpty);
  });

  test('koçun done kopyası (generator=0) önceki seans sayılmaz', () {
    // Ekran zaten byStudent filtresi uyguluyor; filtre kalkarsa kıyas
    // koçun hedef değerleriyle kurulur, o yüzden burada test ediliyor.
    final sessions = [session54, copy52, plan20];
    final wrong = WorkoutProgress(sessions).previousSetsFor(session54);
    expect(wrong[setKey(mv, 1)]?.reps, 12, reason: 'filtresiz kıyas plana düşer');

    final filtered = [
      for (final w in sessions) if (w.byStudent) w,
    ];
    expect(WorkoutProgress(filtered).previousSetsFor(session54), isEmpty);
  });

  test('ikinci seans: set bazında artış ve düşüş çıkar', () {
    final session56 = wk(
      id: 56, studentId: 26, generator: true, source: 20, status: 'done',
      date: '2026-08-25 17:00:00',
      sets: [s(mv, 1, 14, 17.5), s(mv, 2, 10, 15)],
    );
    final progress = WorkoutProgress([session56, session54]); // yeniden eskiye
    final prev = progress.previousSetsFor(session56);

    expect(prev[setKey(mv, 1)]!.weight, 15);
    expect(prev[setKey(mv, 2)]!.weight, 17.5);

    expect(session56.sets[0].weight - prev[setKey(mv, 1)]!.weight, 2.5); // +2.5 kg
    expect(session56.sets[1].weight - prev[setKey(mv, 2)]!.weight, -2.5); // -2.5 kg

    final c = SessionComparison.of(session56, prev);
    expect(c.improved, 1);
    expect(c.dropped, 1);
    expect(c.direction, 0);
    expect(c.previousVolume, 14 * 15 + 10 * 17.5);
    expect(c.currentVolume, 14 * 17.5 + 10 * 15);
  });

  test('bekleyen plan aynı programın son seansıyla kıyaslanır', () {
    final newPlan = wk(
      id: 57, studentId: 26, generator: false, source: 20, status: 'waiting',
      date: '2026-08-26 09:00:00',
      sets: [s(mv, 1, 12, 20), s(mv, 2, 10, 20)],
    );
    final prev = WorkoutProgress([session54]).previousSetsFor(newPlan);
    expect(prev[setKey(mv, 1)]!.weight, 15);
    expect(prev[setKey(mv, 2)]!.reps, 10);
  });

  test('başka programın seansı önceki seans sayılmaz', () {
    final legPress = wk(
      id: 58, studentId: 26, generator: true, source: 51, status: 'done',
      date: '2026-08-25 10:00:00',
      sets: [s('leg press', 1, 12, 123)],
    );
    final progress = WorkoutProgress([legPress, session54]);
    expect(progress.previousSetsFor(legPress)[setKey('leg press', 1)], isNull);
  });

  test('sıralama ters gelirse kıyas yönü ters çıkar (regresyon koruması)', () {
    final session56 = wk(
      id: 56, studentId: 26, generator: true, source: 20, status: 'done',
      date: '2026-08-25 17:00:00',
      sets: [s(mv, 1, 14, 20)],
    );
    // Backend ORDER BY vermiyor; servis sıralamayı kaldırırsa liste eskiden
    // yeniye gelir ve "önceki seans" yanlış seçilir.
    final prev = WorkoutProgress([session54, session56]).previousSetsFor(session54);
    expect(prev[setKey(mv, 1)]!.weight, 20,
        reason: 'eskiden yeniye sıralı listede kıyas ileriye bakar');
  });
}
