/// Backend'deki doğrulama kurallarının birebir karşılığı.
///
/// Değerler hem `utils.ValidatePassword` / handler kontrollerinden hem de
/// entity'lerdeki gorm `check` kısıtlarından türetildi. İkisi çeliştiğinde
/// dar olan aralık alındı, böylece istek DB hatasına düşmüyor.
class Validators {
  const Validators._();

  // Öğrenci
  static const int minAge = 10;
  static const int maxAge = 50;
  static const double minFat = 1;
  static const double maxFat = 49.9; // DB: fat_percentage < 50
  static const double minWeight = 10;
  static const double maxWeight = 200;
  static const double minHeight = 50;
  static const double maxHeight = 249.9; // DB: body_height < 250

  // Koç
  static const int minStudents = 1;
  static const int maxStudents = 19; // DB: max_students < 20

  // Set
  static const int maxReps = 50;
  static const double maxSetWeight = 1000;
  static const int maxMovementNameLength = 32;

  static final RegExp _emailPattern = RegExp(
    r'^[\w.!#$%&*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$',
  );

  static String? required(String? value, {String label = 'Bu alan'}) {
    if (value == null || value.trim().isEmpty) return '$label zorunlu';
    return null;
  }

  static String? email(String? value) {
    final empty = required(value, label: 'E-posta');
    if (empty != null) return empty;
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Geçerli bir e-posta girin';
    }
    return null;
  }

  /// utils.ValidatePassword: en az 6 karakter, 1 küçük harf, 1 rakam,
  /// ve `.!@#$%^&*` içinden 1 özel karakter.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Şifre zorunlu';
    if (value.length < 6) return 'Şifre en az 6 karakter olmalı';
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Şifre en az 1 küçük harf içermeli';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Şifre en az 1 rakam içermeli';
    }
    if (!RegExp(r'[.!@#$%^&*]').hasMatch(value)) {
      return r'Şifre en az 1 özel karakter içermeli (. ! @ # $ % ^ & *)';
    }
    return null;
  }

  static String? passwordConfirm(String? value, String original) {
    if (value == null || value.isEmpty) return 'Şifre tekrarı zorunlu';
    if (value != original) return 'Şifreler eşleşmiyor';
    return null;
  }

  static String? intInRange(
    String? value, {
    required int min,
    required int max,
    required String label,
  }) {
    final empty = required(value, label: label);
    if (empty != null) return empty;
    final parsed = int.tryParse(value!.trim());
    if (parsed == null) return '$label tam sayı olmalı';
    if (parsed < min || parsed > max) return '$label $min ile $max arasında olmalı';
    return null;
  }

  static String? doubleInRange(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    final empty = required(value, label: label);
    if (empty != null) return empty;
    final parsed = double.tryParse(value!.trim().replaceAll(',', '.'));
    if (parsed == null) return '$label sayı olmalı';
    if (parsed < min || parsed > max) {
      return '$label ${_trim(min)} ile ${_trim(max)} arasında olmalı';
    }
    return null;
  }

  static String? age(String? value) =>
      intInRange(value, min: minAge, max: maxAge, label: 'Yaş');

  /// Yağ oranı zorunlu değil; boş bırakılırsa kayıt bu bilgi olmadan gider.
  static String? fatPercentageOptional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return doubleInRange(value, min: minFat, max: maxFat, label: 'Yağ oranı');
  }

  static String? bodyWeight(String? value) =>
      doubleInRange(value, min: minWeight, max: maxWeight, label: 'Kilo');

  static String? bodyHeight(String? value) =>
      doubleInRange(value, min: minHeight, max: maxHeight, label: 'Boy');

  static String? maxStudentCount(String? value) => intInRange(
    value,
    min: minStudents,
    max: maxStudents,
    label: 'Öğrenci kontenjanı',
  );

  static String? movementName(String? value) {
    final empty = required(value, label: 'Hareket adı');
    if (empty != null) return empty;
    if (value!.trim().length > maxMovementNameLength) {
      return 'Hareket adı en fazla $maxMovementNameLength karakter';
    }
    return null;
  }

  static String? reps(String? value) =>
      intInRange(value, min: 0, max: maxReps, label: 'Tekrar');

  static String? setWeight(String? value) =>
      doubleInRange(value, min: 0, max: maxSetWeight, label: 'Ağırlık');

  static String _trim(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  /// Metin alanını sayıya çevirir; virgüllü girişleri de kabul eder.
  static double toDouble(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  }

  static int toInt(String value) => int.tryParse(value.trim()) ?? 0;
}

/// entities.User içindeki `gender IN ('Male','female')` kısıtı bu iki değeri
/// birebir bekliyor — büyük/küçük harf farkı kasıtlı değil ama zorunlu.
class Gender {
  const Gender._();

  static const String male = 'Male';
  static const String female = 'female';

  static const Map<String, String> labels = {
    male: 'Erkek',
    female: 'Kadın',
  };

  static String label(String? value) => labels[value] ?? '-';
}

/// Koçun uzmanlık alanları.
class Speciality {
  const Speciality._();

  static const List<String> all = ['Fitness', 'Powerlifting', 'Koşu'];
}
