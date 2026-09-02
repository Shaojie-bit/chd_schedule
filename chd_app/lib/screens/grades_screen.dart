import 'package:flutter/material.dart';
import '../models/grade.dart';
import '../services/chd_auth.dart';
import '../services/chd_eams.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/score_badge.dart';

class GradesScreen extends StatefulWidget {
  final CHDAuthService authService;
  final StorageService storageService;

  const GradesScreen({
    super.key,
    required this.authService,
    required this.storageService,
  });

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  GradesData? _gradesData;
  bool _isLoading = false;
  String _selectedSemester = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCachedGrades();
  }

  void _loadCachedGrades() {
    _gradesData = widget.storageService.getCachedGrades();
    if (_gradesData == null || _gradesData!.totalCourses == 0) {
      _refreshGrades();
    } else {
      setState(() {});
    }
  }

  Future<void> _refreshGrades() async {
    setState(() => _isLoading = true);
    try {
      final eams = CHDEamsService(widget.authService.dio);
      final isAlive = await widget.authService.isSessionAlive();
      if (!isAlive && widget.storageService.savedUsername.isNotEmpty) {
        await widget.authService.login(
          widget.storageService.savedUsername,
          widget.storageService.savedPassword,
        );
      }

      final freshGrades = await eams.getGrades();
      if (freshGrades.totalCourses > 0) {
        await widget.storageService.saveGrades(freshGrades);
        setState(() {
          _gradesData = freshGrades;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latestSummary = (_gradesData != null && _gradesData!.summary.isNotEmpty)
        ? _gradesData!.summary.first
        : null;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text(
          '学业成绩与 GPA 中心',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _refreshGrades,
            tooltip: '刷新成绩',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部最新学期 GPA 高亮卡片
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEF2FF), Color(0xFFFDF2F8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentIndigo.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentIndigo.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          latestSummary?.gpa ?? '3.72',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentIndigo,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '最新学期绩点',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '学业进展优异',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latestSummary != null
                              ? '已修读 ${latestSummary.courseCount} 门，共 ${latestSummary.totalCredits} 学分'
                              : '收录历年各学期课程明细与成绩单',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab 切换条
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppTheme.accentIndigo,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '单门课程明细'),
                  Tab(text: '历年学期绩点'),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Tab 内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCourseGradesTab(),
                  _buildSemesterSummaryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseGradesTab() {
    final allCourses = _gradesData?.courseGrades ?? [];

    // 提取所有学期选项
    final semesterOptions = <String, String>{'all': '全部学期课程'};
    for (final c in allCourses) {
      if (c.semesterId.isNotEmpty && !semesterOptions.containsKey(c.semesterId)) {
        semesterOptions[c.semesterId] = c.semesterName.isNotEmpty ? c.semesterName : c.term;
      }
    }

    final query = _searchController.text.trim().toLowerCase();
    final filtered = allCourses.where((c) {
      final matchSem = (_selectedSemester == 'all' || c.semesterId == _selectedSemester);
      final matchQuery = query.isEmpty ||
          c.courseName.toLowerCase().contains(query) ||
          c.category.toLowerCase().contains(query);
      return matchSem && matchQuery;
    }).toList();

    return Column(
      children: [
        // 筛选工具栏 (学期下拉 + 搜索框)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              // 学期下拉菜单
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: semesterOptions.containsKey(_selectedSemester)
                        ? _selectedSemester
                        : 'all',
                    items: semesterOptions.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedSemester = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 搜索输入框
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '搜索课程...',
                      hintStyle: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 课程计数说明
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '共 ${filtered.length} 门课程',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // 课程列表
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _isLoading ? '正在从教务拉取课程成绩...' : '暂无匹配的课程成绩',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final c = filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        c.term.isNotEmpty ? c.term : c.semesterName,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentIndigo.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        c.category,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.accentIndigo,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  c.courseName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${c.credits} 学分  ·  平时: ${c.usualScore.isEmpty ? '-' : c.usualScore}  ·  期末: ${c.examScore.isEmpty ? '-' : c.examScore}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ScoreBadge(score: c.score),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '绩点: ',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                  Text(
                                    c.gpa.isEmpty ? '-' : c.gpa,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.accentIndigo,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSemesterSummaryTab() {
    final summaries = _gradesData?.summary ?? [];

    if (summaries.isEmpty) {
      return Center(
        child: Text(
          _isLoading ? '正在获取历年学期绩点概览...' : '暂无学期概览数据',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: summaries.length,
      itemBuilder: (ctx, i) {
        final s = summaries[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.academicYear} 第 ${s.term} 学期',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '修读 ${s.courseCount} 门课程  ·  总计 ${s.totalCredits} 学分',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentIndigo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      s.gpa,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.accentIndigo,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '平均绩点',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
