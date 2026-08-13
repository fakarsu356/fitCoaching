import '../core/api_client.dart';
import '../core/api_result.dart';
import '../core/json_utils.dart';
import '../models/coach.dart';

/// Profil uçları — `handlers.Profile`.
class ProfileService {
  ProfileService(this._client);

  final ApiClient _client;

  static const String coachProfilePath = '/profile/getCoach';

  /// POST /profile/getCoach — koçun herkese açık profili: puan ortalaması,
  /// değerlendirme sayısı ve sertifikaları.
  Future<ApiResult<Coach>> getCoachProfile(int coachId) async {
    final result = await _client.post(
      coachProfilePath,
      body: {'coach_id': coachId},
    );
    if (!result.ok) return ApiResult.failure<Coach>(result.message);

    final map = asMap(result.data);
    if (map == null) return ApiResult.failure<Coach>('Profil bilgisi boş geldi');
    return ApiResult.success<Coach>(Coach.fromJson(map));
  }
}
