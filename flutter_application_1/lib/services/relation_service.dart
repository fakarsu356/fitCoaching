import '../core/api_client.dart';
import '../core/api_result.dart';
import '../core/json_utils.dart';
import '../models/coach.dart';
import '../models/relation.dart';

class RelationService {
  RelationService(this._client);

  final ApiClient _client;

  /// POST /coaches — kapasitesi dolmamış koçlar (sadece öğrenci).
  Future<ApiResult<List<Coach>>> getAvailableCoaches() async {
    final result = await _client.post('/coaches');
    if (!result.ok) return ApiResult.failure<List<Coach>>(result.message);
    return ApiResult.success<List<Coach>>(
      asMapList(result.data).map(Coach.fromJson).toList(),
    );
  }

  /// POST /relations/request — koça bağlanma isteği.
  Future<ApiResult<void>> sendRequest(int coachId) async {
    final result = await _client.post(
      '/relations/request',
      body: {'coach_id': coachId},
      dataKey: 'Relation',
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /relations/myrequest — öğrencinin cevap bekleyen isteği.
  ///
  /// Bekleyen istek yoksa uç hata döndürüyor ("kayıt bulunamadı"), bu bir arıza
  /// değil, o yüzden null'a çevriliyor. Uç şu an sadece durum metnini
  /// döndürdüğü için ("waiting") tam ilişki nesnesi geldiğinde de çalışsın diye
  /// iki biçim de okunuyor.
  Future<ApiResult<Relation?>> getMyRequest() async {
    final result = await _client.post('/relations/myrequest');
    if (!result.ok) return ApiResult.success<Relation?>(null);

    final data = result.data;
    if (data is String) {
      return ApiResult.success<Relation?>(
        data.isEmpty
            ? null
            : Relation(id: 0, studentId: 0, coachId: 0, status: data),
      );
    }
    final map = asMap(data);
    return ApiResult.success<Relation?>(
      map == null ? null : Relation.fromJson(map),
    );
  }

  /// POST /relations/myCoach — öğrencinin aktif koçu.
  ///
  /// Aktif ilişki yoksa backend gorm'un "record not found" hatasını döndürüyor;
  /// bu bir arıza değil "henüz koçu yok" demek, o yüzden null'a çevriliyor.
  Future<ApiResult<Coach?>> getMyCoach() async {
    final result = await _client.post('/relations/myCoach');
    if (!result.ok) {
      final message = (result.message ?? '').toLowerCase();
      if (message.contains('record not found')) {
        return ApiResult.success<Coach?>(null);
      }
      return ApiResult.failure<Coach?>(result.message);
    }
    final map = asMap(result.data);
    return ApiResult.success<Coach?>(map == null ? null : Coach.fromJson(map));
  }

  /// POST /relations/leave — koçtan ayrıl.
  Future<ApiResult<void>> leaveCoach(int coachId) async {
    final result = await _client.post(
      '/relations/leave',
      body: {'coach_id': coachId},
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /relations/pastCoaches — en son ayrılınan koç.
  ///
  /// Uç, geçmiş koç bulunmadığında da hata döndürdüğü için başarısız sonuç
  /// "geçmiş koç yok" sayılır; ekran bu bilgiyi sadece puanlama kartını
  /// göstermek için kullanıyor.
  Future<ApiResult<Coach?>> getPastCoach() async {
    final result = await _client.post('/relations/pastCoaches');
    if (!result.ok) return ApiResult.success<Coach?>(null);
    final map = asMap(result.data);
    return ApiResult.success<Coach?>(map == null ? null : Coach.fromJson(map));
  }

  /// POST /relations/pending — koça gelen istekler.
  ///
  /// Backend bu uçta koçun tüm ilişkilerini döndürüyor (status filtresi yok),
  /// bu yüzden bekleyenler burada ayıklanıyor.
  Future<ApiResult<List<Relation>>> getPendingRequests() async {
    final result = await _client.post(
      '/relations/pending',
      dataKey: 'PendingRequests',
    );
    if (!result.ok) return ApiResult.failure<List<Relation>>(result.message);

    final all = asMapList(result.data).map(Relation.fromJson).toList();
    final pending = all
        .where((relation) => relation.isWaiting && !relation.isExpired)
        .toList();
    return ApiResult.success<List<Relation>>(pending);
  }

  /// POST /relations/accept
  Future<ApiResult<void>> acceptRequest(int studentId) async {
    final result = await _client.post(
      '/relations/accept',
      body: {'student_id': studentId},
      dataKey: 'relation',
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /relations/reject
  Future<ApiResult<void>> rejectRequest(int studentId) async {
    final result = await _client.post(
      '/relations/reject',
      body: {'student_id': studentId},
      dataKey: 'relation',
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /relations/myStudents — koçun aktif öğrencileri.
  Future<ApiResult<List<Student>>> getMyStudents() async {
    final result = await _client.post(
      '/relations/myStudents',
      dataKey: 'Students',
    );
    if (!result.ok) return ApiResult.failure<List<Student>>(result.message);
    final students = asMapList(result.data)
        .map(Student.fromJson)
        .where((student) => student.userId != 0)
        .toList();
    return ApiResult.success<List<Student>>(students);
  }
}
