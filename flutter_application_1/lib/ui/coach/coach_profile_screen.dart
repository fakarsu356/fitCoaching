import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/api_result.dart';
import '../../core/date_fmt.dart';
import '../../models/coach.dart';
import '../../models/tracking.dart';
import '../../services/services.dart';
import '../../state/auth_controller.dart';
import '../student/coach_card.dart';
import '../widgets/common.dart';

/// Koçun kendi profili.
///
/// Üst bölüm öğrencilerin gördüğü profille aynı uçtan (`/profile/getCoach`)
/// besleniyor — koç kendisini öğrencinin gördüğü hâliyle görüyor. O uç yalnızca
/// sertifikaları döndürdüğü için CV gibi diğer belgeler ayrıca belge listesi
/// ucundan (`/document/getDocumentList`, öğrenci kimliği göndermeden) çekiliyor.
class CoachProfileScreen extends StatefulWidget {
  const CoachProfileScreen({super.key});

  @override
  State<CoachProfileScreen> createState() => _CoachProfileScreenState();
}

class _CoachProfileScreenState extends State<CoachProfileScreen> {
  Coach? _coach;
  List<DocumentItem> _otherDocuments = const [];
  String? _error;
  bool _loading = true;

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

    final coachId = context.read<Session>().userId;
    if (coachId == null) {
      setState(() {
        _loading = false;
        _error = 'Oturum bilgisi okunamadı, tekrar giriş yap';
      });
      return;
    }

    final services = context.read<AppServices>();
    // İki uç birlikte bekleniyor; belge listesi başarısız olursa profil yine
    // açılıyor, yalnızca alt bölüm boş kalıyor.
    final results = await Future.wait([
      services.profiles.getCoachProfile(coachId),
      services.documents.getList(),
    ]);
    final result = results[0] as ApiResult<Coach>;
    final documents = results[1] as ApiResult<List<DocumentItem>>;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _otherDocuments = documents.ok
          ? (documents.data ?? const <DocumentItem>[])
                .where((document) => document.type != DocumentType.certificate)
                .toList()
          : const <DocumentItem>[];
      if (result.ok) {
        _coach = result.data;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthController>();
    final confirmed = await confirmDialog(
      context,
      title: 'Çıkış yap',
      message: 'Oturumun kapatılacak. Devam edilsin mi?',
      confirmLabel: 'Çıkış yap',
      destructive: true,
    );
    if (confirmed) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: AsyncContent<Coach>(
        loading: _loading,
        error: _error,
        data: _coach,
        onRetry: _load,
        builder: (coach) => RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              _Header(coach: coach),
              const SizedBox(height: AppSizes.gap),
              _Capacity(coach: coach),
              const SizedBox(height: AppSizes.gapLarge),
              const SectionTitle(
                'Sertifikalar',
                subtitle: 'Kayıt olurken yüklediğin belgeler.',
              ),
              if (coach.documents.isEmpty)
                const AppCard(
                  child: Text(
                    'Yüklü sertifikan görünmüyor.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                for (final document in coach.documents) ...[
                  _CertificateTile(document: document),
                  const SizedBox(height: AppSizes.gapSmall),
                ],
              if (_otherDocuments.isNotEmpty) ...[
                const SizedBox(height: AppSizes.gapLarge),
                const SectionTitle(
                  'Diğer belgelerim',
                  subtitle: 'CV gibi yalnızca sana görünen belgeler.',
                ),
                for (final document in _otherDocuments) ...[
                  _DocumentTile(document: document),
                  const SizedBox(height: AppSizes.gapSmall),
                ],
              ],
              const SizedBox(height: AppSizes.gapLarge),
              const SectionTitle('Hesap'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('E-posta', coach.email.isEmpty ? '-' : coach.email),
                    const SizedBox(height: AppSizes.gapSmall),
                    InfoRow('Uzmanlık', coach.speciality),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.gap),
              OutlinedButton.icon(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
      ),
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
                      const StatusPill.warning('Kontenjanın dolu')
                    else
                      StatusPill.success('${coach.freeSlots} boş yerin var'),
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
              'Henüz değerlendirilmedin. Öğrencilerin ancak koçlukları bittikten '
              'sonra puan verebiliyor.',
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
            label: 'Aktif öğrenci',
            value: '${coach.activeStudents}',
            unit: 'kişi',
          ),
        ),
        const SizedBox(width: AppSizes.gapSmall),
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

/// Tek sertifika satırı. Önizleme yalnızca çözülmüş görsellerde açılıyor.
class _CertificateTile extends StatelessWidget {
  const _CertificateTile({required this.document});

  final CoachDocument document;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatar,
            height: AppSizes.avatar,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            ),
            child: Icon(
              document.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.workspace_premium_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
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
                Text(
                  document.sizeLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sertifika dışındaki belgeler. Profil ucu bunların içeriğini göndermediği
/// için önizleme yok; ad, tür ve tarih gösteriliyor.
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.cardPaddingCompact),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatar,
            height: AppSizes.avatar,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            ),
            child: Icon(
              document.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.description_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document.docName.trim().isEmpty
                      ? 'Belge #${document.id}'
                      : document.docName.trim(),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${document.typeLabel} · ${AppDate.short(document.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
