import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:html/parser.dart' as html_parser;

/// 安全 Cookie 管理拦截器，自动清洗和修复高校服务器非标准的 SameSite 属性，杜绝崩溃
class SafeCookieManager extends Interceptor {
  final CookieJar cookieJar;

  SafeCookieManager(this.cookieJar);

  static String sanitizeSetCookie(String raw) {
    return raw.replaceAllMapped(
      RegExp(r';\s*SameSite(=[^;]*)?', caseSensitive: false),
      (match) {
        final val = match.group(1)?.replaceFirst('=', '').trim().replaceAll('"', '') ?? '';
        final lower = val.toLowerCase();
        if (lower == 'lax') return '; SameSite=Lax';
        if (lower == 'strict') return '; SameSite=Strict';
        if (lower == 'none') return '; SameSite=None';
        return ''; // 移除其他非标准/空值的 SameSite
      },
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final cookies = await cookieJar.loadForRequest(options.uri);
      final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      if (cookieString.isNotEmpty) {
        options.headers[HttpHeaders.cookieHeader] = cookieString;
      }
    } catch (_) {}
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    await _saveCookies(response.realUri, response.headers);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response != null) {
      await _saveCookies(err.response!.realUri, err.response!.headers);
    }
    handler.next(err);
  }

  Future<void> _saveCookies(Uri uri, Headers headers) async {
    final setCookies = headers[HttpHeaders.setCookieHeader];
    if (setCookies == null || setCookies.isEmpty) return;

    final parsedCookies = <Cookie>[];
    for (final raw in setCookies) {
      try {
        final sanitized = sanitizeSetCookie(raw);
        parsedCookies.add(Cookie.fromSetCookieValue(sanitized));
      } catch (_) {
        try {
          final parts = raw.split(';').first.split('=');
          if (parts.length >= 2) {
            parsedCookies.add(Cookie(parts[0].trim(), parts.sublist(1).join('=').trim()));
          }
        } catch (_) {}
      }
    }

    if (parsedCookies.isNotEmpty) {
      try {
        await cookieJar.saveFromResponse(uri, parsedCookies);
      } catch (_) {}
    }
  }
}

class AuthResult {
  final bool success;
  final String message;
  final bool needCaptcha;

  AuthResult({
    required this.success,
    this.message = '',
    this.needCaptcha = false,
  });
}

class CHDAuthService {
  late final Dio dio;
  late final CookieJar cookieJar;
  final String serviceUrl = 'http://bkjw.chd.edu.cn/eams/home.action';
  final String loginUrl =
      'https://ids.chd.edu.cn/authserver/login?service=http%3A%2F%2Fbkjw.chd.edu.cn%2Feams%2Fhome.action';

  CHDAuthService({CookieJar? customJar}) {
    cookieJar = customJar ?? CookieJar();
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        followRedirects: true,
        maxRedirects: 8,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    dio.interceptors.add(SafeCookieManager(cookieJar));
  }

