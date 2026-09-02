import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/student.dart';
import '../services/chd_auth.dart';
import '../services/chd_eams.dart';
import '../services/storage_service.dart';
import '../services/telemetry_service.dart';
import '../theme/app_theme.dart';
import '../widgets/announcement_dialog.dart';
import '../widgets/course_card.dart';

class ScheduleScreen extends StatefulWidget {
  final CHDAuthService authService;
  final StorageService storageService;

  const ScheduleScreen({
    super.key,
    required this.authService,
    required this.storageService,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _selectedWeek = 1;
  String _currentSemesterId = '262';
  List<Course> _courses = [];
  StudentProfile? _profile;
  List<SemesterInfo> _semesters = [];
  bool _isRefreshing = false;
  late final TelemetryService _telemetryService;
  bool _hasUnreadAnnouncement = false;

  final List<String> _periodTimes = [
    '08:00',
    '08:50',
    '10:05',
    '10:55',
    '14:00',
    '14:50',
    '16:00',
    '16:50',
    '19:00',
    '19:50',
    '20:40',
  ];

  @override
  void initState() {
    super.initState();
    _telemetryService = TelemetryService(widget.storageService);
    _loadLocalData();
    _calculateCurrentWeek();
    _reportTelemetryAndCheckAnnouncements();
  }

  Future<void> _reportTelemetryAndCheckAnnouncements() async {
    _telemetryService.reportHeartbeat(_profile);

    final ann = await _telemetryService.getLatestAnnouncement();
    if (ann != null && mounted) {
      final lastRead = widget.storageService.lastReadAnnouncementId;
      if (ann.id > lastRead) {
        setState(() => _hasUnreadAnnouncement = true);
        if (ann.isPopup) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AnnouncementPopupDialog(
              announcement: ann,
              onDismiss: () async {
                Navigator.of(ctx).pop();
                await widget.storageService.saveLastReadAnnouncementId(ann.id);
                if (mounted) setState(() => _hasUnreadAnnouncement = false);
              },
            ),
          );
        }
      }
    }
  }

  void _calculateCurrentWeek() {
    // 假设开学日期为 2026-08-31
    final termStart = DateTime(2026, 8, 31);
    final now = DateTime.now();
    final diffDays = now.difference(termStart).inDays;
    final w = (diffDays / 7).floor() + 1;
    setState(() {
      _selectedWeek = w.clamp(1, 20);
    });
  }

  void _loadLocalData() {
    _profile = widget.storageService.getCachedUser();
    _semesters = widget.storageService.getCachedSemesters();
    _currentSemesterId = widget.storageService.getCurrentSemesterId();
    _courses = widget.storageService.getCachedCourses(_currentSemesterId);
    setState(() {});
    if (_courses.isEmpty || _profile == null || _profile!.name.isEmpty) {
      _refreshSchedule();
    }
  }

