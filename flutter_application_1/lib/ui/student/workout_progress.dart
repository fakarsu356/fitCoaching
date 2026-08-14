import 'package:flutter/material.dart';

import '../../core/num_fmt.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';

/// Bir setin kimliği: hareket adı + set numarası. Kıyas bu anahtarla kurulur,
/// böylece "3. set bench press" hep kendi geçmişiyle eşleşir.
String setKey(String movementName, int setNumber) {
  return '${movementName.trim().toLowerCase()}|$setNumber';
}

/// Aynı programın seansları arasında set bazında kıyas kurar.
///
/// Program kimliği [Workout.programId]. Bir önceki antrenman farklı bir program
/// olabileceği için karşılaştırma asla "son yapılan antrenman" ile yapılmaz;
/// aynı programın bir önceki seansı aranır.
class WorkoutProgress {
  const WorkoutProgress(this.sessions);

  /// Öğrencinin yaptığı antrenmanlar, yeniden eskiye sıralı.
  final List<Workout> sessions;

  /// [workout] içindeki her set için önceki seanstaki karşılığı.
  ///
  /// Anahtarlar [setKey] biçimindedir. Bekleyen bir plan da verilebilir; o
  /// durumda aynı programın en güncel seansıyla kıyaslanır.
  Map<String, WorkoutSet> previousSetsFor(Workout workout) {
    final result = <String, WorkoutSet>{};
    final wanted = {
      for (final set in workout.sets) setKey(set.movementName, set.setNumber),
    };
    if (wanted.isEmpty) return result;

    final group = [
      for (final session in sessions)
        if (session.programId == workout.programId) session,
    ];
    // Plan henüz yapılmadığı için listede olmayabilir; indexWhere -1 dönünce
    // sublist(0) ile grubun tamamı (en güncel seans başta) taranır.
    final index = group.indexWhere((session) => session.id == workout.id);
    final earlier = group.sublist(index + 1);

    if (earlier.isNotEmpty) {
      for (final session in earlier) {
        _collect(session, wanted, result);
        if (result.length == wanted.length) break;
      }
      // Programın geçmişi varsa eşleşmeyen hareket gerçekten yeni demektir;
      // başka bir programın sayısını yanına yazmıyoruz.
      return result;
    }

    // Bu program ilk kez yapılıyor: hareketin geçtiği en son seansa düşülür.
    for (final session in sessions) {
      if (session.id == workout.id || !_isBefore(session, workout)) continue;
      _collect(session, wanted, result);
      if (result.length == wanted.length) break;
    }
    return result;
  }

  void _collect(
    Workout session,
    Set<String> wanted,
    Map<String, WorkoutSet> into,
  ) {
    for (final set in session.sets) {
      final key = setKey(set.movementName, set.setNumber);
      if (!wanted.contains(key)) continue;
      into.putIfAbsent(key, () => set);
    }
  }

  bool _isBefore(Workout a, Workout b) {
    final aDate = a.date;
    final bDate = b.date;
    if (aDate == null || bDate == null) return false;
    return aDate.isBefore(bDate);
  }
}

/// Bir setin önceki seansa göre ağırlık ve tekrar farkını gösterir.
///
/// Toplam hacim gibi tek bir sayı yerine set bazında fark veriliyor; gelişim
/// asıl burada görünüyor.
class SetDiffBadges extends StatelessWidget {
  const SetDiffBadges({
    super.key,
    required this.weight,
    required this.reps,
    required this.previous,
  });

  final double weight;
  final int reps;

  /// Önceki seanstaki aynı set; yoksa hiçbir şey çizilmez.
  final WorkoutSet? previous;

  @override
  Widget build(BuildContext context) {
    final before = previous;
    if (before == null) return const SizedBox.shrink();

    final weightDiff = weight - before.weight;
    final repsDiff = reps - before.reps;

    if (weightDiff == 0 && repsDiff == 0) {
      return const _DiffBadge(
        label: 'aynı',
        color: AppColors.textSecondary,
        background: AppColors.surfaceMuted,
        icon: Icons.drag_handle,
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        if (weightDiff != 0)
          _DiffBadge(
            label: '${formatSignedNumber(weightDiff)} kg',
            color: weightDiff > 0 ? AppColors.success : AppColors.danger,
            background: weightDiff > 0
                ? AppColors.successSoft
                : AppColors.dangerSoft,
            icon: weightDiff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
          ),
        if (repsDiff != 0)
          _DiffBadge(
            label: '${formatSignedNumber(repsDiff.toDouble())} tekrar',
            color: repsDiff > 0 ? AppColors.success : AppColors.danger,
            background: repsDiff > 0
                ? AppColors.successSoft
                : AppColors.dangerSoft,
            icon: repsDiff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
          ),
      ],
    );
  }
}

class _DiffBadge extends StatelessWidget {
  const _DiffBadge({
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.radiusTiny),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir setin "10 tekrar × 40 kg" biçimindeki okunur hâli.
String setLine(WorkoutSet set) {
  return '${set.reps} tekrar × ${formatNumber(set.weight)} kg';
}

/// Kıyas satırlarında kullanılan kısa hâli: "10 × 40 kg".
String setLineShort(WorkoutSet set) {
  return '${set.reps} × ${formatNumber(set.weight)} kg';
}

/// Adı boş kaydedilmiş setlerin başlığı.
///
/// Böyle setler listeden atılırsa antrenman "0 hareket" görünür ve sorunun
/// setlerde olduğu ekrandan anlaşılmaz; bu yüzden gizlenmiyorlar.
const String unnamedMovement = 'Hareket adı yok';

/// Setleri hareket adına göre gruplar; her grup set numarasına göre sıralanır.
/// Ekleme sırası korunur, yani hareketler koçun yazdığı sırayla kalır.
Map<String, List<WorkoutSet>> groupByMovement(List<WorkoutSet> sets) {
  final grouped = <String, List<WorkoutSet>>{};
  for (final set in sets) {
    final name = set.movementName.trim();
    grouped.putIfAbsent(name.isEmpty ? unnamedMovement : name, () => []).add(set);
  }
  for (final group in grouped.values) {
    group.sort((a, b) => a.setNumber.compareTo(b.setNumber));
  }
  return grouped;
}
