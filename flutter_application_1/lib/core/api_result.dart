/// Backend tek bir cevap formatı kullanmıyor:
///
/// * `utils.Response` ile dönen uçlar `{status, banner, data, line}` veriyor
///   ve hata durumunda bile HTTP 200 dönüyor.
/// * Bazı uçlar ham `gin.H` döndürüyor: `{"error": "..."}`,
///   `{"Students": [...]}`, `{"Coach": {...}}` gibi.
///
/// [ApiResult] iki formatı da tek tipe indirger; ekranlar sadece [ok],
/// [message] ve [data] ile ilgilenir.
class ApiResult<T> {
  const ApiResult({required this.ok, this.message, this.data});

  final bool ok;
  final String? message;
  final T? data;

  bool get isError => !ok;

  /// Hata mesajı; backend boş bıraktıysa genel bir metne düşer.
  String get errorMessage =>
      (message == null || message!.trim().isEmpty)
      ? 'Bir hata oluştu, tekrar deneyin'
      : message!;

  ApiResult<R> map<R>(R Function(T value) transform) {
    if (!ok || data == null) {
      return ApiResult<R>(ok: ok, message: message);
    }
    return ApiResult<R>(ok: ok, message: message, data: transform(data as T));
  }

  static ApiResult<T> success<T>(T? data, [String? message]) {
    return ApiResult<T>(ok: true, message: message, data: data);
  }

  static ApiResult<T> failure<T>(String? message) {
    return ApiResult<T>(ok: false, message: message);
  }
}

/// Ham cevap gövdesini [ApiResult]'a çevirir.
///
/// [dataKey] verilirse (`"Students"`, `"Coach"` gibi) ham `gin.H` cevaplarından
/// o anahtar okunur; `utils.Response` formatında ise `data` alanı kullanılır.
ApiResult<dynamic> parseResponseBody(
  dynamic body, {
  String? dataKey,
  int? statusCode,
}) {
  if (body is! Map) {
    final ok = statusCode == null || (statusCode >= 200 && statusCode < 300);
    return ApiResult<dynamic>(ok: ok, data: body);
  }

  // Ham hata formatı: {"error": "..."}
  if (body.containsKey('error')) {
    return ApiResult<dynamic>(ok: false, message: body['error']?.toString());
  }

  // utils.ResponseS formatı
  if (body.containsKey('status')) {
    final ok = body['status'] == true;
    return ApiResult<dynamic>(
      ok: ok,
      message: body['banner']?.toString(),
      data: body['data'],
    );
  }

  // Ham başarı formatı: {"Students": [...]} gibi
  final httpOk = statusCode == null || (statusCode >= 200 && statusCode < 300);
  if (dataKey != null && body.containsKey(dataKey)) {
    return ApiResult<dynamic>(ok: httpOk, data: body[dataKey]);
  }
  return ApiResult<dynamic>(ok: httpOk, data: body);
}
