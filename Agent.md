# CHD 课表系统架构与 AI 协作开发白皮书 (Agent.md)

> 🤖 **致后续接手本项目的 AI 协作助手 (Antigravity / Claude / GPT) 与核心开发者**：  
> 本文档是整个「长安大学现代化课表系统」的全局工程与架构基石。在进行任何代码修改、重构或功能迭代之前，**请务必通读本文档**。它记录了所有关键模块设计、教务系统底层逆向协议、数据契约以及踩坑防线。

---

## 1. 项目定位与系统全景 (Project Blueprint)

本项目由三个解耦但紧密配合的子系统构成：

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                              产品矩阵全局架构                                │
└─────────────────────────────────────────────────────────────────────────────┘

    [子系统 A: 原生移动端]               [子系统 B: 响应式 Web 端]
    chd_app/ (Flutter 3.x)              app.py + static/ (Python/HTML5)
         │                                       │
         ├───────────────────────┬───────────────┤
         ▼                       ▼               ▼
┌──────────────────┐    ┌─────────────────┐    ┌──────────────────────┐
│ 长安大学统一认证  │    │ 长安大学本科教务 │    │ 配套云端统计与公告   │
│ ids.chd.edu.cn   │    │ bkjw.chd.edu.cn │    │ server/ (FastAPI)    │
│ (AES-128 动态加盐)│    │ (调度数据流逆向)│    │ (Port 2543 / 双模DB) │
└──────────────────┘    └─────────────────┘    └──────────────────────┘
```

1. **`chd_app/` (原生移动端)**：基于 Flutter 3.x 纯原生开发，支持 Android（产出正式 Release APK），采用 Material 3 纯浅色现代 Bento 设计，支持完全离线查看、手势切周、完整地点与教师解析；
2. **`static/` + `app.py` (Web 响应式端)**：纯原生 Vanilla JS/CSS + Python 后端，支持局域网多端访问，支持导出标准 `.ics` iCalendar 文件实现手机与手表上课提前 20 分钟强提醒；
3. **`server/` (云端数据与公告中心)**：基于 FastAPI + Uvicorn 运行（默认端口 `2543`），支持 Azure MySQL 云数据库与内置 SQLite 自动平滑降级，提供学生使用活跃度统计看板与启动公告/新版 APK 弹窗推送。

---

## 2. 核心逆向协议与业务逻辑细节 (Reverse Engineering)

这是本项目最核心的资产，任何教务网对接的改动必须严格遵循以下协议规范：

### 2.1 长安大学统一认证 (IDS) 登录流程

- **认证入口**：`http://bkjw.chd.edu.cn/eams/home.action` -> 302 重定向至 `https://ids.chd.edu.cn/authserver/login?service=...`
- **提取表单隐藏域**：从登录页 HTML 中解析 `execution` 与隐藏的 `<input id="pwdEncryptSalt" value="...">`；
- **加密核心算法**：
  ```dart
  // Dart 实现 (参考 lib/services/chd_auth.dart)
  final key = enc.Key.fromUtf8(salt);
  final iv = enc.IV.fromUtf8(salt);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
  final encryptedPassword = encrypter.encrypt(rawPassword, iv: iv).base64;
  ```
- **Cookie 规范化防坑**：学校认证中心下发的 Cookie 包含非标的 `SameSite=no_restriction`，在 Dart `dio_cookie_manager` 中会抛出异常。必须在持久化前对其清洗（替换为标准 `SameSite=None` 或移除）。

### 2.2 教务系统 (EAMS) 调度数据解析

- **课表页面入口**：`http://bkjw.chd.edu.cn/eams/courseTableForStd!courseTable.action`；
- **真实教师数据解析（关键坑点）**：
  - **现象**：教务系统底部的总表中，部分实验或设计课程被粗暴标注为“待定”，读取 HTML `table` 无法得到准确教师；
  - **底层真相**：教务系统前端调度引擎在 `<script>` 块中内联了真实的 `TaskActivity` 和 `var teachers = ([...]);`；
  - **解析方案**：
    ```dart
    // 解析内联脚本中的教师 JSON 数组：
    final teachersMatch = RegExp(r'var teachers = \(\[(.*?)\]\);', dotAll: true).firstMatch(html);
    // 建立 taskActivity 与教师真实姓名的映射，完全取代“待定”
    ```
- **教室地点完整展示与排版抗截断算法**：
  - 教室编号包含完整的代号前缀（如 `WX2304` 代表渭水校区 2304 教室），**严禁将 WX 删减或替换为汉字**；
  - **排版断词陷阱**：Flutter 文字引擎对连续英数字符串（`WX2304`）不执行折行，列宽不足时会强制裁剪为 `WX23…`；
  - **解法**：在字符间插入零宽排版断词符 `\u200B`：
    ```dart
    String formatRoom(String raw) => raw.split('').join('\u200B');
    ```
    配合 `maxLines: 3` 和 `softWrap: true`，确保屏幕过窄时自适应换行，字符 100% 完整可见。
- **周次位图掩码 (Week Bitmap)**：
  - 每个活动块携带 20 位以上的位图字符串（如 `01111111000000000000`）；
  - 第 $N$ 位（1-indexed）为 `'1'` 即代表第 $N$ 周有课。

### 2.3 成绩与 GPA 统计机制

- **请求接口**：`POST /eams/teach/grade/course/person!historyCourseGrade.action?projectType=`
- **数据结构**：包含历年所有学期列表，每个学期包含：
  - 学期平均绩点（GPA）与总学分、修读门数；
  - 该学期每门课程的代码、课程名、性质（必修/选修/公选）、学分、原始得分及绩点。

