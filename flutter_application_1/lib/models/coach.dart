import '../core/json_utils.dart';

/// `models.CoachM` karşılığı — /coaches, /relations/myCoach.
class Coach {
  const Coach({
    required this.userId,
    required this.username,
    required this.email,
    required this.gender,
    required this.speciality,
    required this.maxStudents,
    required this.activeStudents,
    required this.status,
  });

  final int userId;
  final String username;
  final String email;
  final String gender;
  final String speciality;
  final int maxStudents;
  final int activeStudents;
  final String status;

  int get freeSlots => (maxStudents - activeStudents).clamp(0, maxStudents);

  bool get isFull => freeSlots <= 0;

  /// Koç adı boş gelirse (eski kayıtlar) id ile göster.
  String get displayName =>
      username.trim().isEmpty ? 'Koç #$userId' : username.trim();

  factory Coach.fromJson(Map<String, dynamic> json) {
    // /coaches ve /relations/myCoach models.CoachM (snake_case) döndürüyor;
    // /relations/pastCoaches ise ham entities.Coach döndürdüğü için kullanıcı
    // bilgileri iç içe `User` alanından okunur.
    final user = asMap(pick(json, ['User', 'user']));
    String fromUser(List<String> keys) =>
        user == null ? '' : asString(pick(user, keys));

    return Coach(
      userId: asInt(pick(json, ['user_id', 'UserID'])),
      username: asString(pick(json, ['username', 'Username'])).isNotEmpty
          ? asString(pick(json, ['username', 'Username']))
          : fromUser(['Username', 'username']),
      email: asString(pick(json, ['email', 'Email'])).isNotEmpty
          ? asString(pick(json, ['email', 'Email']))
          : fromUser(['Email', 'email']),
      gender: asString(pick(json, ['gender', 'Gender'])).isNotEmpty
          ? asString(pick(json, ['gender', 'Gender']))
          : fromUser(['Gender', 'gender']),
      speciality: asString(pick(json, ['speciality', 'Speciality'])),
      maxStudents: asInt(pick(json, ['max_students', 'MaxStudents'])),
      activeStudents: asInt(pick(json, ['active_students', 'ActiveStudents'])),
      status: asString(pick(json, ['status', 'Status'])),
    );
  }
}
