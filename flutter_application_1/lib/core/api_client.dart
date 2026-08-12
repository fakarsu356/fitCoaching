import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_result.dart';
import 'session.dart';

/// Backend'e giden tüm istekler buradan geçer.
///
/// Notlar:
/// * Backend'in tamamı POST kullanıyor, o yüzden tek bir [post] yeterli.
/// * `utils.Response` hatalarda da HTTP 200 döndüğü için `validateStatus`
///   kapatıldı; başarı/başarısızlık kararını [parseResponseBody] veriyor.
/// * 401 alındığında refresh token ile bir kez yenileme denenip istek
///   tekrarlanır.
class ApiClient {
  ApiClient({required this.session, String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? defaultBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 60),
          validateStatus: (_) => true,
          headers: {'Accept': 'application/json'},
        ),
      );

  final Session session;
  final Dio _dio;

  /// Oturum kurtarılamadığında (refresh de başarısız) tetiklenir.
  VoidCallback? onSessionExpired;

  /// Android emülatörü ana makineye 10.0.2.2 üzerinden ulaşır; masaüstü ve
  /// web'de doğrudan localhost kullanılır.
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    } catch (_) {
      // Platform erişilemezse varsayılana düş.
    }
    return 'http://127.0.0.1:8080';
  }

  String get baseUrl => _dio.options.baseUrl;

  set baseUrl(String value) => _dio.options.baseUrl = value;

  Options _authOptions() {
    final token = session.accessToken;
    return Options(
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// JSON gövdeli POST isteği.
  ///
  /// [dataKey] ham `gin.H` cevaplarında okunacak anahtardır
  /// (örn. `/relations/myStudents` için `"Students"`).
  Future<ApiResult<dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? dataKey,
    bool authenticated = true,
  }) {
    return _send(
      path: path,
      dataKey: dataKey,
      authenticated: authenticated,
      request: (options) => _dio.post(
        path,
        data: body ?? const <String, dynamic>{},
        options: options,
      ),
    );
  }

  /// multipart/form-data POST isteği (koç kaydı ve belge yükleme).
  Future<ApiResult<dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<MultipartFile> files = const [],
    String filesFieldName = 'files',
    Map<String, MultipartFile> namedFiles = const {},
    String? dataKey,
    bool authenticated = true,
  }) {
    return _send(
      path: path,
      dataKey: dataKey,
      authenticated: authenticated,
      request: (options) {
        // FormData her denemede yeniden kurulmalı: stream'i bir kez okunuyor.
        final form = FormData();
        fields.forEach((key, value) {
          form.fields.add(MapEntry(key, value));
        });
        for (final file in files) {
          form.files.add(MapEntry(filesFieldName, file));
        }
        namedFiles.forEach((key, file) {
          form.files.add(MapEntry(key, file));
        });
        return _dio.post(path, data: form, options: options);
      },
    );
  }

  Future<ApiResult<dynamic>> _send({
    required String path,
    required Future<Response<dynamic>> Function(Options options) request,
    String? dataKey,
    bool authenticated = true,
  }) async {
    try {
      var response = await request(
        authenticated ? _authOptions() : Options(),
      );

      if (authenticated && response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          onSessionExpired?.call();
          return ApiResult.failure<dynamic>(
            'Oturumun süresi doldu, tekrar giriş yap',
          );
        }
        response = await request(_authOptions());
      }

      return parseResponseBody(
        response.data,
        dataKey: dataKey,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response?.data != null) {
        return parseResponseBody(
          e.response!.data,
          dataKey: dataKey,
          statusCode: e.response!.statusCode,
        );
      }
      return ApiResult.failure<dynamic>(_networkMessage(e));
    } catch (e) {
      return ApiResult.failure<dynamic>('Beklenmeyen hata: $e');
    }
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _dio.post(
        '/refresh',
        data: {'refreshtoken': refreshToken},
      );
      final result = parseResponseBody(
        response.data,
        statusCode: response.statusCode,
      );
      if (result.ok && result.data is String && (result.data as String).isNotEmpty) {
        await session.updateAccessToken(result.data as String);
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Sunucu yanıt vermedi, bağlantını kontrol et';
      case DioExceptionType.connectionError:
        return 'Sunucuya bağlanılamadı ($baseUrl)';
      default:
        return e.message ?? 'Ağ hatası';
    }
  }
}