  Future<void> _refreshSchedule() async {
    setState(() => _isRefreshing = true);
    try {
      final eams = CHDEamsService(widget.authService.dio);
      final isAlive = await widget.authService.isSessionAlive();
      if (!isAlive && widget.storageService.savedUsername.isNotEmpty) {
        await widget.authService.login(
          widget.storageService.savedUsername,
          widget.storageService.savedPassword,
        );
      }

      final profile = await eams.getStudentDetail();
      if (profile != null && profile.name.isNotEmpty) {
        await widget.storageService.saveUser(profile);
        _profile = profile;
      }

      final semCtx = await eams.getSemestersAndContext();
      final stdId = semCtx['std_id'] ?? '';
      final sems = semCtx['semesters'] as List<dynamic>? ?? [];
      if (sems.isNotEmpty) {
        await widget.storageService.saveSemesters(sems.cast());
        _semesters = widget.storageService.getCachedSemesters();
      }

      final freshCourses = await eams.getCourseTable(_currentSemesterId, stdId);
      if (freshCourses.isNotEmpty) {
        await widget.storageService.saveCourses(_currentSemesterId, freshCourses);
        _courses = freshCourses;
      }
      setState(() {});
    } catch (_) {} finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _profile?.name.isNotEmpty == true ? _profile!.name : '同学',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentIndigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _profile?.campus.isNotEmpty == true ? _profile!.campus : '长安大学',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.accentIndigo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              _profile?.major.isNotEmpty == true
                  ? '${_profile!.department} · ${_profile!.major}'
                  : '现代教务课程中心',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (_hasUnreadAnnouncement)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: '通知公告',
            onPressed: () async {
              final list = await _telemetryService.getAllAnnouncements();
              if (!mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => AnnouncementListSheet(announcements: list),
              );
              if (_hasUnreadAnnouncement) {
                final latest = await _telemetryService.getLatestAnnouncement();
                if (latest != null) {
                  await widget.storageService.saveLastReadAnnouncementId(latest.id);
                }
                setState(() => _hasUnreadAnnouncement = false);
              }
            },
          ),
          if (_semesters.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.tune_rounded),
              tooltip: '切换学期',
              onSelected: (semId) async {
                setState(() {
                  _currentSemesterId = semId;
                  _courses = widget.storageService.getCachedCourses(semId);
                });
                await widget.storageService.saveCurrentSemesterId(semId);
                if (_courses.isEmpty) {
                  _refreshSchedule();
                }
              },
              itemBuilder: (ctx) => _semesters.map((s) {
                final isCurr = s.id == _currentSemesterId;
                return PopupMenuItem(
                  value: s.id,
                  child: Row(
                    children: [
                      if (isCurr)
                        const Icon(Icons.check, size: 16, color: AppTheme.accentIndigo)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 6),
                      Text(
                        s.name,
                        style: TextStyle(
                          fontWeight: isCurr ? FontWeight.bold : FontWeight.normal,
                          color: isCurr ? AppTheme.accentIndigo : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isRefreshing ? null : _refreshSchedule,
            tooltip: '同步教务课表',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1~20 周水平滑动选择条
            _buildWeekSelector(),

            // 今日待上课卡片
            _buildTodayBanner(),

            // 课表核心矩阵网格
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshSchedule,
                child: _buildTimetableGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 20,
        itemBuilder: (ctx, i) {
          final w = i + 1;
          final isSelected = w == _selectedWeek;
          return GestureDetector(
            onTap: () => setState(() => _selectedWeek = w),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accentIndigo : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.accentIndigo : AppTheme.borderColor,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.accentIndigo.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '第 $w 周',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayBanner() {
    // 查找今天星期几
    final todayWeekday = DateTime.now().weekday; // 1-7
    final todayCourses = <Map<String, dynamic>>[];

    for (final c in _courses) {
      for (final s in c.slots) {
        if (s.dayOfWeek == todayWeekday && s.weeks.contains(_selectedWeek)) {
          todayCourses.add({'course': c, 'slot': s});
        }
      }
    }

    todayCourses.sort((a, b) =>
        (a['slot'] as CourseSlot).startPeriod.compareTo((b['slot'] as CourseSlot).startPeriod));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentIndigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppTheme.accentIndigo,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todayCourses.isNotEmpty
                      ? '今日待上 (${todayCourses.length} 门课程)'
                      : '今日无待上课程',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  todayCourses.isNotEmpty
                      ? '${(todayCourses.first['course'] as Course).name} · ${(todayCourses.first['slot'] as CourseSlot).room}'
                      : '放松一下，享受惬意的大学时光吧！',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              '第 $_selectedWeek 周',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid() {
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final termStart = DateTime(2026, 8, 31);
    final now = DateTime.now();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) {
          // 左滑：切换到下一周
          if (_selectedWeek < 20) {
            setState(() {
              _selectedWeek++;
            });
          }
        } else if (details.primaryVelocity! > 200) {
          // 右滑：切换到上一周
          if (_selectedWeek > 1) {
            setState(() {
              _selectedWeek--;
            });
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            // 星期与日期联动表头
            Container(
              height: 44,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 38,
                    child: Center(
                      child: Text(
                        '节次',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ...List.generate(7, (d) {
                    final dayDate = termStart.add(Duration(days: (_selectedWeek - 1) * 7 + d));
                    final isToday = dayDate.year == now.year &&
                        dayDate.month == now.month &&
                        dayDate.day == now.day;
                    final dateStr = '${dayDate.month}/${dayDate.day}';

                    return Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: isToday ? AppTheme.accentIndigo.withValues(alpha: 0.08) : null,
                          borderRadius: isToday ? BorderRadius.circular(8) : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              days[d],
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                                color: isToday ? AppTheme.accentIndigo : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                color: isToday ? AppTheme.accentIndigo : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // 11 节次课程表格内容
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧节次与时间列表
                    SizedBox(
                      width: 38,
                      child: Column(
                        children: List.generate(11, (p) {
                          return Container(
                            height: 60,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFF1F5F9)),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${p + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  _periodTimes[p],
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),

                    // 7 天每列内容
                    ...List.generate(7, (dayIdx) {
                      final dayOfWeek = dayIdx + 1;
                      return Expanded(
                        child: _buildDayColumn(dayOfWeek),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayColumn(int dayOfWeek) {
    // 找出属于该天的课程槽位 (当前选中周次)
    final slotsInDay = <Map<String, dynamic>>[];
    for (final c in _courses) {
      for (final s in c.slots) {
        if (s.dayOfWeek == dayOfWeek && s.weeks.contains(_selectedWeek)) {
          slotsInDay.add({'course': c, 'slot': s});
        }
      }
    }

    return Stack(
      children: [
        // 背景 11 节网格线
        Column(
          children: List.generate(11, (p) {
            return Container(
              height: 60,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFF1F5F9)),
                  bottom: BorderSide(color: Color(0xFFF1F5F9)),
                ),
              ),
            );
          }),
        ),

        // 浮层放置课程卡片
        ...slotsInDay.map((item) {
          final course = item['course'] as Course;
          final slot = item['slot'] as CourseSlot;
          final top = (slot.startPeriod - 1) * 60.0;
          final height = slot.periodCount * 60.0;

          return Positioned(
            top: top,
            left: 0,
            right: 0,
            height: height,
            child: CourseGridCell(
              course: course,
              slot: slot,
            ),
          );
        }),
      ],
    );
  }
}
