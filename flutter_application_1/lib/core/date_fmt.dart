/// Backend `time.Parse("2006-01-02 15:04:05", ...)` kullandığı için gönderilen
/// tarihler bu formatta olmak zorunda. Dönen tarihler ise Go'nun varsayılanı
/// olan RFC3339 formatında geliyor.
class AppDate {
  const AppDate._();

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// Backend'in beklediği "yyyy-MM-dd HH:mm:ss" formatı.
  static String toApi(DateTime date) {
    return '${date.year}-${_two(date.month)}-${_two(date.day)} '
        '${_two(date.hour)}:${_two(date.minute)}:${_two(date.second)}';
  }

  /// Günün başlangıcı (00:00:00) — tarih aralığı sorgularında kullanılır.
  static String dayStart(DateTime date) {
    return '${date.year}-${_two(date.month)}-${_two(date.day)} 00:00:00';
  }

  /// Günün sonu (23:59:59).
  static String dayEnd(DateTime date) {
    return '${date.year}-${_two(date.month)}-${_two(date.day)} 23:59:59';
  }

  static DateTime? parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toLocal();
  }

  /// "12.08.2026"
  static String short(DateTime? date) {
    if (date == null) return '-';
    return '${_two(date.day)}.${_two(date.month)}.${date.year}';
  }

  /// "12.08.2026 14:30"
  static String long(DateTime? date) {
    if (date == null) return '-';
    return '${short(date)} ${_two(date.hour)}:${_two(date.minute)}';
  }

  /// "14:30"
  static String time(DateTime? date) {
    if (date == null) return '-';
    return '${_two(date.hour)}:${_two(date.minute)}';
  }

  static const List<String> _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  /// "12 Ağustos 2026"
  static String readable(DateTime? date) {
    if (date == null) return '-';
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// İki tarih arasındaki farkı "3 sa 45 dk" biçiminde verir.
  static String duration(DateTime? from, DateTime? to) {
    if (from == null || to == null) return '-';
    final minutes = to.difference(from).inMinutes;
    if (minutes <= 0) return '-';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest dk';
    if (rest == 0) return '$hours sa';
    return '$hours sa $rest dk';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
