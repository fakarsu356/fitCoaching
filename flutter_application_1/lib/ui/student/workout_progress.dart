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
    grouped
        .putIfAbsent(name.isEmpty ? unnamedMovement : name, () => [])
        .add(set);
  }
  for (final group in grouped.values) {
    group.sort((a, b) => a.setNumber.compareTo(b.setNumber));
  }
  return grouped;
}

/// Bir seansın bir önceki seansa göre tek cümlelik özeti.
///
/// Set bazındaki rozetler ([SetDiffBadges]) neyin ne kadar değiştiğini
/// gösteriyor ama "bu antrenman daha iyi miydi" sorusunu cevaplamak için
/// öğrencinin bütün satırları tek tek okuması gerekiyordu. Bu özet o soruyu
/// kartın en üstünde cevaplıyor.
class SessionComparison {
  const SessionComparison({
    required this.improved,
    required this.same,
    required this.dropped,
    required this.currentVolume,
    required this.previousVolume,
    required this.currentReps,
    required this.previousReps,
  });

  /// Önceki seansta karşılığı bulunan ve daha iyi/aynı/daha düşük olan set
  /// sayıları. Karşılığı olmayan setler (yeni hareket) hiçbirine sayılmaz.
  final int improved;
  final int same;
  final int dropped;

  /// Toplam hacim: her set için tekrar × ağırlık.
  final double currentVolume;
  final double previousVolume;

  /// Vücut ağırlığıyla yapılan setlerde hacim 0 kalıyor; o antrenmanlarda
  /// kıyas tekrar sayısı üzerinden kuruluyor.
  final int currentReps;
  final int previousReps;

  int get comparedSets => improved + same + dropped;

  bool get hasData => comparedSets > 0;

  /// Ağırlıklı bir antrenman mı, yoksa tamamen vücut ağırlığı mı?
  bool get usesWeight => currentVolume > 0 || previousVolume > 0;

  double get volumeDiff => currentVolume - previousVolume;

  int get repsDiff => currentReps - previousReps;

  /// Yüzde değişim; önceki seans sıfırsa (ilk kez ağırlık kullanıldıysa)
  /// oran anlamsız olacağı için null.
  double? get percent {
    final base = usesWeight ? previousVolume : previousReps.toDouble();
    if (base <= 0) return null;
    final diff = usesWeight ? volumeDiff : repsDiff.toDouble();
    return diff / base * 100;
  }

  /// Genel yön: 1 ilerleme, 0 aynı, -1 gerileme.
  ///
  /// Toplam yerine set sayısına bakılıyor: tek bir sette 20 kg artış, diğer
  /// altı sette düşüşü maskelememeli.
  int get direction {
    if (improved > dropped) return 1;
    if (dropped > improved) return -1;
    return 0;
  }

  /// [workout] setlerini [previousSets] içindeki karşılıklarıyla kıyaslar.
  factory SessionComparison.of(
    Workout workout,
    Map<String, WorkoutSet> previousSets,
  ) {
    var improved = 0;
    var same = 0;
    var dropped = 0;
    var currentVolume = 0.0;
    var previousVolume = 0.0;
    var currentReps = 0;
    var previousReps = 0;

    for (final set in workout.sets) {
      final before = previousSets[setKey(set.movementName, set.setNumber)];
      if (before == null) continue;

      currentVolume += set.reps * set.weight;
      previousVolume += before.reps * before.weight;
      currentReps += set.reps;
      previousReps += before.reps;

      switch (compareSet(set, before)) {
        case 1:
          improved++;
        case -1:
          dropped++;
        default:
          same++;
      }
    }

    return SessionComparison(
      improved: improved,
      same: same,
      dropped: dropped,
      currentVolume: currentVolume,
      previousVolume: previousVolume,
      currentReps: currentReps,
      previousReps: previousReps,
    );
  }
}

/// İki setin hangisinin daha iyi olduğu: 1 daha iyi, -1 daha kötü, 0 aynı.
///
/// Önce ağırlığa bakılır — aynı ağırlıkta daha çok tekrar da ilerlemedir ama
/// daha ağır kaldırmak her zaman önce gelir.
int compareSet(WorkoutSet now, WorkoutSet before) {
  if (now.weight != before.weight) return now.weight > before.weight ? 1 : -1;
  if (now.reps != before.reps) return now.reps > before.reps ? 1 : -1;
  return 0;
}

/// Seans kartının üstündeki tek bakışta özet şeridi.
///
/// Kıyas kurulamıyorsa (programın ilk seansı) hiçbir şey çizilmez; "veri yok"
/// yazmak kartı kalabalıklaştırmaktan başka işe yaramıyor.
class SessionProgressBanner extends StatelessWidget {
  const SessionProgressBanner({super.key, required this.comparison});

  final SessionComparison comparison;

  @override
  Widget build(BuildContext context) {
    if (!comparison.hasData) return const SizedBox.shrink();

    final direction = comparison.direction;
    final (color, background, icon, title) = switch (direction) {
      1 => (
        AppColors.success,
        AppColors.successSoft,
        Icons.trending_up,
        'Geçen seansa göre ilerledin',
      ),
      -1 => (
        AppColors.danger,
        AppColors.dangerSoft,
        Icons.trending_down,
        'Geçen seansın altında kaldın',
      ),
      _ => (
        AppColors.textSecondary,
        AppColors.surfaceMuted,
        Icons.trending_flat,
        'Geçen seansla aynı',
      ),
    };

    return Container(
      margin: const EdgeInsets.only(top: AppSizes.gapSmall),
      padding: const EdgeInsets.all(AppSizes.gapSmall),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _totalLine(comparison),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _setLine(comparison),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Toplam 2.400 → 2.640 kg (+%10)" — vücut ağırlığı antrenmanlarında
  /// aynı cümle tekrar sayısıyla kurulur.
  static String _totalLine(SessionComparison c) {
    // Yüzde tam sayıya yuvarlanıyor: "+11%" okunur, "+10,98%" değil.
    final percent = c.percent?.roundToDouble();
    final suffix = percent == null || percent == 0
        ? ''
        : ' (${formatSignedNumber(percent)}%)';

    if (c.usesWeight) {
      return 'Toplam kaldırdığın: ${formatNumber(c.previousVolume)} kg → '
          '${formatNumber(c.currentVolume)} kg$suffix';
    }
    return 'Toplam tekrar: ${c.previousReps} → ${c.currentReps}$suffix';
  }

  /// "6 sette arttı · 2 set aynı" — sıfır olan kısımlar yazılmaz.
  static String _setLine(SessionComparison c) {
    final parts = [
      if (c.improved > 0) '${c.improved} sette arttı',
      if (c.same > 0) '${c.same} set aynı',
      if (c.dropped > 0) '${c.dropped} sette düştü',
    ];
    return parts.join(' · ');
  }
}
