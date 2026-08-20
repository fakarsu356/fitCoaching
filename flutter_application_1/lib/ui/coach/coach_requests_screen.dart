import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_result.dart';
import '../../core/date_fmt.dart';
import '../../core/theme.dart';
import '../../models/relation.dart';
import '../../services/relation_service.dart';
import '../../services/services.dart';
import '../widgets/common.dart';

/// Koça gelen bağlanma istekleri; buradan onaylanır ya da reddedilir.
///
/// Uç `student_name` de döndürüyor; adı boş gelen eski kayıtlarda kart
/// "Öğrenci #id"ye düşer ([Relation.studentLabel]).
class CoachRequestsScreen extends StatefulWidget {
  const CoachRequestsScreen({super.key, required this.relationsVersion});

  /// Bir istek cevaplanınca artırılır; öğrenci listesi bunu dinleyip tazelenir.
  final ValueNotifier<int> relationsVersion;

  @override
  State<CoachRequestsScreen> createState() => _CoachRequestsScreenState();
}

class _CoachRequestsScreenState extends State<CoachRequestsScreen> {
  List<Relation>? _requests;
  String? _error;
  bool _loading = true;

  /// İşlem gören isteğin öğrenci kimliği — sadece o kartın butonları kilitlenir,
  /// diğer istekler cevaplanabilir kalır.
  int? _busyStudentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await context
        .read<AppServices>()
        .relations
        .getPendingRequests();

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _requests = result.data ?? const <Relation>[];
      } else {
        _error = result.errorMessage;
      }
    });
  }

  Future<void> _accept(Relation request) async {
    final confirmed = await confirmDialog(
      context,
      title: 'İsteği onayla',
      message:
          '${_studentLabel(request)} öğrencin olacak ve program yazabileceksin. '
          'Devam edilsin mi?',
      confirmLabel: 'Onayla',
    );
    if (!confirmed || !mounted) return;

    await _respond(
      request,
      action: (relations) => relations.acceptRequest(request.studentId),
      successMessage: 'İstek onaylandı',
    );
  }

  Future<void> _reject(Relation request) async {
    final confirmed = await confirmDialog(
      context,
      title: 'İsteği reddet',
      message: '${_studentLabel(request)} isteği reddedilecek.',
      confirmLabel: 'Reddet',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await _respond(
      request,
      action: (relations) => relations.rejectRequest(request.studentId),
      successMessage: 'İstek reddedildi',
    );
  }

  Future<void> _respond(
    Relation request, {
    required Future<ApiResult<void>> Function(RelationService relations) action,
    required String successMessage,
  }) async {
    setState(() => _busyStudentId = request.studentId);

    final result = await action(context.read<AppServices>().relations);

    if (!mounted) return;
    setState(() => _busyStudentId = null);

    if (!result.ok) {
      showAppSnack(context, result.errorMessage, isError: true);
      return;
    }

    showAppSnack(context, successMessage);
    // Onay öğrenci listesini de değiştirir; ret sonrası da liste yeniden
    // okunsun ki sunucudaki durumla ayrışma olmasın.
    widget.relationsVersion.value++;
    await _load();
  }

  String _studentLabel(Relation request) => request.studentLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İstekler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: AsyncContent<List<Relation>>(
        loading: _loading,
        error: _error,
        data: _requests,
        onRetry: _load,
        builder: (requests) {
          if (requests.isEmpty) {
            return const EmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'Bekleyen istek yok',
              description:
                  'Öğrenciler sana bağlanma isteği gönderdiğinde burada '
                  'görünür. Cevaplanmayan istekler 24 saat sonra düşer.',
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              itemCount: requests.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSizes.gapSmall),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SectionTitle(
                    'Bekleyen istekler',
                    subtitle: '${requests.length} istek',
                  );
                }
                final request = requests[index - 1];
                return _RequestCard(
                  request: request,
                  label: _studentLabel(request),
                  busy: _busyStudentId == request.studentId,
                  // Başka bir istek işlenirken bu kartın butonları da kapanır:
                  // arka arkaya gönderilen iki cevap listeyi karıştırırdı.
                  enabled: _busyStudentId == null,
                  onAccept: () => _accept(request),
                  onReject: () => _reject(request),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onAccept,
    required this.onReject,
  });

  final Relation request;
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.avatar,
                height: AppSizes.avatar,
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_outlined,
                  color: AppColors.info,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppDate.relative(request.requestedTime),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill.warning(RelationStatus.label(request.status)),
            ],
          ),
          if (request.deletedTime != null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            InfoRow('Son geçerlilik', AppDate.long(request.deletedTime)),
          ],
          const SizedBox(height: AppSizes.gap),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? onReject : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('Reddet'),
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: ElevatedButton(
                  onPressed: enabled ? onAccept : null,
                  // Yükseklik butonun kendi temasından gelir; gösterge de o
                  // yüksekliğe oturur ki basınca kart zıplamasın.
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Onayla'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
