import '../core/api_client.dart';
import '../core/api_result.dart';
import '../core/date_fmt.dart';
import '../core/json_utils.dart';
import '../models/workout.dart';

class WorkoutService {
  WorkoutService(this._client);

  final ApiClient _client;

  /// Set listesi `entities.Set` alan adlarÄ±yla gÃ¶nderilir.
  List<Map<String, dynamic>> _setsPayload(List<WorkoutSet> sets) {
    return sets.map((set) => set.toApiJson()).toList();
  }

  /// POST /workout/workoutAdd â koÃ§ Ã¶Ärenciye plan girer.
  ///
  /// `date` gÃ¶nderilmiyor: backend'de `time.Time` olarak bind edildiÄi iÃ§in
  /// serbest formatlÄ± bir tarih tÃ¼m isteÄi bozar, handler zaten `time.Now()`
  /// kullanÄ±yor.
  Future<ApiResult<void>> addWorkout({
    required int studentId,
    required String name,
    required String note,
    required List<WorkoutSet> sets,
  }) async {
    final result = await _client.post(
      '/workout/workoutAdd',
      body: {
        'student_id': studentId,
        'name': name,
        'note': note,
        'sets': _setsPayload(sets),
      },
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /workout/getworkout â Ã¶Ärencinin sÄ±radaki (en eski bekleyen) planÄ±.
  Future<ApiResult<Workout?>> getTodayPlan() async {
    final result = await _client.post('/workout/getworkout');
    if (!result.ok) return ApiResult.failure<Workout?>(result.message);
    final map = asMap(result.data);
    return ApiResult.success<Workout?>(
      map == null ? null : Workout.fromJson(map),
    );
  }

  /// POST /workout/saveWorkout â Ã¶Ärenci yaptÄ±ÄÄ± antrenmanÄ± kaydeder.
  Future<ApiResult<void>> saveStudentWorkout({
    required int studentId,
    required int sourcePlanId,
    required String note,
    required List<WorkoutSet> sets,
  }) async {
    final result = await _client.post(
      '/workout/saveWorkout',
      body: {
        'student_id': studentId,
        'source_plan_id': sourcePlanId,
        'note': note,
        'generator': true,
        'sets': _setsPayload(sets),
      },
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /workout/workoutcopy â geÃ§miÅ bir planÄ± Ã¶Ärenciye kopyalar.
  Future<ApiResult<void>> copyWorkout({
    required int workoutId,
    required int studentId,
  }) async {
    final result = await _client.post(
      '/workout/workoutcopy',
      body: {'workout_id': workoutId, 'student_id': studentId},
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /workout/workoutupdate â Ã¶Ärenci cevaplamadan planÄ± gÃ¼nceller.
  Future<ApiResult<void>> updateWorkout({
    required int workoutId,
    required int studentId,
    required String name,
    required String note,
    required List<WorkoutSet> sets,
  }) async {
    final result = await _client.post(
      '/workout/workoutupdate',
      body: {
        'workout_id': workoutId,
        'student_id': studentId,
        'name': name,
        'note': note,
        'sets': _setsPayload(sets),
      },
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /workout/workoutlist â koÃ§un girdiÄi planlar.
  Future<ApiResult<List<Workout>>> getCoachWorkouts() async {
    final result = await _client.post('/workout/workoutlist');
    if (!result.ok) return ApiResult.failure<List<Workout>>(result.message);
    return ApiResult.success<List<Workout>>(
      asMapList(result.data).map(Workout.fromJson).toList(),
    );
  }

  /// POST /workout/workoutsbytime â tarih aralÄ±ÄÄ±ndaki antrenmanlar.
  /// KoÃ§ rolÃ¼nde [studentId] zorunlu.
  Future<ApiResult<List<Workout>>> getWorkoutsByDate({
    required DateTime start,
    required DateTime end,
    int? studentId,
  }) async {
    final result = await _client.post(
      '/workout/workoutsbytime',
      body: {
        'start_date': AppDate.dayStart(start),
        'end_date': AppDate.dayEnd(end),
        'student_id': ?studentId,
      },
    );
    if (!result.ok) return ApiResult.failure<List<Workout>>(result.message);
    final workouts = asMapList(result.data).map(Workout.fromJson).toList()
      ..sort((a, b) {
        final aDate = a.date ?? DateTime(1970);
        final bDate = b.date ?? DateTime(1970);
        // Aynı ana düşen kayıtlarda sıra rastgele kalıyordu ve "önceki
        // seans" yanlış seçiliyordu; büyük id her zaman daha yeni kayıt.
        final byDate = bDate.compareTo(aDate);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    return ApiResult.success<List<Workout>>(workouts);
  }

  /// POST /workout/workout â tek antrenman detayÄ±.
  /// Backend Ã¶Ärenci rolÃ¼nde de `student_id` bekliyor.
  Future<ApiResult<Workout?>> getWorkoutDetail({
    required int workoutId,
    required int studentId,
  }) async {
    final result = await _client.post(
      '/workout/workout',
      body: {'workout_id': workoutId, 'student_id': studentId},
    );
    if (!result.ok) return ApiResult.failure<Workout?>(result.message);
    final map = asMap(result.data);
    return ApiResult.success<Workout?>(
      map == null ? null : Workout.fromJson(map),
    );
  }
}
