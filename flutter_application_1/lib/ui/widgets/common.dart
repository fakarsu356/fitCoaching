import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Bootstrap 5 `.card` karşılığı: beyaz zemin, ince kenarlık ve yumuşak gölge.
/// Uygulamadaki tüm gruplamalar bunu kullanır.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.cardPadding),
    this.onTap,
    this.borderColor,
    this.background,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppSizes.radius));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        border: Border.all(color: borderColor ?? AppColors.border),
        borderRadius: radius,
        boxShadow: AppShadows.card,
      ),
      // Dalga efekti kartın zemininin üstünde kalsın diye Material/InkWell
      // içeride: dıştaki Container donuk olduğu için altına çizilen splash
      // görünmezdi.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Bölüm başlığı + isteğe bağlı sağ aksiyon.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gapSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Durum rozeti (bekliyor / tamamlandı / aktif ...).
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.color = AppColors.textSecondary,
    this.background = AppColors.surfaceMuted,
  });

  const StatusPill.success(this.label, {super.key})
    : color = AppColors.success,
      background = AppColors.successSoft;

  const StatusPill.warning(this.label, {super.key})
    : color = AppColors.warning,
      background = AppColors.warningSoft;

  const StatusPill.danger(this.label, {super.key})
    : color = AppColors.danger,
      background = AppColors.dangerSoft;

  const StatusPill.info(this.label, {super.key})
    : color = AppColors.info,
      background = AppColors.infoSoft;

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Puanı yıldızla gösterir. Yarım puanları da çizer; tıklanabilir değil,
/// puan verme akışı `RateCoachSheet` içinde.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.value,
    this.size = 18,
    this.label,
  });

  /// 0-5 arası ortalama puan.
  final double value;
  final double size;

  /// Yıldızların sağında gösterilecek metin (örn. "4,0 · 12 değerlendirme").
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            value >= star
                ? Icons.star_rounded
                : value >= star - 0.5
                ? Icons.star_half_rounded
                : Icons.star_border_rounded,
            size: size,
            color: value >= star - 0.5
                ? AppColors.rating
                : AppColors.borderStrong,
          ),
        if (label != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label!,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

/// Etiket + değer satırı.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Rakam vurgulu küçük kutu (kcal, protein, set sayısı ...).
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.loading = false,
  });

  final String label;
  final String value;
  final String? unit;

  /// true iken etiket yerinde kalır, yalnızca rakam iskelete döner. Kutunun
  /// tamamı iskelet olsaydı gün değiştirirken ekranın şablonu kaybolurdu.
  final bool loading;

  /// Rakam satırının sabit yüksekliği: iskelet ile gerçek değer aynı yeri
  /// kaplasın, geçişte kutu büyüyüp küçülmesin.
  static const double _valueHeight = 22;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          SizedBox(
            height: _valueHeight,
            child: ContentSwap(
              loading: loading,
              skeleton: const Align(
                alignment: Alignment.centerLeft,
                child: Skeleton(width: 52, height: 18, color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 3),
                    Text(unit!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş liste durumu.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? description;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.gapLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Hata durumu + tekrar dene.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.gapLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 36,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Tekrar dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Form alanı: etiket üstte, alan altta.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(hint!, style: Theme.of(context).textTheme.labelSmall),
        ],
      ],
    );
  }
}

/// İki seçenekli segment (cinsiyet, rol vb.).
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((entry) {
        final selected = entry.key == value;
        return InkWell(
          onTap: () => onChanged(entry.key),
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.surface,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderStrong,
                width: selected ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// İçerik yüklenirken onun yerini tutan gri blok.
///
/// Ölçüler yerini tuttuğu metne göre verilir: iskelet ile gerçek içerik aynı
/// yüksekliği kaplarsa geçişte satırlar yerinden oynamaz, ekran zıplamaz.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 12,
    this.radius = AppSizes.radiusTiny,
    this.color = AppColors.surfaceMuted,
  });

  /// Verilmezse bulunduğu alanı doldurur.
  final double? width;
  final double height;
  final double radius;

  /// Zaten gri bir kutunun içindeki iskeletler görünmez olmasın diye
  /// (örn. [MetricTile]) bir tık koyu ton verilebilir.
  final Color color;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.pulse,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      // Tamamen kaybolmuyor: sönüp yeniden belirmesi "yükleniyor" hissini
      // verirken blokların oluşturduğu şablon ekranda okunur kalıyor.
      opacity: Tween<double>(begin: 1, end: 0.45).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Aynı yerde duran iki görünüm arasında yumuşak geçiş: yüklenirken
/// [skeleton], hazır olunca [child].
///
/// Bölüm başlıkları ve kart çerçeveleri bu sarmalayıcının dışında bırakılır;
/// amaç şablonun sabit kalıp yalnızca içeriğin değişmesi.
class ContentSwap extends StatelessWidget {
  const ContentSwap({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.swap,
      // Varsayılan geçiş eskiyi ve yeniyi üst üste bindirip ikisinin de
      // yüksekliğini istediği için liste içinde zıplamaya yol açıyor; sadece
      // yeni çocuğun boyutu esas alınsın diye layoutBuilder sadeleştirildi.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [
          for (final entry in previous)
            Positioned(left: 0, right: 0, top: 0, child: entry),
          ?current,
        ],
      ),
      child: KeyedSubtree(
        key: ValueKey(loading),
        child: loading ? skeleton : child,
      ),
    );
  }
}

/// Yükleniyor / hata / veri durumlarını tek yerde yöneten liste sarmalayıcı.
class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.builder,
    this.data,
    this.skeleton,
  });

  final bool loading;
  final String? error;
  final T? data;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  /// Yüklenirken çizilecek iskelet. Verilmezse ortada dönen gösterge çıkar —
  /// ekranın şablonu belli olmayan yerlerde (form, tek kart) hâlâ doğru olan
  /// davranış bu.
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (loading) {
      content =
          skeleton ??
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
    } else if (error != null) {
      content = ErrorState(message: error!, onRetry: onRetry);
    } else if (data == null) {
      content = const EmptyState(title: 'Kayıt bulunamadı');
    } else {
      content = builder(data as T);
    }

    return AnimatedSwitcher(
      duration: AppDurations.swap,
      child: KeyedSubtree(
        key: ValueKey('$loading|${error != null}|${data == null}'),
        child: content,
      ),
    );
  }
}

void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.textPrimary,
      ),
    );
}

/// Yıkıcı işlemler için onay penceresi.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Onayla',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Vazgeç',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? AppColors.danger : AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
