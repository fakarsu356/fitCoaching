import '../core/api_client.dart';
import '../core/api_result.dart';
import '../core/json_utils.dart';
import '../models/coach.dart';
import '../models/relation.dart';

/// Profil uçları — `handlers.Profile`.
class ProfileService {
  ProfileService(this._client);

  final ApiClient _client;

  static const String coachProfilePath = '/profile/getCoach';

  /// Handler: `handlers.Profile.ResetPassword`.
  static const String resetPasswordPath = '/profile/resetPassword';

  /// Handler: `handlers.Profile.StudentProfile`.
  static const String studentProfilePath = '/profile/getStudent';

  /// Handler: `handlers.Profile.UpdateStudent`.
  static const String updateStudentPath = '/profile/updateStudent';

  /// POST /profile/getCoach — koçun herkese açık profili: puan ortalaması,
  /// değerlendirme sayısı ve sertifikaları.
  Future<ApiResult<Coach>> getCoachProfile(int coachId) async {
    final result = await _client.post(
      coachProfilePath,
      body: {'coach_id': coachId},
    );
    if (!result.ok) return ApiResult.failure<Coach>(result.message);

    final map = asMap(result.data);
    if (map == null) {
      return ApiResult.failure<Coach>('Profil bilgisi boş geldi');
    }
    return ApiResult.success<Coach>(Coach.fromJson(map));
  }

  /// POST /profile/resetPassword — giriş yapmış kullanıcının şifresini
  /// değiştirir.
  ///
  /// [oldPassword] backend bugün doğrulanmıyor (handler yalnızca user_id ve
  /// password okuyor) ama gövdede gönderiliyor: sunucu tarafında bcrypt
  /// kontrolü eklendiğinde front değişmeden çalışsın diye.
  Future<ApiResult<void>> resetPassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final result = await _client.post(
      resetPasswordPath,
      body: {
        'user_id': userId,
        'old_password': oldPassword,
        'password': newPassword,
      },
    );
    if (!result.ok) return ApiResult.failure<void>(result.message);
    return ApiResult.success<void>(null);
  }

  /// POST /profile/getStudent — öğrencinin kendi profili.
  ///
  /// Kimlik token'dan okunduğu için gövde boş gidiyor.
  Future<ApiResult<Student>> getStudentProfile() async {
    final result = await _client.post(studentProfilePath);
    if (!result.ok) return ApiResult.failure<Student>(result.message);

    final map = asMap(result.data);
    if (map == null) {
      return ApiResult.failure<Student>('Profil bilgisi boş geldi');
    }
    return ApiResult.success<Student>(Student.fromJson(map));
  }

  /// POST /profile/updateStudent — kilo ve yağ oranını günceller.
  ///
  /// Yaş, boy ve cinsiyet kayıt sırasında belirleniyor, burada
  /// değiştirilmiyor. Cevap güncel kaydı döndürdüğü için ekran ayrıca
  /// yeniden istek atmıyor.
  Future<ApiResult<Student>> updateStudentProfile({
    required double bodyWeight,
    required double fatPercentage,
  }) async {
    final result = await _client.post(
      updateStudentPath,
      body: {'body_weight': bodyWeight, 'fat_percentage': fatPercentage},
    );
    if (!result.ok) return ApiResult.failure<Student>(result.message);

    final map = asMap(result.data);
    // Uç güncel kaydı döndürmezse hata değil: kayıt yine de yazıldı.
    if (map == null) return ApiResult.success<Student>(null);
    return ApiResult.success<Student>(Student.fromJson(map));
  }
}
