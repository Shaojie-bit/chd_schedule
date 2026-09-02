import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/chd_auth.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置状态栏沉浸与纯浅色系统图标
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final storageService = await StorageService.init();
  final authService = CHDAuthService();

  runApp(CHDApp(
    storageService: storageService,
    authService: authService,
  ));
}

class CHDApp extends StatelessWidget {
  final StorageService storageService;
  final CHDAuthService authService;

  const CHDApp({
    super.key,
    required this.storageService,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    final cachedUser = storageService.getCachedUser();
    final hasSession = cachedUser != null && cachedUser.name.isNotEmpty;

    return MaterialApp(
      title: 'CHD 课表',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: hasSession
          ? MainScreen(
              authService: authService,
              storageService: storageService,
            )
          : LoginScreen(
              authService: authService,
              storageService: storageService,
            ),
    );
  }
}
