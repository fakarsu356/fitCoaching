import 'dart:convert';
import 'dart:typed_data';

import '../core/json_utils.dart';

/// `models.CoachM` karşılığı — /coaches, /relations/myCoach, /profile/coach.
///
/// Puan, değerlendirme sayısı ve sertifikalar yalnızca profil ucundan gelir
/// (diğer uçlarda `omitempty` ile düşüyor), o yüzden hepsi opsiyonel.
class Coach {
  const Coach({
    required this.userId,
    required this.username,
    required this.email,
    required this.gender,
    required this.speciality,
    required this.maxStudents,
    required this.activeStudents,
    required this.status,
    this.rating,
    this.ratingCount,
    this.documents = const [],
  });

  final int userId;
  final String username;
  final String email;
  final String gender;
  final String speciality;
  final int maxStudents;
  final int activeStudents;
  final String status;

  /// Ortalama puan. Henüz puan yoksa null (backend bu durumda -1 döndürüyor).
  final double? rating;
  final int? ratingCount;

  /// Koçun yüklediği sertifikalar.
  final List<CoachDocument> documents;

  int get freeSlots => (maxStudents - activeStudents).clamp(0, maxStudents);

  bool get isFull => freeSlots <= 0;

  bool get hasRating => rating != null && (ratingCount ?? 0) > 0;

  /// Koç adı boş gelirse (eski kayıtlar) id ile göster.
  String get displayName =>
      username.trim().isEmpty ? 'Koç #$userId' : username.trim();

  /// Liste ucundan gelen kartın üstüne profil ucunun ayrıntılarını yazar.
  /// Profil ekranı, veri gelene kadar elindeki özet kartı göstermeye devam
  /// edebilsin diye ayrı bir model yerine bu birleştirme kullanılıyor.
  Coach mergeDetails(Coach details) {
    return Coach(
      userId: details.userId == 0 ? userId : details.userId,
      username: details.username.isEmpty ? username : details.username,
      email: details.email.isEmpty ? email : details.email,
      gender: details.gender.isEmpty ? gender : details.gender,
      speciality: details.speciality.isEmpty ? speciality : details.speciality,
      maxStudents: details.maxStudents == 0 ? maxStudents : details.maxStudents,
      activeStudents: details.activeStudents,
      status: details.status.isEmpty ? status : details.status,
      rating: details.rating ?? rating,
      ratingCount: details.ratingCount ?? ratingCount,
      documents: details.documents.isEmpty ? documents : details.documents,
    );
  }

  factory Coach.fromJson(Map<String, dynamic> json) {
    // /coaches ve /relations/myCoach models.CoachM (snake_case) döndürüyor;
    // /relations/pastCoaches ise ham entities.Coach döndürdüğü için kullanıcı
    // bilgileri iç içe `User` alanından okunur.
    final user = asMap(pick(json, ['User', 'user']));
    String fromUser(List<String> keys) =>
        user == null ? '' : asString(pick(user, keys));

    // Hiç puanı olmayan koç için repository ortalamayı -1 döndürüyor; bu bir
    // puan değil "henüz değerlendirilmemiş" demek.
    final rawRating = pick(json, ['rating', 'Rating']);
    final rating = rawRating == null ? null : asDouble(rawRating);
    final count = asIntOrNull(pick(json, ['rating_count', 'RatingCount']));

    return Coach(
      userId: asInt(pick(json, ['user_id', 'UserID'])),
      username: asString(pick(json, ['username', 'Username'])).isNotEmpty
          ? asString(pick(json, ['username', 'Username']))
          : fromUser(['Username', 'username']),
      email: asString(pick(json, ['email', 'Email'])).isNotEmpty
          ? asString(pick(json, ['email', 'Email']))
          : fromUser(['Email', 'email']),
      gender: asString(pick(json, ['gender', 'Gender'])).isNotEmpty
          ? asString(pick(json, ['gender', 'Gender']))
          : fromUser(['Gender', 'gender']),
      speciality: asString(pick(json, ['speciality', 'Speciality'])),
      maxStudents: asInt(pick(json, ['max_students', 'MaxStudents'])),
      activeStudents: asInt(pick(json, ['active_students', 'ActiveStudents'])),
      status: asString(pick(json, ['status', 'Status'])),
      rating: rating == null || rating < 0 ? null : rating,
      ratingCount: count == null || count < 0 ? null : count,
      documents: asMapList(pick(json, ['documents', 'CoachDoc']))
          .map(CoachDocument.fromJson)
          .toList(),
    );
  }
}

/// Koç profilindeki sertifika — `entities.Document`.
///
/// Belge listesi ucunun aksine profil ucu dosya içeriğini de gömüyor, bu yüzden
/// görsel sertifikalar ayrı bir istek olmadan gösterilebiliyor.
class CoachDocument {
  const CoachDocument({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    this.date,
    this.bytes,
  });

  final int id;
  final String name;

  /// Sunucudaki `Doctype` alanı MIME type tutuyor (örn. application/pdf).
  final String mimeType;
  final double sizeBytes;
  final DateTime? date;

  /// Şifresi çözülmüş dosya içeriği; uç göndermezse null.
  final Uint8List? bytes;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';
  bool get hasPreview => isImage && bytes != null && bytes!.isNotEmpty;

  String get displayName => name.trim().isEmpty ? 'Sertifika #$id' : name.trim();

  /// "1,4 MB" — dosya boyutunun okunabilir hali.
  String get sizeLabel {
    if (sizeBytes <= 0) return '-';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = sizeBytes;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = value >= 10 || unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1).replaceAll('.', ',');
    return '$text ${units[unit]}';
  }

  factory CoachDocument.fromJson(Map<String, dynamic> json) {
    // Go `[]byte`'ı base64 string olarak serialize eder; bozuk/eksik içerik
    // profilin tamamını çökertmesin diye sessizce atlanır.
    Uint8List? decode(dynamic value) {
      if (value is! String || value.isEmpty) return null;
      try {
        return base64Decode(value);
      } catch (_) {
        return null;
      }
    }

    return CoachDocument(
      id: asInt(pick(json, ['ID', 'id'])),
      name: asString(pick(json, ['DocName', 'doc_name'])),
      // Entity alanının adı `Doctype`, json tag'i olmadığı için anahtar da
      // aynen böyle geliyor.
      mimeType: asString(pick(json, ['Doctype', 'DocType', 'doc_type'])),
      sizeBytes: asDouble(pick(json, ['Size', 'size'])),
      date: DateTime.tryParse(asString(pick(json, ['Date', 'date'])))?.toLocal(),
      bytes: decode(pick(json, ['File', 'file'])),
    );
  }
}
