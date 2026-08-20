import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_result.dart';
import '../core/date_fmt.dart';
import '../core/json_utils.dart';
import '../models/tracking.dart';
import 'auth_service.dart' show UploadFile;

/// Öğün kayıtları.
class MealService {
  MealService(this._client);

  final ApiClient _client;

  /// POST /meal/addMeal
  Future<ApiResult<void>> addMeal({
    required String mealName,
    required String description,
    required double kcal,
    required double protein,
    required double oil,
    required double karb,
    required double lif,
  }) async {
    final result = await _client.post(
      '/meal/addMeal',
      body: {
        'meal_name': mealName,
        'description': description,
        'kcal': kcal,
        'protein': protein,
        'oil': oil,
        'karb': karb,
        'lif': lif,
      },
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /meal/getMeals — aralıktaki öğünler. Koç rolünde [studentId] zorunlu.
  Future<ApiResult<List<Meal>>> getMeals({
    required DateTime start,
    required DateTime end,
    int? studentId,
  }) async {
    final result = await _client.post(
      '/meal/getMeals',
      body: {
        'start_date': AppDate.dayStart(start),
        'end_date': AppDate.dayEnd(end),
        'student_id': ?studentId,
      },
    );
    if (!result.ok) return ApiResult.failure<List<Meal>>(result.message);
    return ApiResult.success<List<Meal>>(
      asMapList(result.data).map(Meal.fromJson).toList(),
    );
  }

  /// POST /meal/dailyMeals — bir günün kcal/protein/yağ toplamı.
  ///
  /// Backend tarihin geçmişte olmasını şart koşuyor; bugünün toplamı için
  /// gün başlangıcı gönderilir.
  Future<ApiResult<MealSummary>> getDailySummary({
    required DateTime day,
    int? studentId,
  }) async {
    final result = await _client.post(
      '/meal/dailyMeals',
      body: {
        'start_date': AppDate.dayStart(day),
        'student_id': ?studentId,
      },
    );
    if (!result.ok) return ApiResult.failure<MealSummary>(result.message);

    // Uç, düzeltme öncesi `{"meals": {...}}` biçiminde de dönebiliyor.
    final raw = asMap(result.data);
    final map = raw == null ? null : (asMap(raw['meals']) ?? raw);
    return ApiResult.success<MealSummary>(
      map == null ? MealSummary.empty : MealSummary.fromJson(map),
    );
  }

  /// POST /meal/deleteMeal
  Future<ApiResult<void>> deleteMeal(int mealId) async {
    final result = await _client.post(
      '/meal/deleteMeal',
      body: {'meal_id': mealId},
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }
}

/// Uyku kayıtları.
class SleepService {
  SleepService(this._client);

  final ApiClient _client;

  /// POST /sleep/addSleep
  Future<ApiResult<void>> addSleep({
    required DateTime bedTime,
    required DateTime wakeTime,
  }) async {
    final result = await _client.post(
      '/sleep/addSleep',
      body: {
        'bed_time': AppDate.toApi(bedTime),
        'wake_time': AppDate.toApi(wakeTime),
      },
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /sleep/getSleep — koç rolünde [studentId] zorunlu.
  Future<ApiResult<List<Sleep>>> getSleepRecords({int? studentId}) async {
    final result = await _client.post(
      '/sleep/getSleep',
      body: {'student_id': ?studentId},
      dataKey: 'sleep',
    );
    if (!result.ok) return ApiResult.failure<List<Sleep>>(result.message);

    final records = asMapList(result.data).map(Sleep.fromJson).toList()
      ..sort((a, b) {
        final aDate = a.bedTime ?? DateTime(1970);
        final bDate = b.bedTime ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    return ApiResult.success<List<Sleep>>(records);
  }
}

/// Puanlama.
class RatingService {
  RatingService(this._client);

  final ApiClient _client;

  /// POST /rate/addRating — sadece ilişki `breakup` durumundayken.
  Future<ApiResult<void>> addRating({
    required int coachId,
    required int score,
    required String description,
  }) async {
    final result = await _client.post(
      '/rate/addRating',
      body: {
        'coach_id': coachId,
        'rate': score,
        'description': description,
      },
      dataKey: 'rating',
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }
}

/// Belgeler (tahlil, gelişim/öğün fotoğrafı).
class DocumentService {
  DocumentService(this._client);

  final ApiClient _client;

  /// POST /document/addDocuments — multipart, `files` + `type`.
  Future<ApiResult<void>> upload({
    required List<UploadFile> files,
    required String type,
  }) async {
    final multipartFiles = <MultipartFile>[];
    for (final file in files) {
      multipartFiles.add(await file.toMultipart());
    }

    final result = await _client.postMultipart(
      '/document/addDocuments',
      fields: {'type': type},
      files: multipartFiles,
    );
    return ApiResult<void>(ok: result.ok, message: result.message);
  }

  /// POST /document/getDocumentList — [studentId] verilmezse kendi belgeleri,
  /// koç rolünde verilirse o öğrencinin belgeleri döner.
  Future<ApiResult<List<DocumentItem>>> getList({int? studentId}) async {
    final result = await _client.post(
      '/document/getDocumentList',
      body: {'student_id': ?studentId},
    );
    if (!result.ok) {
      return ApiResult.failure<List<DocumentItem>>(result.message);
    }
    final items = asMapList(result.data).map(DocumentItem.fromJson).toList()
      ..sort((a, b) {
        final aDate = a.date ?? DateTime(1970);
        final bDate = b.date ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    return ApiResult.success<List<DocumentItem>>(items);
  }

  /// POST /document/getDocument — şifresi çözülmüş dosya içeriği.
  /// Go `[]byte`'ı base64 string olarak serialize eder.
  Future<ApiResult<List<int>>> download(int fileId) async {
    final result = await _client.post(
      '/document/getDocument',
      body: {'file_id': fileId},
    );
    if (!result.ok) return ApiResult.failure<List<int>>(result.message);

    final data = result.data;
    if (data is String && data.isNotEmpty) {
      try {
        return ApiResult.success<List<int>>(base64Decode(data));
      } catch (_) {
        return ApiResult.failure<List<int>>('Dosya çözümlenemedi');
      }
    }
    if (data is List) {
      return ApiResult.success<List<int>>(data.map((e) => asInt(e)).toList());
    }
    return ApiResult.failure<List<int>>('Dosya içeriği boş döndü');
  }
}
