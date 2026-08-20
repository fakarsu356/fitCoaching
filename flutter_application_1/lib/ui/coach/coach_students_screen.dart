import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/relation.dart';
import '../../services/services.dart';
import '../widgets/common.dart';
import 'coach_student_detail_screen.dart';
import 'student_card.dart';

/// Koçun aktif öğrencileri.
///
/// İstekler ekranında bir istek onaylanınca liste kendiliğinden tazelensin
/// diye [relationsVersion] dinleniyor: kabuk sekmeleri [IndexedStack] içinde
/// tuttuğu için bu ekran arka planda canlı kalıyor ve tekrar açıldığında
/// `initState` çalışmıyor.
class CoachStudentsScreen extends StatefulWidget {
  const CoachStudentsScreen({super.key, required this.relationsVersion});

  final ValueListenable<int> relationsVersion;

  @override
  State<CoachStudentsScreen> createState() => _CoachStudentsScreenState();
}

class _CoachStudentsScreenState extends State<CoachStudentsScreen> {
  List<Student>? _students;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.relationsVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.relationsVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await context.read<AppServices>().relations.getMyStudents();

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _students = result.data ?? const <Student>[];
      } else {
        _error = result.errorMessage;
      }
    });
  }

  /// Öğrenci detayı program da yazdırabildiği için dönüşte liste tazeleniyor:
  /// yeni plan öğrenci kartındaki bilgiyi değiştirmese de detay ekranındaki
  /// kayıtlarla ekranın ayrışmaması için tek noktadan okunuyor.
  Future<void> _openDetail(Student student) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CoachStudentDetailScreen(student: student),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final count = _students?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrencilerim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: AsyncContent<List<Student>>(
        loading: _loading,
        error: _error,
        data: _students,
        onRetry: _load,
        builder: (students) {
          if (students.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Henüz öğrencin yok',
              description:
                  'Sana gelen bağlanma isteklerini "İstekler" sekmesinden '
                  'onayladığında öğrencilerin burada listelenir.',
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              // Başlık satırı da listenin bir parçası: ayrı bir kutu olsaydı
              // aşağı çekerek yenilemede sabit kalır, liste boşken de yer
              // kaplardı.
              itemCount: students.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSizes.gapSmall),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SectionTitle(
                    'Aktif öğrenciler',
                    subtitle: '$count kişi',
                  );
                }
                final student = students[index - 1];
                return StudentCard(
                  student: student,
                  onTap: () => _openDetail(student),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
