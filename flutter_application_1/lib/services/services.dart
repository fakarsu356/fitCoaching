import '../core/api_client.dart';
import 'auth_service.dart';
import 'relation_service.dart';
import 'tracking_service.dart';
import 'workout_service.dart';

/// Tüm servisleri tek yerde toplayan basit kap.
/// Ekranlar `context.read<AppServices>()` ile erişir.
class AppServices {
  AppServices(this.client)
    : auth = AuthService(client),
      relations = RelationService(client),
      workouts = WorkoutService(client),
      meals = MealService(client),
      sleep = SleepService(client),
      ratings = RatingService(client),
      documents = DocumentService(client);

  final ApiClient client;
  final AuthService auth;
  final RelationService relations;
  final WorkoutService workouts;
  final MealService meals;
  final SleepService sleep;
  final RatingService ratings;
  final DocumentService documents;
}
