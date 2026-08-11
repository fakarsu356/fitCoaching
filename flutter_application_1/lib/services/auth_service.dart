import 'package:dio/dio.dart';
import '../models/base_response.dart';

class AuthService {
  // 10.0.2.2 Android emülatörün senin bilgisayarındaki Go sunucusuna bağlanma adresidir.
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:8080', 
  ));

  Future<BaseResponse<dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      Map<String, dynamic> requestBody = {
        "email": email,
        "password": password,
      };

      // Go'daki giriş URL'ni buraya yazmalısın. Eğer farklıysa '/login' kısmını değiştir.
      Response response = await _dio.post(
        '/login', 
        data: requestBody,
      );

      return BaseResponse.fromJson(response.data);

    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        return BaseResponse.fromJson(e.response!.data);
      }
      return BaseResponse(status: false, banner: "Sunucu hatası: ${e.message}");
    } catch (e) {
      return BaseResponse(status: false, banner: "Bir hata oluştu: $e");
    }
  }
}