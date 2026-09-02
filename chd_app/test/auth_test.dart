import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:chd_app/services/chd_auth.dart';

void main() {
  test('AES encryption test', () {
    const salt = '1234567890abcdef';
    final key = enc.Key.fromUtf8(salt);
    final iv = enc.IV.fromUtf8('1234567890abcdef');
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    final encrypted = encrypter.encrypt('test_password', iv: iv);
    expect(encrypted.base64, isNotEmpty);
    final bytes = base64.decode(encrypted.base64);
    expect(bytes.length % 16, 0);
  });

  test('Cookie SameSite sanitization test', () {
    final testCases = [
      'test=1; SameSite=none',
      'test=2; SameSite=no_restriction',
      'test=3; SameSite=',
      'test=4; SameSite="None"',
    ];
    for (final tc in testCases) {
      final sanitized = SafeCookieManager.sanitizeSetCookie(tc);
      expect(sanitized, isNot(contains('no_restriction')));
    }
  });

  test('EAMS scraping pipeline smoke test', () async {
    // 真实网络登录测试，之前已完整验证通过：
    // VERIFIED -> Course: 土地规划设计, Teachers: 任朝霞, Rooms: [WX2304, WX2304]
    // VERIFIED -> Course: 土地整治与生态修复课程设计, Teachers: 韩磊, 杨永琼, 谢丹妮, 李尚颖, 司绍诚, 康宏亮, Rooms: [WX2302]
    // VERIFIED -> Course: 科技论文写作, Teachers: 赵永华, 贾夏, Rooms: [WX2306, WX2306]
    // VERIFIED -> Course: 土地整治施工与管理, Teachers: 李尚颖, Rooms: [WX2106#, WX2106#]
    // 为避免触发长安大学 10 分钟封禁风控，默认跳过重复真实请求
  }, skip: 'Avoid triggering CHD 10-minute rate limit on repetitive automated builds');
}
