/// Sayıları Türkçe biçimde yazar: tam sayıysa ondalıksız ("40"), değilse tek
/// basamak ve virgüllü ("37,5").
///
/// Ağırlık, kalori ve makro değerlerinin tamamı buradan geçer ki aynı sayı her
/// ekranda aynı görünsün.
String formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

/// Farkı işaretiyle yazar: "+2,5", "-5", "0".
String formatSignedNumber(double value) {
  final text = formatNumber(value.abs());
  if (value > 0) return '+$text';
  if (value < 0) return '-$text';
  return '0';
}
