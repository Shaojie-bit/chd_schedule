import 'package:dio/dio.dart';
import '../models/announcement.dart';
import '../models/student.dart';
import 'storage_service.dart';

class TelemetryService {
  final StorageService storageService;
  late final Dio _dio;

  TelemetryService(this.storageService) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
      ),
    );
  }

  String get _baseUrl {
    var url = storageService.serverUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// 静默上报活跃心跳与学籍档案统计（异步无阻塞、完全容错）
  Future<void> reportHeartbeat(StudentProfile? profile, {String action = 'startup'}) async {
    if (profile == null || profile.studentId.isEmpty) return;
    try {
      final payload = {
        'student_id': profile.studentId,
        'name': profile.name,
        'college': profile.department,
        'major': profile.major,
        'grade': profile.grade,
        'campus': profile.campus,
        'app_version': '1.0.0',
        'device_id': storageService.deviceUuid,
        'action': action,
      };

      await _dio.post(
        '$_baseUrl/api/telemetry/report',
        data: payload,
        options: Options(contentType: Headers.jsonContentType),
      );
    } catch (_) {
      // 容错忽略，确保云端服务不可用时不影响本地课表任何功能
    }
  }

  /// 获取最新公告
  Future<Announcement?> getLatestAnnouncement() async {
    try {
      final res = await _dio.get('$_baseUrl/api/announcements/latest');
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map<String, dynamic>;
        if (data['has_announcement'] == true && data['data'] != null) {
          return Announcement.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  /// 获取全部历史公告
  Future<List<Announcement>> getAllAnnouncements() async {
    try {
      final res = await _dio.get('$_baseUrl/api/announcements');
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map<String, dynamic>;
        final list = data['data'] as List<dynamic>? ?? [];
        return list
            .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