  /// 检查当前 Cookie 会话是否依然有效，避免频繁登录导致账号被冻结 10 分钟
  Future<bool> isSessionAlive() async {
    try {
      final res = await dio.get(
        serviceUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (res.statusCode == 200) {
        return true;
      }
      final location = res.headers.value('location') ?? '';
      if (res.statusCode == 302 && !location.contains('authserver')) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 检查是否需要验证码
  Future<bool> checkNeedCaptcha(String username) async {
    try {
      final res = await dio.get(
        'https://ids.chd.edu.cn/authserver/checkNeedCaptcha.htl?username=$username',
      );
      if (res.data is Map) {
        return res.data['isNeed'] == true;
      } else if (res.data is String) {
        final map = jsonDecode(res.data as String);
        return map['isNeed'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 获取验证码二进制流
  Future<Uint8List?> getCaptchaBytes() async {
    try {
      final rnd = Random().nextInt(1000000);
      final res = await dio.get<List<int>>(
        'https://ids.chd.edu.cn/authserver/getCaptcha.htl?$rnd',
        options: Options(responseType: ResponseType.bytes),
      );
      if (res.data != null) {
        return Uint8List.fromList(res.data!);
      }
    } catch (_) {}
    return null;
  }

  /// 纯 Dart 实现 AES-128-CBC 密码加密
  String _encryptPassword(String password, String salt) {
    const chars = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
    final rnd = Random();
    final random64 =
        List.generate(64, (_) => chars[rnd.nextInt(chars.length)]).join();
    final iv16 =
        List.generate(16, (_) => chars[rnd.nextInt(chars.length)]).join();

    final key = enc.Key.fromUtf8(salt);
    final iv = enc.IV.fromUtf8(iv16);
    final encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
    );

    final encrypted = encrypter.encrypt(random64 + password, iv: iv);
    return encrypted.base64;
  }

  /// 执行登录统一认证
  Future<AuthResult> login(
    String username,
    String password, {
    String captcha = '',
  }) async {
    try {
      // 1. 请求登录页面，获取 salt 和 execution
      final getRes = await dio.get(loginUrl);
      final doc = html_parser.parse(getRes.data);

      final pwdForm = doc.querySelector('form#pwdFromId');
      if (pwdForm == null) {
        if (getRes.realUri.toString().contains('eams')) {
          return AuthResult(success: true, message: '已经在登录状态');
        }
        return AuthResult(success: false, message: '未找到登录表单，请检查网络');
      }

      var action = pwdForm.attributes['action'] ?? '/authserver/login';
      if (!action.startsWith('http')) {
        action = Uri.parse(loginUrl).resolve(action).toString();
      }
      if (!action.contains('service=')) {
        action +=
            '?service=${Uri.encodeQueryComponent(serviceUrl)}';
      }

      final saltInput = doc.querySelector('input#pwdEncryptSalt');
      final salt = saltInput?.attributes['value'] ?? '';
      if (salt.isEmpty) {
        return AuthResult(success: false, message: '获取动态密码盐失败');
      }

      final executionInput = doc.querySelector('input[name=execution]');
      final execution = executionInput?.attributes['value'] ?? 'e1s1';

      // 2. 检查验证码
      final needCaptcha = await checkNeedCaptcha(username);
      if (needCaptcha && captcha.isEmpty) {
        return AuthResult(
          success: false,
          needCaptcha: true,
          message: '需要输入验证码',
        );
      }

      // 3. 加密密码
      final encPwd = _encryptPassword(password, salt);

      // 4. 发送登录请求
      final formData = {
        'username': username,
        'password': encPwd,
        'captcha': captcha,
        '_eventId': 'submit',
        'cllt': 'userNameLogin',
        'dllt': 'generalLogin',
        'lt': '',
        'execution': execution,
      };

      final postRes = await dio.post(
        action,
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // 手动逐步跟随跨协议重定向，确保每一步 302 返回的 Set-Cookie 均被保存
      var currentUrl = postRes.headers.value('location') ?? '';
      var redirectSteps = 0;
      while (currentUrl.isNotEmpty && redirectSteps < 10) {
        redirectSteps++;
        if (!currentUrl.startsWith('http')) {
          currentUrl = Uri.parse(action).resolve(currentUrl).toString();
        }
        final stepRes = await dio.get(
          currentUrl,
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        final nextLoc = stepRes.headers.value('location') ?? '';
        if (nextLoc.isNotEmpty) {
          if (nextLoc.startsWith('http')) {
            currentUrl = nextLoc;
          } else {
            currentUrl = Uri.parse(currentUrl).resolve(nextLoc).toString();
          }
        } else {
          break;
        }
      }

      // 验证教务会话是否已激活
      if (await isSessionAlive()) {
        return AuthResult(success: true, message: '登录成功');
      }

      final finalUrl = postRes.realUri.toString();
      if (finalUrl.contains('eams') || finalUrl.contains('home.action')) {
        return AuthResult(success: true, message: '登录成功');
      }

      // 登录失败，从页面提取错误提示
      final errDoc = html_parser.parse(postRes.data);
      final errEl = errDoc.querySelector('#showErrorTip, #msg, .auth_error');
      final errMsg = errEl?.text.trim() ?? '';
      if (errMsg.isNotEmpty) {
        return AuthResult(
          success: false,
          message: errMsg,
          needCaptcha: needCaptcha,
        );
      }

      if (postRes.data.toString().contains('密码有误') ||
          postRes.data.toString().contains('用户名或密码')) {
        return AuthResult(success: false, message: '用户名或密码错误');
      }

      return AuthResult(success: true, message: '登录完成');
    } catch (e) {
      return AuthResult(success: false, message: '连接错误: $e');
    }
  }
}
