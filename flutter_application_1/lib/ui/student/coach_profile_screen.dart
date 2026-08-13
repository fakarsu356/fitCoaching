import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_fmt.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/coach.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'coach_card.dart';

/// Koçun herkese açık profili: puan ortalaması, kontenjan durumu ve
/// sertifikaları.
///
/// Ekran, listeden gelen özet [coach] ile hemen çizilir; `/profile/coach`
/// cevabı gelince aynı kart puan ve sertifikalarla zenginleşir. Böylece
/// açılışta boş ekran görünmüyor.
///
/// [canRequest] verildiğinde altta "İstek gönder" düğmesi çıkar; düğmeye
/// basılınca ekran `true` ile kapanır ve isteği açan liste ekranı gönderir —
/// istek gönderme kuralları tek yerde kalsın diye.
class CoachProfileScreen extends StatefulWidget {
  const CoachProfileScreen({
    super.key,
    required this.coach,
    this.canRequest = false,
  });

  final Coach coach;
  final bool canRequest;

  @override
  State<CoachProfileScreen> createState() => _CoachProfileScreenState();
}

class _CoachProfileScreenState extends State<CoachProfileScreen> {
  late Coach _coach = widget.coach;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await context.read<AppServices>().profiles.getCoachProfile(
      widget.coach.userId,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok && result.data != null) {
        _coach = widget.coach.mergeDetails(result.data!);
      } else {
        _error = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koç profili'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            _Header(coach: _coach),
            const SizedBox(height: AppSizes.gap),
            _Capacity(coach: _coach),
            const SizedBox(height: AppSizes.gapLarge),
            _Certificates(
              documents: _coach.documents,
              loading: _loading,
              error: _error,
              onRetry: _load,
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.canRequest
          ? SafeArea(
              minimum: const EdgeInsets.all(AppSizes.pagePadding),
              child: ElevatedButton(
                onPressed: _coach.isFull
                    ? null
                    : () => Navigator.of(context).pop(true),
                child: Text(
                  _coach.isFull ? 'Kontenjan dolu' : 'İstek gönder',
                ),
              ),
            )
          : null,
    );
  }
}

/// Ad, uzmanlık ve puan.
class _Header extends StatelessWidget {
  const _Header({required this.coach});

  final Coach coach;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (coach.speciality.isNotEmpty) coach.speciality,
      if (coach.gender.isNotEmpty) Gender.label(coach.gender),
    ].join(' · ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoachAvatar(
                name: coach.displayName,
                size: AppSizes.avatar * 1.5,
              ),
              const SizedBox(width: AppSizes.gapSmall + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSizes.gapSmall),
                    if (coach.isFull)
                      const StatusPill.warning('Kontenjan dolu')
                    else
                      StatusPill.success('${coach.freeSlots} boş yer'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gap),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSizes.gap),
          if (coach.hasRating)
            RatingStars(
              value: coach.rating!,
              size: 20,
              label:
                  '${coach.rating!.toStringAsFixed(1).replaceAll('.', ',')} · '
                  '${coach.ratingCount} değerlendirme',
            )
          else
            Text(
              'Henüz değerlendirilmemiş',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// Kontenjan rakamları.
class _Capacity extends StatelessWidget {
  const _Capacity({required this.coach});

  final Coach coach;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: 'Boş kontenjan',
            value: '${coach.freeSlots}',
            unit: 'kişi',
          ),
        ),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: MetricTile(
            label: 'Toplam kontenjan',
            value: '${coach.maxStudents}',
            unit: 'kişi',
          ),
        ),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: MetricTile(
            label: 'Puan',
            value: coach.hasRating
                ? coach.rating!.toStringAsFixed(1).replaceAll('.', ',')
                : '-',
            unit: coach.hasRating ? '/ 5' : null,
          ),
        ),
      ],
    );
  }
}

/// Koçun yüklediği sertifikalar.
class _Certificates extends StatelessWidget {
  const _Certificates({
    required this.documents,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<CoachDocument> documents;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Sertifikalar',
          subtitle: 'Koçun yüklediği belgeler.',
        ),
        // Yükleme/hata yalnızca bu bölümü kaplar: üstteki özet listeden gelen
        // veriyle zaten dolu olduğu için tüm ekranı boşaltmak gereksiz.
        if (loading)
          const Padding(
            padding: EdgeInsets.all(AppSizes.gapLarge),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (error != null)
          ErrorState(message: error!, onRetry: onRetry)
        else if (documents.isEmpty)
          const EmptyState(
            icon: Icons.workspace_premium_outlined,
            title: 'Sertifika yok',
            description: 'Bu koç henüz belge yüklememiş.',
          )
        else
          for (final document in documents) ...[
            _CertificateTile(document: document),
            const SizedBox(height: AppSizes.gapSmall),
          ],
      ],
    );
  }
}

class _CertificateTile extends StatelessWidget {
  const _CertificateTile({required this.document});

  final CoachDocument document;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      document.sizeLabel,
      if (document.date != null) AppDate.short(document.date),
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
      onTap: document.hasPreview
          ? () => _showPreview(context, document)
          : null,
      child: Row(
        children: [
          _Thumbnail(document: document),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (document.hasPreview) ...[
            const SizedBox(width: AppSizes.gapSmall),
            const Icon(
              Icons.zoom_out_map,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}

/// Görsel sertifikaların küçük önizlemesi; diğerlerinde tür ikonu.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.document});

  final CoachDocument document;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.radiusSmall);

    if (document.hasPreview) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          document.bytes!,
          width: AppSizes.avatar,
          height: AppSizes.avatar,
          fit: BoxFit.cover,
          // Bozuk içerik satırı çökertmesin.
          errorBuilder: (_, _, _) => _icon(radius),
        ),
      );
    }
    return _icon(radius);
  }

  Widget _icon(BorderRadius radius) {
    return Container(
      width: AppSizes.avatar,
      height: AppSizes.avatar,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: radius,
      ),
      child: Icon(
        document.isPdf
            ? Icons.picture_as_pdf_outlined
            : Icons.description_outlined,
        size: 20,
        color: AppColors.textSecondary,
      ),
    );
  }
}

void _showPreview(BuildContext context, CoachDocument document) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSizes.pagePadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            child: SectionTitle(
              document.displayName,
              subtitle: document.sizeLabel,
              action: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.memory(document.bytes!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: AppSizes.cardPadding),
        ],
      ),
    ),
  );
}
