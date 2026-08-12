import '../core/api_client.dart';
import '../core/api_result.dart';
import '../core/date_fmt.dart';
import '../core/json_utils.dart';
import '../models/workout.dart';

class WorkoutService {
  WorkoutService(this._client);

  final ApiClient _client;

  /// Set listesi `entities.Set` alan adlarıyla gönderilir.
  List<Map<String, dynamic>> _setsPayload(List<WorkoutSet> sets) {
    return sets.map((set) => set.toApiJson()).toList();
  }

  /// POST /workout/workoutAdd — koç öğrenciye plan girer.
  ///
  /// `date` gönderilmiyor: backend'de `time.Time` olarak bind edildiği için
  /// serbest formatlı bir tarih tüm isteği bozar, handler zaten `time.Now()`
  /// kullanıyor.
  Future<ApiResult<void>> addWorkout({
    required int studentId,
    required String note,
    required List<WorkoutSet> sets,
  }) async {
    final result = await _client.post(
      '/workout/workoutAdd',
      body: {
        'student_id': studentId,
        'note': note,
        'sets': _setsPayload(sets),
      },
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /workout/getworkout — öğrencinin sıradaki (en eski bekleyen) planı.
  Future<ApiResult<Workout?>> getTodayPlan() async {
    final result = await _client.post('/workout/getworkout');
    if (!result.ok) return ApiResult.failure<Workout?>(result.message);
    final map = asMap(result.data);
    return ApiResult.success<Workout?>(
      map == null ? null : Workout.fromJson(map),
    );
  }

  /// POST /workout/saveWorkout — öğrenci yaptığı antrenmanı kaydeder.
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

  /// POST /workout/workoutcopy — geçmiş bir planı öğrenciye kopyalar.
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

  /// POST /workout/workoutupdate — öğrenci cevaplamadan planı günceller.
  Future<ApiResult<void>> updateWorkout({
    required int workoutId,
    required int studentId,
    required String note,
    required List<WorkoutSet> sets,
  }) async {
    final result = await _client.post(
      '/workout/workoutupdate',
      body: {
        'workout_id': workoutId,
        'student_id': studentId,
        'note': note,
        'sets': _setsPayload(sets),
      },
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /workout/workoutlist — koçun girdiği planlar.
  Future<ApiResult<List<Workout>>> getCoachWorkouts() async {
    final result = await _client.post('/workout/workoutlist');
    if (!result.ok) return ApiResult.failure<List<Workout>>(result.message);
    return ApiResult.success<List<Workout>>(
      asMapList(result.data).map(Workout.fromJson).toList(),
    );
  }

  /// POST /workout/workoutsbytime — tarih aralığındaki antrenmanlar.
  /// Koç rolünde [studentId] zorunlu.
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
        return bDate.compareTo(aDate);
      });
    return ApiResult.success<List<Workout>>(workouts);
  }

  /// POST /workout/workout — tek antrenman detayı.
  /// Backend öğrenci rolünde de `student_id` bekliyor.
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
