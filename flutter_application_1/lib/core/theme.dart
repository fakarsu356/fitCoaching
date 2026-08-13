import 'package:flutter/material.dart';

/// Uygulamanın renk paleti — Bootstrap 5 sistemine göre kuruldu.
///
/// Bootstrap'te sayfa zemini gri (`--bs-body-tertiary-bg`), içerik ise beyaz
/// kartların içinde durur. Vurgu rengi projeye özgü yeşil olarak korundu;
/// gri/metin/kenarlık tonları Bootstrap'in gray ölçeğinden alındı.
/// Dark mode eklenirken sadece [AppTheme.dark] yazılması yeterli olacak şekilde
/// tüm renkler burada tek yerde toplandı.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF16A34A);
  static const Color primaryDark = Color(0xFF15803D);

  /// Bootstrap'in `bg-label-*` mantığı: rengin beyaz üzerine açık tonu.
  static const Color primarySoft = Color(0xFFE8F6EE);

  /// Sayfa zemini (bs gray-100). Kartlar bunun üstünde beyaz durur.
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);

  /// Kart içindeki ikincil kutular (bs gray-200).
  static const Color surfaceMuted = Color(0xFFF1F3F5);

  static const Color border = Color(0xFFE9ECEF);
  static const Color borderStrong = Color(0xFFCED4DA);

  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textMuted = Color(0xFFADB5BD);

  static const Color success = Color(0xFF198754);
  static const Color successSoft = Color(0xFFE7F4EE);
  static const Color danger = Color(0xFFDC3545);
  static const Color dangerSoft = Color(0xFFFBEAEC);
  static const Color warning = Color(0xFF997404);
  static const Color warningSoft = Color(0xFFFFF6E0);
  static const Color info = Color(0xFF0D6EFD);
  static const Color infoSoft = Color(0xFFE7F0FE);

  /// Yıldız/puan rengi (bs warning).
  static const Color rating = Color(0xFFFFC107);
}

/// Ortak ölçüler — ekranlar arası tutarlılık için.
///
/// Boşluklar Bootstrap'in spacer ölçeğine (4 / 8 / 16 / 24 / 48) oturur,
/// yarıçaplar `--bs-border-radius` ailesine (4 / 6 / 8) karşılık gelir.
class AppSizes {
  const AppSizes._();

  /// Kart yarıçapı (bs `border-radius-lg`).
  static const double radius = 8;

  /// Alan, buton ve rozet yarıçapı (bs `border-radius`).
  static const double radiusSmall = 6;

  /// En küçük yarıçap (bs `border-radius-sm`).
  static const double radiusTiny = 4;

  static const double pagePadding = 16;
  static const double gap = 16;
  static const double gapSmall = 8;
  static const double gapLarge = 24;

  /// Avatar ve ikon kutularının tek ölçüsü.
  static const double avatar = 44;

  /// Liste satırı gibi ince kartların iç boşluğu.
  static const double cardPaddingCompact = 12;

  /// Kartların standart iç boşluğu.
  static const double cardPadding = 16;

  /// Buton ve giriş alanlarının tek yüksekliği.
  static const double controlHeight = 48;

  /// "Set 1" etiketinin sabit genişliği — plan listesi ile tamamlama formundaki
  /// satırların hizası aynı olsun diye.
  static const double setLabelWidth = 52;
}

/// Bootstrap'in `box-shadow-sm` karşılığı — kartları zeminden ayıran yumuşak
/// gölge. Tek yerde durur ki bütün kartlar aynı derinlikte olsun.
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14435971),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    );

    const controlRadius = BorderRadius.all(
      Radius.circular(AppSizes.radiusSmall),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      splashFactory: InkSparkle.splashFactory,
      // Bootstrap navbar'ı gibi: beyaz zemin, altında ince ayraç.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: AppColors.border)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      // Bootstrap tipografisi: gövde 1rem, `small` 0.875rem, h5 1.25rem.
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: inputBorder(AppColors.borderStrong),
        enabledBorder: inputBorder(AppColors.borderStrong),
        // bs `:focus` — kenarlık vurgu rengine döner ve kalınlaşır.
        focusedBorder: inputBorder(AppColors.primary, 1.8),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, 1.8),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        helperStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderStrong,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        side: BorderSide(color: AppColors.border),
        labelStyle: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusSmall)),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusSmall)),
        ),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