---

## 3. 代码仓库全景与关键文件索引 (Code Map)

```text
chd课表/
├── chd_app/                           # 【原生 Flutter 安卓应用】
│   ├── lib/
│   │   ├── main.dart                  # 应用启动入口、全局轻量 Provider/初始化
│   │   ├── theme/app_theme.dart       # 全局纯浅色 Modern Bento 调色板与圆角规范
│   │   ├── models/
│   │   │   ├── course.dart            # 课程与时间槽模型 (包含颜色与周次位图)
│   │   │   ├── grade.dart             # 成绩与 GPA 学期汇总模型
│   │   │   ├── student.dart           # 学生个人基础学籍信息
│   │   │   └── announcement.dart      # 云端通知与版本升级模型
│   │   ├── services/
│   │   │   ├── chd_auth.dart          # IDS 登录认证与 AES 动态加盐加密器
│   │   │   ├── chd_eams.dart          # EAMS 课表、教师映射、成绩抓取核心
│   │   │   ├── storage_service.dart   # 本地安全沙盒持久化 (记住密码/离线秒开)
│   │   │   └── telemetry_service.dart # 后台静默心跳上报与公告拉取服务
│   │   ├── screens/
│   │   │   ├── schedule_screen.dart   # 课表主界面 (周矩阵、日期联动、左右滑动手势)
│   │   │   ├── grades_screen.dart     # 成绩仪表盘 (GPA 走势、学分、课程明细)
│   │   │   ├── login_screen.dart      # 现代登录界面 (干净无预填，支持自动登录)
│   │   │   └── main_screen.dart       # 底栏主容器 (Tab 切换、学生档案面板)
│   │   └── widgets/
│   │       ├── course_card.dart       # 课表格子卡片 (零宽换行、对比度强化)
│   │       ├── course_detail_sheet.dart # 课程详情点阵弹窗 (1~20周全景分布)
│   │       └── announcement_dialog.dart # 启动全屏/居中公告弹窗卡片
│   └── android/                       # 原生 Android 配置与全套官方校徽 Mipmap 图标
│
├── server/                            # 【云端统计与公告后台服务】
│   ├── main.py                        # FastAPI 高并发异步服务端、管理看板
│   ├── .env.example                   # 数据库配置文件模板
│   ├── start.sh                       # Linux/Ubuntu 一键虚拟环境启动脚本
│   ├── Dockerfile & docker-compose.yml# 容器化部署配置 (暴露端口 2543)
│   └── README.md                      # 独立服务端部署白皮书
│
├── static/                            # 【响应式 Web 端前端资产】
├── app.py                             # Web 端轻量 Python 服务
├── calendar_export.py                 # RFC 5545 iCalendar (.ics) 日历同步引擎
└── Agent.md                           # 本架构白皮书文档
```

---

## 4. 必须遵守的「黄金军规」与避坑指南 (Critical Rules)

后续 AI 进行开发或维护时，**严禁违背以下 4 条铁律**：

### 🚨 铁律 1：严禁在自动化测试中高频触发学校真实登录
- **教务系统风控策略**：长安大学统一身份认证系统对同一 IP / 账号的连续失败或高频调用有**10 分钟临时封禁风控**；
- **AI 行为规范**：在 `flutter test` 或自动化构建脚本中，必须跳过频繁的真实网络登录用例，使用 Mock 数据或基于已抓取的 HTML 进行单测。

### 🚨 铁律 2：Windows 下构建 Flutter APK 必须使用虚拟磁盘映射
- **致命问题**：当前项目路径包含中文字符（`f:\files\programs\课表\chd课表`）。Dart AOT 编译器在 Windows 下读取含中文路径时会发生 Snapshotter 崩溃；
- **规范构建命令**：
  ```powershell
  # 必须使用 subst 映射为纯英文驱动器 P: 进行打包
  subst P: 'F:\files\programs\课表\chd课表\chd_app'
  cd P:\
  flutter build apk --release
  subst P: /d
  Copy-Item 'F:\files\programs\课表\chd课表\chd_app\build\app\outputs\flutter-apk\app-release.apk' 'F:\files\programs\课表\chd课表\CHD课表.apk'
  ```

### 🚨 铁律 3：绝不允许在代码库中提交明文密码与个人数据
- 任何云数据库凭证必须通过环境变量或 `.env` 注入，不得硬编码在 `server/main.py`；
- 所有学生学号与密码必须在 `chd_app` 本地沙盒加密，严禁提交任何真实的 `data_cache/*.json` 数据文件至 Git；
- 遵循根目录 `.gitignore` 规则。

### 🚨 铁律 4：UI 界面必须维持纯浅色极简美学
- 用户明确要求：**只要浅色模式，不要深色模式**；
- 遵循 Material 3 与 Bento Grid 现代轻量质感（柔和紫色渐变、圆角卡片、高对比度文字）。

---

## 5. 常用开发与维护指令速查 (Cookbook)

### 5.1 Flutter 移动端指令
```bash
# 依赖拉取
cd chd_app
flutter pub get

# 静态代码检查 (确保 0 errors)
flutter analyze

# 单元与解析测试
flutter test

# 调试运行 (连接安卓真机或模拟器)
flutter run
```

### 5.2 云端后台测试与运行
```bash
# 本地调试启动 (端口 2543)
cd server
python -m uvicorn main:app --host 0.0.0.0 --port 2543 --reload

# 查看代码语法编译
python -m py_compile main.py
```

### 5.3 Web 端与日历导出运行
```bash
python app.py
# 访问 http://localhost:8000
```
