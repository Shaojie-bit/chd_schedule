import 'package:flutter/material.dart';
import '../services/chd_auth.dart';
import '../services/chd_eams.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  final CHDAuthService authService;
  final StorageService storageService;

  const LoginScreen({
    super.key,
    required this.authService,
    required this.storageService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _needCaptcha = false;
  ImageProvider? _captchaImage;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // 如果本地之前保存过登录信息，则自动回填；未保存时保持空输入框
    final savedUser = widget.storageService.savedUsername;
    final savedPwd = widget.storageService.savedPassword;
    if (savedUser.isNotEmpty) {
      _usernameController.text = savedUser;
      _passwordController.text = savedPwd;
    }

    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    // 优先检查本地缓存是否已有课表与用户数据，存在直接秒开进入主页
    final cachedUser = widget.storageService.getCachedUser();
    if (cachedUser != null && cachedUser.name.isNotEmpty) {
      _navigateToMain();
      return;
    }

    // 尝试探测会话
    final isAlive = await widget.authService.isSessionAlive();
    if (isAlive && mounted) {
      _navigateToMain();
    }
  }

  Future<void> _refreshCaptcha() async {
    final bytes = await widget.authService.getCaptchaBytes();
    if (bytes != null && mounted) {
      setState(() {
        _captchaImage = MemoryImage(bytes);
      });
    }
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final captcha = _captchaController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '请输入学号与统一认证密码');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final res = await widget.authService.login(
      username,
      password,
      captcha: captcha,
    );

    if (!mounted) return;

    if (res.success) {
      if (widget.storageService.rememberMe) {
        await widget.storageService.saveCredentials(username, password);
      } else {
        await widget.storageService.clearCredentials();
      }

      // 初始化拉取个人信息与课表
      final eams = CHDEamsService(widget.authService.dio);
      final profile = await eams.getStudentDetail();
      if (profile != null) {
        await widget.storageService.saveUser(profile);
      }

      final semCtx = await eams.getSemestersAndContext();
      final currSem = semCtx['current_semester_id'] as String? ?? '262';
      final sems = semCtx['semesters'] as List<dynamic>? ?? [];
      await widget.storageService.saveCurrentSemesterId(currSem);
      await widget.storageService.saveSemesters(sems.cast());

      final courses = await eams.getCourseTable(currSem, semCtx['std_id'] ?? '');
      await widget.storageService.saveCourses(currSem, courses);

      // 后台顺便抓取一次成绩缓存到本地
      final grades = await eams.getGrades();
      if (grades.totalCourses > 0) {
        await widget.storageService.saveGrades(grades);
      }

      _navigateToMain();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res.message;
        _needCaptcha = res.needCaptcha;
      });
      if (res.needCaptcha) {
        _refreshCaptcha();
      }
    }
  }

  void _navigateToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainScreen(
          authService: widget.authService,
          storageService: widget.storageService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo 与标题
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentIndigo.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 42,
                    color: AppTheme.accentIndigo,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '长安大学 课程中心',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '统一身份认证登录 · 极速离线课表与成绩',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // 表单主卡片
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0x1FEF4444),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x4DEF4444)),
                          ),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // 学号输入
                      const Text(
                        '学号',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _usernameController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '请输入本科生学号',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 密码输入
                      const Text(
                        '统一认证密码',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '请输入登录密码',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 验证码输入框 (仅当需要时显示)
                      if (_needCaptcha) ...[
                        const Text(
                          '图形验证码',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _captchaController,
                                decoration: InputDecoration(
                                  hintText: '输入验证码',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppTheme.borderColor),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: _refreshCaptcha,
                              child: Container(
                                width: 100,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderColor),
                                ),
                                child: _captchaImage != null
                                    ? Image(image: _captchaImage!, fit: BoxFit.fill)
                                    : const Center(child: Text('点击获取', style: TextStyle(fontSize: 12))),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 记住密码复选框
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: widget.storageService.rememberMe,
                              onChanged: (v) {
                                setState(() {
                                  widget.storageService.rememberMe = v ?? true;
                                });
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '记住账号密码并开启自动离线缓存',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // 登录按钮
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('立即登录并同步'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '数据直接与长安大学统一认证交互，数据仅存放在手机本地',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
