import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import '../models/grade.dart';
import '../models/student.dart';

class StorageService {
  static const _keyUser = 'chd_cached_user';
  static const _keySemesters = 'chd_cached_semesters';
  static const _keyCurrentSemester = 'chd_current_semester_id';
  static const _keyCourses = 'chd_cached_courses';
  static const _keyGrades = 'chd_cached_grades';
  static const _keySavedUsername = 'chd_saved_username';
  static const _keySavedPassword = 'chd_saved_password';
  static const _keyRememberMe = 'chd_remember_me';
  static const _keyServerUrl = 'chd_server_url';
  static const _keyDeviceUuid = 'chd_device_uuid';
  static const _keyLastReadAnnId = 'chd_last_read_ann_id';

  final SharedPreferences prefs;

  StorageService(this.prefs);

  static Future<StorageService> init() async {
    final sp = await SharedPreferences.getInstance();
    return StorageService(sp);
  }

  // 云端服务配置（默认连接用户的云端后端 20.200.219.153:2543）
  String get serverUrl => prefs.getString(_keyServerUrl) ?? 'http://20.200.219.153:2543';
  Future<void> saveServerUrl(String url) async => await prefs.setString(_keyServerUrl, url.trim());

  String get deviceUuid {
    var id = prefs.getString(_keyDeviceUuid);
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      prefs.setString(_keyDeviceUuid, id);
    }
    return id;
  }

  int get lastReadAnnouncementId => prefs.getInt(_keyLastReadAnnId) ?? 0;
  Future<void> saveLastReadAnnouncementId(int id) async => await prefs.setInt(_keyLastReadAnnId, id);

  // 凭据记住与自动填充
  bool get rememberMe => prefs.getBool(_keyRememberMe) ?? true;
  set rememberMe(bool val) => prefs.setBool(_keyRememberMe, val);

  String get savedUsername => prefs.getString(_keySavedUsername) ?? '';
  String get savedPassword => prefs.getString(_keySavedPassword) ?? '';

  Future<void> saveCredentials(String username, String password) async {
    await prefs.setString(_keySavedUsername, username);
    await prefs.setString(_keySavedPassword, password);
  }

  Future<void> clearCredentials() async {
    await prefs.remove(_keySavedUsername);
    await prefs.remove(_keySavedPassword);
  }

  // 学生个人档案
  StudentProfile? getCachedUser() {
    final str = prefs.getString(_keyUser);
    if (str == null) return null;
    try {
      return StudentProfile.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(StudentProfile user) async {
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  // 学期列表
  List<SemesterInfo> getCachedSemesters() {
    final str = prefs.getString(_keySemesters);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list
          .map((e) => SemesterInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSemesters(List<SemesterInfo> sems) async {
    await prefs.setString(
      _keySemesters,
      jsonEncode(sems.map((e) => e.toJson()).toList()),
    );
  }

  String getCurrentSemesterId() =>
      prefs.getString(_keyCurrentSemester) ?? '262';

  Future<void> saveCurrentSemesterId(String semId) async {
    await prefs.setString(_keyCurrentSemester, semId);
  }

  // 课表缓存
  List<Course> getCachedCourses(String semesterId) {
    final str = prefs.getString('${_keyCourses}_$semesterId');
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCourses(String semesterId, List<Course> courses) async {
    await prefs.setString(
      '${_keyCourses}_$semesterId',
      jsonEncode(courses.map((e) => e.toJson()).toList()),
    );
  }

  // 成绩缓存
  GradesData? getCachedGrades() {
    final str = prefs.getString(_keyGrades);
    if (str == null) return null;
    try {
      return GradesData.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGrades(GradesData data) async {
    await prefs.setString(_keyGrades, jsonEncode(data.toJson()));
  }

  Future<void> clearAll() async {
    await prefs.clear();
  }
}
