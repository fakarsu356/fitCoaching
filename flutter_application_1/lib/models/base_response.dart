class BaseResponse<T> {
  final bool status;
  final String? banner;
  final T? data;

  BaseResponse({
    required this.status,
    this.banner,
    this.data,
  });

  factory BaseResponse.fromJson(Map<String, dynamic> json, {T Function(dynamic)? fromJsonData}) {
    return BaseResponse<T>(
      status: json['Status'] ?? false,
      banner: json['Banner'],
      data: json['Data'] != null && fromJsonData != null
          ? fromJsonData(json['Data'])
          : json['Data'],
    );
  }
}