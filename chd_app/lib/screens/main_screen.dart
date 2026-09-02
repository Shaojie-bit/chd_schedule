import 'package:flutter/material.dart';
import '../services/chd_auth.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'schedule_screen.dart';
import 'grades_screen.dart';
import 'login_screen.dart';

class MainScreen extends StatefulWidget {
  final CHDAuthService authService;
  final StorageService storageService;

  const MainScreen({
    super.key,
    required this.authService,
    required this.storageService,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ScheduleScreen(
        authService: widget.authService,
        storageService: widget.storageService,
      ),
      GradesScreen(
        authService: widget.authService,
        storageService: widget.storageService,
      ),
    ];
  }

  void _showProfileDialog() {
    final user = widget.storageService.getCachedUser();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('学生档案与设置', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileItem('姓名', user?.name ?? '-'),
            _buildProfileItem('学号', user?.studentId ?? '-'),
            _buildProfileItem('院系', user?.department ?? '-'),
            _buildProfileItem('专业', user?.major ?? '-'),
            _buildProfileItem('校区', user?.campus ?? '-'),
            _buildProfileItem('班级', user?.adminClass ?? '-'),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 6),
            const Text(
              '当前数据已完整保存在手机沙盒，支持断网离线秒开。',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.storageService.clearAll();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      authService: widget.authService,
                      storageService: widget.storageService,
                    ),
                  ),
                );
              }
            },
            child: const Text('退出登录', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderColor, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.accentIndigo,
          unselectedItemColor: AppTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          elevation: 0,
          onTap: (index) {
            if (index == 2) {
              _showProfileDialog();
            } else {
              setState(() => _currentIndex = index);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: '课表',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events_rounded),
              label: '成绩',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
