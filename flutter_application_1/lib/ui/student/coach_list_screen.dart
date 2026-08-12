import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/coach.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'coach_card.dart';

/// Koç listesi ekranının çıkışı.
///
/// Öğrenci aynı anda yalnızca bir istek gönderebildiği için, sunucu "zaten bir
/// isteğin var" dediğinde de bekleme durumuna geçmek gerekiyor: uygulama
/// yeniden açıldığında bekleyen istek bilgisi kaybolduğundan, bu cevap o
/// durumu geri kazanmanın tek yolu.
enum CoachRequestResult {
  /// İstek bu ekrandan gönderildi.
  sent,

  /// Sunucuda zaten bekleyen bir istek varmış.
  alreadyPending,

  /// Öğrencinin aktif koçu varmış; koç ekranı yenilenmeli.
  hasCoach,
}

/// Kontenjanı uygun koçları listeler, seçilen koça bağlanma isteği gönderir.
class CoachListScreen extends StatefulWidget {
  const CoachListScreen({super.key});

  @override
  State<CoachListScreen> createState() => _CoachListScreenState();
}

class _CoachListScreenState extends State<CoachListScreen> {
  List<Coach>? _coaches;
  String? _error;
  bool _loading = true;
  bool _sending = false;

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

    final result = await context.read<AppServices>().relations
        .getAvailableCoaches();

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        // Backend kontenjanı dolmayanları döndürüyor; yine de elenir.
        _coaches = (result.data ?? const <Coach>[])
            .where((coach) => !coach.isFull)
            .toList();
      } else {
        _error = result.errorMessage;
      }
    });
  }

  Future<void> _sendRequest(Coach coach) async {
    final confirmed = await confirmDialog(
      context,
      title: 'İstek gönder',
      message:
          '${coach.displayName} adlı koça bağlanma isteği gönderilecek. '
          'Aynı anda yalnızca bir isteğin olabilir.',
      confirmLabel: 'Gönder',
    );
    if (!confirmed || !mounted) return;

    setState(() => _sending = true);
    final result = await context.read<AppServices>().relations.sendRequest(
      coach.userId,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (!result.ok) {
      final outcome = _outcomeFromError(result.errorMessage);
      if (outcome == null) {
        showAppSnack(context, result.errorMessage, isError: true);
        return;
      }
      Navigator.of(context).pop(outcome);
      return;
    }
    Navigator.of(context).pop(CoachRequestResult.sent);
  }

  /// Sunucunun "tek istek" kuralına takılan cevaplarını ayırt eder; diğer
  /// hatalar (kapasite doldu vb.) listede bildirim olarak gösterilir.
  CoachRequestResult? _outcomeFromError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('isteğin var')) return CoachRequestResult.alreadyPending;
    if (lower.contains('have a coach')) return CoachRequestResult.hasCoach;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koç bul'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: AsyncContent<List<Coach>>(
        loading: _loading,
        error: _error,
        data: _coaches,
        onRetry: _load,
        builder: (coaches) {
          if (coaches.isEmpty) {
            return const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'Şu an uygun koç yok',
              description:
                  'Kontenjanı dolmamış koçlar burada listelenir. '
                  'Daha sonra tekrar bak.',
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              itemCount: coaches.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSizes.gapSmall),
              itemBuilder: (context, index) {
                final coach = coaches[index];
                return CoachCard(
                  coach: coach,
                  compact: true,
                  onTap: _sending ? null : () => _sendRequest(coach),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
