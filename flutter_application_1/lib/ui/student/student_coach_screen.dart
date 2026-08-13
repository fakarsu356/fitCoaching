import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_fmt.dart';
import '../../core/theme.dart';
import '../../models/coach.dart';
import '../../models/relation.dart';
import '../../services/services.dart';
import '../../state/auth_controller.dart';
import '../widgets/common.dart';
import 'coach_card.dart';
import 'coach_list_screen.dart';
import 'coach_profile_screen.dart';
import 'rate_coach_sheet.dart';

/// Öğrencinin koç durumu: aktif koçu varsa koç kartı ve ayrılma; yoksa koç
/// arama daveti ve varsa eski koçu için puanlama kartı.
class StudentCoachScreen extends StatefulWidget {
  const StudentCoachScreen({super.key});

  @override
  State<StudentCoachScreen> createState() => _StudentCoachScreenState();
}

class _StudentCoachScreenState extends State<StudentCoachScreen> {
  Coach? _coach;
  Coach? _pastCoach;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// Koçun henüz cevaplamadığı istek. Açılışta sunucudan okunur, istek
  /// gönderildiğinde de işaretlenir.
  Relation? _pendingRequest;
  bool _requestSent = false;

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

    final relations = context.read<AppServices>().relations;
    final coachResult = await relations.getMyCoach();
    final pastResult = await relations.getPastCoach();
    final requestResult = await relations.getMyRequest();

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!coachResult.ok) {
        _error = coachResult.errorMessage;
        return;
      }
      _coach = coachResult.data;
      _pastCoach = pastResult.data;
      _pendingRequest = requestResult.data;
      _requestSent = _pendingRequest?.isWaiting ?? false;
      // Koç isteği kabul etmişse bekleme bilgisi anlamını yitirir.
      if (_coach != null) {
        _requestSent = false;
        _pendingRequest = null;
      }
    });
  }

  Future<void> _findCoach() async {
    final result = await Navigator.of(context).push<CoachRequestResult>(
      MaterialPageRoute<CoachRequestResult>(
        builder: (_) => const CoachListScreen(),
      ),
    );
    if (result == null || !mounted) return;

    switch (result) {
      case CoachRequestResult.sent:
        setState(() => _requestSent = true);
        showAppSnack(context, 'İsteğin gönderildi, koçun onayını bekliyorsun');
      case CoachRequestResult.alreadyPending:
        setState(() => _requestSent = true);
        showAppSnack(
          context,
          'Bekleyen bir isteğin zaten var, önce onun cevaplanmasını bekle',
        );
      case CoachRequestResult.hasCoach:
        await _load();
    }
  }

  Future<void> _leaveCoach(Coach coach) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Koçtan ayrıl',
      message:
          '${coach.displayName} ile çalışmayı bitiriyorsun. Ayrıldıktan sonra '
          'koçuna puan verebilir, yeni bir koça istek gönderebilirsin.',
      confirmLabel: 'Ayrıl',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final result = await context.read<AppServices>().relations.leaveCoach(
      coach.userId,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.ok) {
      showAppSnack(context, result.errorMessage, isError: true);
      return;
    }
    await _load();
    if (mounted) showAppSnack(context, 'Koçundan ayrıldın');
  }

  /// Koçun puanı ve sertifikaları yalnızca profil ucunda döndüğü için kart
  /// ayrıntıları göstermiyor; profil ekranına geçiliyor.
  Future<void> _openProfile(Coach coach) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => CoachProfileScreen(coach: coach)),
    );
  }

  Future<void> _rate(Coach coach) async {
    final saved = await showRateCoachSheet(context, coach);
    if (!saved || !mounted) return;
    showAppSnack(context, 'Değerlendirmen kaydedildi');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koçum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış yap',
            onPressed: () async {
              final confirmed = await confirmDialog(
                context,
                title: 'Çıkış yap',
                message: 'Oturumun kapatılacak. Devam edilsin mi?',
                confirmLabel: 'Çıkış yap',
                destructive: true,
              );
              if (confirmed && context.mounted) {
                await context.read<AuthController>().signOut();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.pagePadding),
                children: [
                  if (_coach != null)
                    _ActiveCoach(
                      coach: _coach!,
                      busy: _busy,
                      onLeave: () => _leaveCoach(_coach!),
                      onOpenProfile: () => _openProfile(_coach!),
                    )
                  else
                    _NoCoach(
                      requestSent: _requestSent,
                      pendingRequest: _pendingRequest,
                      onFindCoach: _findCoach,
                    ),
                  if (_coach == null && _pastCoach != null) ...[
                    const SizedBox(height: AppSizes.gapLarge),
                    _PastCoach(
                      coach: _pastCoach!,
                      onRate: () => _rate(_pastCoach!),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ActiveCoach extends StatelessWidget {
  const _ActiveCoach({
    required this.coach,
    required this.busy,
    required this.onLeave,
    required this.onOpenProfile,
  });

  final Coach coach;
  final bool busy;
  final VoidCallback onLeave;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Çalıştığın koç',
          subtitle: 'Antrenman programını bu koç yazıyor.',
        ),
        CoachCard(
          coach: coach,
          showContact: true,
          onTap: onOpenProfile,
          action: OutlinedButton(
            onPressed: busy ? null : onLeave,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.borderStrong),
            ),
            child: const Text('Koçtan ayrıl'),
          ),
        ),
      ],
    );
  }
}

class _NoCoach extends StatelessWidget {
  const _NoCoach({
    required this.requestSent,
    required this.onFindCoach,
    this.pendingRequest,
  });

  final bool requestSent;
  final Relation? pendingRequest;
  final VoidCallback onFindCoach;

  /// Uç ilişkinin tamamını döndürdüğünde isteğin ne zaman düşeceği yazılır.
  String? get _remaining {
    final deadline = pendingRequest?.deletedTime;
    if (deadline == null || deadline.isBefore(DateTime.now())) return null;
    return AppDate.duration(DateTime.now(), deadline);
  }

  @override
  Widget build(BuildContext context) {
    if (requestSent) {
      final remaining = _remaining;
      return AppCard(
        borderColor: AppColors.warning.withValues(alpha: 0.35),
        background: AppColors.warningSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.hourglass_top_outlined,
                  size: 20,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'İsteğin bekliyor',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              'Koç isteğini kabul ettiğinde burada görünecek. Aynı anda tek '
              'isteğin olabilir; cevaplanmayan istekler 24 saat sonra düşer ve '
              'başka bir koça istek gönderebilirsin.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (remaining != null) ...[
              const SizedBox(height: AppSizes.gapSmall),
              Text(
                'Kalan süre: $remaining',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.gapLarge),
      child: EmptyState(
        icon: Icons.person_search_outlined,
        title: 'Henüz bir koçun yok',
        description:
            'Sana uygun bir koç seç ve istek gönder. Koç kabul ettiğinde '
            'antrenman programın gelmeye başlar.',
        action: SizedBox(
          width: 220,
          child: ElevatedButton(
            onPressed: onFindCoach,
            child: const Text('Koç bul'),
          ),
        ),
      ),
    );
  }
}

class _PastCoach extends StatelessWidget {
  const _PastCoach({required this.coach, required this.onRate});

  final Coach coach;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Eski koçun'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                coach.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Birlikte çalıştığınız süreci değerlendirerek diğer '
                'öğrencilere yardımcı olabilirsin.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSizes.gap),
              OutlinedButton(
                onPressed: onRate,
                child: const Text('Puan ver'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
