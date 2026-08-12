import '../core/json_utils.dart';

/// `entities.RequestStatus` değerleri.
class RelationStatus {
  const RelationStatus._();

  static const String waiting = 'waiting';
  static const String active = 'active';
  static const String rejected = 'rejected';
  static const String expired = 'expired';
  static const String breakup = 'breakup';

  static String label(String value) {
    switch (value) {
      case waiting:
        return 'Bekliyor';
      case active:
        return 'Aktif';
      case rejected:
        return 'Reddedildi';
      case expired:
        return 'Süresi doldu';
      case breakup:
        return 'Sona erdi';
      default:
        return value;
    }
  }
}

/// `entities.Relation` — json tag'i olmadığı için alanlar PascalCase gelir.
class Relation {
  const Relation({
    required this.id,
    required this.studentId,
    required this.coachId,
    required this.status,
    this.requestedTime,
    this.deletedTime,
    this.startedTime,
    this.endedTime,
  });

  final int id;
  final int studentId;
  final int coachId;
  final String status;
  final DateTime? requestedTime;

  /// İsteğin son geçerlilik tarihi (waiting durumunda) ya da cevaplanma tarihi.
  final DateTime? deletedTime;
  final DateTime? startedTime;
  final DateTime? endedTime;

  bool get isWaiting => status == RelationStatus.waiting;
  bool get isActive => status == RelationStatus.active;

  /// Bekleyen istek 24 saat sonra cron ile `expired` oluyor.
  bool get isExpired {
    if (!isWaiting || deletedTime == null) return false;
    return deletedTime!.isBefore(DateTime.now());
  }

  factory Relation.fromJson(Map<String, dynamic> json) {
    DateTime? date(List<String> keys) {
      final raw = pick(json, keys);
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString())?.toLocal();
    }

    return Relation(
      id: asInt(pick(json, ['ID', 'id'])),
      studentId: asInt(pick(json, ['StudentID', 'student_id'])),
      coachId: asInt(pick(json, ['CoachID', 'coach_id'])),
      status: asString(pick(json, ['Status', 'status'])),
      requestedTime: date(['RequestedTime', 'requested_time']),
      deletedTime: date(['DeletedTime', 'deleted_time']),
      startedTime: date(['StartedTime', 'started_time']),
      endedTime: date(['EndedTime', 'ended_time']),
    );
  }
}

/// `entities.Student` — koçun öğrenci listesinde dönen model.
class Student {
  const Student({
    required this.userId,
    required this.age,
    required this.bodyWeight,
    required this.fatPercentage,
    required this.bodyHeight,
    this.username = '',
  });

  final int userId;
  final int age;
  final double bodyWeight;
  final double fatPercentage;
  final double bodyHeight;
  final String username;

  String get displayName =>
      username.trim().isEmpty ? 'Öğrenci #$userId' : username.trim();

  /// Boy cm cinsinden geldiği için metreye çevrilir.
  double? get bmi {
    if (bodyHeight <= 0 || bodyWeight <= 0) return null;
    final meters = bodyHeight / 100;
    return bodyWeight / (meters * meters);
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    final user = asMap(pick(json, ['User', 'user']));
    return Student(
      userId: asInt(pick(json, ['UserID', 'user_id', 'StudentID', 'student_id'])),
      age: asInt(pick(json, ['Age', 'age'])),
      bodyWeight: asDouble(pick(json, ['BodyWeight', 'body_weight'])),
      fatPercentage: asDouble(pick(json, ['FatPercentage', 'fat_percentage'])),
      bodyHeight: asDouble(pick(json, ['BodyHeight', 'body_height'])),
      username: user == null
          ? ''
          : asString(pick(user, ['Username', 'username'])),
    );
  }
}
