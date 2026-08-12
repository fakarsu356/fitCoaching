import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_result.dart';
import '../core/json_utils.dart';

/// Giriş sonucunda backend'in döndürdüğü token seti.
class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
  });

  final String accessToken;
  final String refreshToken;
  final String role;
}

/// Koç kaydında gönderilen dosya.
class UploadFile {
  const UploadFile({required this.name, required this.path});

  final String name;
  final String path;

  Future<MultipartFile> toMultipart() =>
      MultipartFile.fromFile(path, filename: name);
}

class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  /// POST /register/student — JSON gövde.
  Future<ApiResult<void>> registerStudent({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
    required int age,
    double? bodyFatPercentage,
    required double bodyWeight,
    required double bodyHeight,
    required String gender,
  }) async {
    final result = await _client.post(
      '/register/student',
      authenticated: false,
      body: {
        'name': name,
        'password': password,
        'validatePassword': passwordConfirm,
        'email': email,
        'age': age,
        // Yağ oranı opsiyonel; boş bırakılırsa backend'in "belirtilmedi" olarak
        // yorumladığı 0 gönderilir.
        'bodyFatPercentage': bodyFatPercentage ?? 0,
        'bodyWeight': bodyWeight,
        'bodyHeight': bodyHeight,
        'gender': gender,
      },
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /register/coach — multipart.
  ///
  /// Backend `CV` alanını tek dosya olarak zorunlu tutuyor, sertifikaları ise
  /// `certificates` alanından çoklu okuyor.
  Future<ApiResult<void>> registerCoach({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required int maxStudents,
    required String speciality,
    required String gender,
    required UploadFile cv,
    List<UploadFile> certificates = const [],
  }) async {
    final certificateFiles = <MultipartFile>[];
    for (final file in certificates) {
      certificateFiles.add(await file.toMultipart());
    }

    final result = await _client.postMultipart(
      '/register/coach',
      authenticated: false,
      fields: {
        'username': username,
        'password': password,
        'password_confirm': passwordConfirm,
        'email': email,
        'max_students': maxStudents.toString(),
        'speciality': speciality,
        'gender': gender,
      },
      files: certificateFiles,
      filesFieldName: 'certificates',
      namedFiles: {'CV': await cv.toMultipart()},
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /register/login
  Future<ApiResult<LoginResult>> login({
    required String email,
    required String password,
  }) async {
    final result = await _client.post(
      '/register/login',
      authenticated: false,
      body: {'email': email, 'password': password},
    );

    if (!result.ok) {
      return ApiResult.failure<LoginResult>(result.message);
    }

    final data = asMap(result.data);
    final accessToken = asString(data?['accesstoken']);
    final refreshToken = asString(data?['refreshtoken']);
    final role = asString(data?['role']);

    if (accessToken.isEmpty || role.isEmpty) {
      return ApiResult.failure<LoginResult>('Giriş yanıtı okunamadı');
    }

    return ApiResult.success<LoginResult>(
      LoginResult(
        accessToken: accessToken,
        refreshToken: refreshToken,
        role: role,
      ),
    );
  }
}
