import '../core/json_utils.dart';

/// `entities.Meal` — PascalCase döner.
///
/// `karb` ve `lif` sonradan eklendi: bu alanlar yokken kaydedilmiş öğünlerde
/// sunucu 0 döndürür, ekranda da 0 g görünür.
class Meal {
  const Meal({
    required this.id,
    required this.studentId,
    required this.mealName,
    required this.description,
    required this.kcal,
    required this.protein,
    required this.oil,
    required this.karb,
    required this.lif,
    this.date,
  });

  final int id;
  final int studentId;
  final String mealName;
  final String description;
  final double kcal;
  final double protein;
  final double oil;

  /// Karbonhidrat (g).
  final double karb;

  /// Lif (g).
  final double lif;
  final DateTime? date;

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: asInt(pick(json, ['ID', 'id'])),
      studentId: asInt(pick(json, ['StudentID', 'student_id'])),
      mealName: asString(pick(json, ['MealName', 'meal_name'])),
      description: asString(pick(json, ['Description', 'description'])),
      kcal: asDouble(pick(json, ['Kcal', 'kcal'])),
      protein: asDouble(pick(json, ['Protein', 'protein'])),
      oil: asDouble(pick(json, ['Oil', 'oil'])),
      karb: asDouble(pick(json, ['Karb', 'karb'])),
      lif: asDouble(pick(json, ['Lif', 'lif'])),
      date: DateTime.tryParse(
        asString(pick(json, ['Date', 'date'])),
      )?.toLocal(),
    );
  }
}

/// `/meal/dailyMeals` günün toplamını yine bir Meal gövdesiyle döndürüyor.
class MealSummary {
  const MealSummary({
    required this.kcal,
    required this.protein,
    required this.oil,
    required this.karb,
    required this.lif,
    this.date,
  });

  final double kcal;
  final double protein;
  final double oil;
  final double karb;
  final double lif;
  final DateTime? date;

  bool get isEmpty =>
      kcal == 0 && protein == 0 && oil == 0 && karb == 0 && lif == 0;

  factory MealSummary.fromJson(Map<String, dynamic> json) {
    return MealSummary(
      kcal: asDouble(pick(json, ['Kcal', 'kcal'])),
      protein: asDouble(pick(json, ['Protein', 'protein'])),
      oil: asDouble(pick(json, ['Oil', 'oil'])),
      karb: asDouble(pick(json, ['Karb', 'karb'])),
      lif: asDouble(pick(json, ['Lif', 'lif'])),
      date: DateTime.tryParse(
        asString(pick(json, ['Date', 'date'])),
      )?.toLocal(),
    );
  }

  static const MealSummary empty = MealSummary(
    kcal: 0,
    protein: 0,
    oil: 0,
    karb: 0,
    lif: 0,
  );
}

/// `entities.Sleep`
class Sleep {
  const Sleep({
    required this.id,
    required this.studentId,
    this.bedTime,
    this.wakeTime,
  });

  final int id;
  final int studentId;
  final DateTime? bedTime;
  final DateTime? wakeTime;

  Duration? get duration {
    if (bedTime == null || wakeTime == null) return null;
    final diff = wakeTime!.difference(bedTime!);
    return diff.isNegative ? null : diff;
  }

  factory Sleep.fromJson(Map<String, dynamic> json) {
    return Sleep(
      id: asInt(pick(json, ['ID', 'id'])),
      studentId: asInt(pick(json, ['StudentID', 'student_id'])),
      bedTime: DateTime.tryParse(
        asString(pick(json, ['BedTime', 'bed_time'])),
      )?.toLocal(),
      wakeTime: DateTime.tryParse(
        asString(pick(json, ['WakeTime', 'wake_time'])),
      )?.toLocal(),
    );
  }
}

/// `entities.Rating`
class Rating {
  const Rating({
    required this.id,
    required this.studentId,
    required this.coachId,
    required this.score,
    required this.description,
    this.createTime,
  });

  final int id;
  final int studentId;
  final int coachId;
  final int score;
  final String description;
  final DateTime? createTime;

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: asInt(pick(json, ['ID', 'id'])),
      studentId: asInt(pick(json, ['StudentID', 'student_id'])),
      coachId: asInt(pick(json, ['CoachID', 'coach_id'])),
      score: asInt(pick(json, ['Score', 'score'])),
      description: asString(pick(json, ['Description', 'description'])),
      createTime: DateTime.tryParse(
        asString(pick(json, ['CreateTime', 'create_time'])),
      )?.toLocal(),
    );
  }
}

/// `entities.DocType` değerleri — belge yüklerken `type` alanında gönderilir.
class DocumentType {
  const DocumentType._();

  static const String cv = 'CV';
  static const String certificate = 'Sertificate';
  static const String labResults = 'LabResults';
  static const String progressPictures = 'ProgressPictures';
  static const String mealPictures = 'MealPictures';

  /// Öğrencinin yükleyebildiği türler.
  static const Map<String, String> studentUploadable = {
    labResults: 'Tahlil / rapor',
    progressPictures: 'Gelişim fotoğrafı',
    mealPictures: 'Öğün fotoğrafı',
  };

  static const Map<String, String> labels = {
    cv: 'CV',
    certificate: 'Sertifika',
    labResults: 'Tahlil / rapor',
    progressPictures: 'Gelişim fotoğrafı',
    mealPictures: 'Öğün fotoğrafı',
  };

  static String label(String value) => labels[value] ?? value;
}

/// `handlers.DocumentListItem` — belge listesi (dosya içeriği içermez).
class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.docName,
    required this.mimeType,
    this.date,
  });

  final int id;
  final String docName;

  /// Sunucudaki `DocType` alanı MIME type tutuyor (örn. application/pdf).
  final String mimeType;
  final DateTime? date;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: asInt(pick(json, ['ID', 'id'])),
      docName: asString(pick(json, ['DocName', 'doc_name'])),
      mimeType: asString(pick(json, ['DocType', 'doc_type'])),
      date: DateTime.tryParse(
        asString(pick(json, ['Date', 'date'])),
      )?.toLocal(),
    );
  }
}
