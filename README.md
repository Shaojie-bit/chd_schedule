# CHD 课表中心 (CHD Schedule Hub)

> 🎓 **专为长安大学学子量身定制的现代化教务日程、智能课表与学业分析系统。**  
> 告别教务系统繁琐登录与陈旧界面，享受秒开、离线可用、全学期精准排课与手机日历无缝联动的极致体验。

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📖 目录

- [✨ 核心功能特性](#-核心功能特性)
- [🔬 核心技术与逆向原理](#-核心技术与逆向原理)
  - [1. 统一身份认证中心 (IDS) 动态加盐协议](#1-统一身份认证中心-ids-动态加盐协议)
  - [2. 教务综合管理系统 (EAMS) 数据抓取与解析机制](#2-教务综合管理系统-eams-数据抓取与解析机制)
  - [3. iCalendar (.ics) 日历同步与防迟到提醒算法](#3-icalendar-ics-日历同步与防迟到提醒算法)
  - [4. 云端轻量遥测与全校通知分发服务](#4-云端轻量遥测与全校通知分发服务)
- [📱 客户端与产品形态](#-客户端与产品形态)
- [📂 仓库项目结构](#-仓库项目结构)
- [🚀 快速上手与运行](#-快速上手与运行)
- [🔒 隐私与安全性保障](#-隐私与安全性保障)
- [📄 开源许可](#-开源许可)

---

## ✨ 核心功能特性

### 1. 📅 现代化智能周课表
- **动态日期与教学周联动**：周一至周日下方实时呈现当前周的具体公历日期（如 `9/2`），今天所在列自动采用微紫色高亮；
- **手势自然交互**：在课表任意区域支持**左右滑动手势切换周次**，滑动时顶部 7 天日期与课程卡片毫秒级联动响应；
- **完整教室与地点展示**：保留 `WX2304`、`WX2302`、`WX2106#` 等校区原汁原味教室编号；自研零宽排版折行算法，狭窄屏幕下自适应折为两行，绝不出现 `WX23…` 省略号截断；
- **真实授课教师精准匹配**：绕过教务系统底部表格的“待定”占位符，深度解析课程调度内核数据，完整呈现真实主讲教师姓名；
- **今日待上速览**：首屏清晰罗列今天剩余课程、上课教室与节次安排。

### 2. 📊 成绩、学分与 GPA 全维档案
- **学业走势仪表盘**：历年学期总学分、修读门数与学期平均绩点（GPA）清晰汇总展示；
- **课程明细穿透**：每门课程的课程性质（必修/选修/公选）、课程学分、最终得分及绩点卡片一目了然，得分档次自动彩色徽章标记；
- **断网离线秒开**：教务网络经常维护或卡顿，系统在首次登录成功后将数据加密沉淀至本地沙盒，断网环境下依然 0 毫秒秒开。

### 3. ⏰ 手机系统日历一键全同步 (.ics)
- 遵循国际 RFC 5545 iCalendar 标准协议；
- 一键生成 `.ics` 日历订阅文件，导入 iPhone / iPad / Mac（Apple Calendar）、华为、小米、OPPO、vivo 及 Outlook；
- **上课前 20 分钟静默触发震动提醒**，并在手表/手环端同步振动推送。

### 4. 📢 云端统计与通知推送（可选配套后端）
- 统计全校学生使用活跃度指标（去重总学生量、今日活跃、近 7 日留存）；
- 支持发布版本更新推送与启动时强提醒弹窗；
- 支持 Azure MySQL 云数据库与内置 SQLite 零配置双模式自动保底。

---

## 🔬 核心技术与逆向原理

### 1. 统一身份认证中心 (IDS) 动态加盐协议

长安大学统一身份认证系统采用基于 Web Flow 的安全验证机制：

```text
[客户端] ─── 1. GET /authserver/login ────────────────────────► [CHD IDS 统一认证]
         ◄─── 返回 HTML 页面 (携带 execution、salt、pwdEncryptSalt) ─┘

[客户端] ─── 2. 提取 salt，使用 AES-128-CBC 动态加盐加密密码 ───┐
         ┌──────────────────────────────────────────────────┘
         ▼
[客户端] ─── 3. POST /authserver/login (加密密文 + execution) ─► [CHD IDS 统一认证]
         ◄─── 302 重定向并下发 CASTGC Session Cookie ────────┘
```

- **加密算法细节**：
  - 算法模式：`AES-128-CBC`；
  - 填充方式：`PKCS7Padding`；
  - 密钥 (Key) 与 初始向量 (IV)：将服务端 HTML 表单隐藏域中返回的 `pwdEncryptSalt`（16 位动态随机盐）转换为 UTF-8 字节作为 Key 与 IV；
  - Cookie 净化：自动拦截修复部分安卓设备因 `SameSite=no_restriction` 非标头导致的 Cookie 丢失问题。

---

### 2. 教务综合管理系统 (EAMS) 数据抓取与解析机制

长安大学本科教务系统采用 EAMS 框架，其课表页面并非通过标准 JSON API 异步获取，而是由后端将排课调度引擎的数据直接以内联 JavaScript 脚本形式渲染在 HTML 中：

```javascript
// 教务系统核心调度数据结构
var act = new TaskActivity(actTeacherId, actTeacherName, courseId, courseName, roomId, roomName, weekBitmap);
var teachers = ([{id: 1078, name: "任朝霞", lab: false}, ...]);
table0.marshalTable(startWeek, endWeek, ...);
```

- **真实教师数据抽取**：
  - 现象：教务总表第一行对部分课程粗暴标注为“待定”，直接读取表格单元格会丢失教师；
  - 解法：解析器使用正则提取内联脚本中的 `teachers = ([...])` JSON 数组，将其与课程任务 ID 映射关联，实现真实教师全量找回；
- **周次位图掩码解码 (Week Bitmap)**：
  - 课程所覆盖的周次由形如 `01111111000000000000` 的二进制字符串标识；
  - 索引第 $N$ 位为 `1` 即代表第 $N$ 周有课；解析器通过位运算将位图映射为 `1-8周`、`9-16周` 或单双周范围。
- **抗截断排版算法**：
  - 移动端排版引擎在遇到无空格的连续英数代号（如 `WX2304`）时，无法自行断词，容易打上省略号 `WX23…`；
  - 本项目自研排版预处理算法，在英文字母与数字间插入零宽排版断字符（`\u200B`），允许布局引擎在列宽不足时自适应优雅换行（第 1 行 `WX`，第 2 行 `2304`），实现字符 100% 完整可视。

---

### 3. iCalendar (.ics) 日历同步与防迟到提醒算法

系统严格遵循 RFC 5545 协议生成日历事件：
- 长安大学作息基准（第一大节 08:00~09:40，第二大节 10:00~11:40，第三大节 14:00~15:40，第四大节 16:00~17:40，晚间大节 19:00~20:40）；
- 根据学期开学周首日日期（如第一周周一为 `2026-08-31`），结合课程位图计算出每一节课精确的公历起始与结束时间戳；
- 注入 `VALARM` 模块（`TRIGGER:-PT20M`），支持移动端和智能手表准时弹出提前 20 分钟的上课教室震动提醒。

---

### 4. 云端轻量遥测与全校通知分发服务

- 基于 **Python 3.10+ & FastAPI** 异步高并发框架构建；
- 采用 **双模容灾存储**：配置了云端 MySQL 时直连云数据库，未配置或云端故障时无缝降级为本地 SQLite（`data/analytics.db`）；
- 具备去重留存分析看板，并提供在线发布公告表单，App 启动时静默拉取并按需展示居中弹窗卡片。

---

## 📱 客户端与产品形态

本项目提供了两套互相补充的客户端方案：

| 客户端形态 | 技术栈 | 核心优势 | 适用场景 |
| :--- | :--- | :--- | :--- |
| **纯原生安卓 App** (`chd_app/`) | Flutter 3.x / Dart / Material 3 | 运行极度流畅、支持手势切周、完整本地沙盒加密、内置云端服务支持 | 安卓手机主力日常使用，桌面图标秒开 |
| **现代化 Web 端** (`app.py` + `static/`) | Python / Vanilla HTML5 & CSS3 | 零依赖纯净前端、支持局域网多端共享、一键生成并下载 `.ics` 系统日历 | 电脑桌面端宽屏查看、批量导出日历至 iPhone/Mac |

---

## 📂 仓库项目结构

```text
chd课表/
├── chd_app/                  # 📱 纯原生 Flutter 安卓应用源码
│   ├── android/              # 原生 Android 工程与定制应用图标
│   ├── lib/                  # Flutter Dart 业务核心
│   │   ├── models/           # 课程、成绩、学籍、通知等数据模型
│   │   ├── screens/          # 课表主界面、成绩走势、学生档案、登录界面
│   │   ├── services/         # IDS认证、EAMS解析、本地加密沙盒、云端心跳
│   │   ├── theme/            # 浅色模式现代化调色板与排版设计系统
│   │   └── widgets/          # 课程卡片、防截断排版、弹窗详情、成绩徽章
│   └── pubspec.yaml          # Flutter 依赖声明
│
├── server/                   # ☁️ 配套云端统计与公告后台服务
│   ├── main.py               # FastAPI 服务端、管理看板与双数据库容灾
│   ├── requirements.txt      # 后端核心依赖
│   ├── start.sh              # Ubuntu/Linux 一键后台启动脚本
│   ├── Dockerfile            # 容器化镜像构建配置
│   ├── docker-compose.yml    # Docker Compose 编排文件
│   └── README.md             # 独立服务端部署与运维完整指南
│
├── static/                   # 🌐 Web 版前端界面资产
│   ├── css/style.css         # Bento 现代化毛玻璃设计样式
│   ├── js/app.js             # Web 端交互、课表矩阵绘制与数据缓存
│   └── index.html            # Web 版响应式单页应用
│
├── app.py                    # 🐍 Web 版本地后端服务
├── chd_auth.py               # 🔐 Python 版统一身份认证客户端
├── chd_eams.py               # 📊 Python 版教务系统排课逆向解析器
├── calendar_export.py        # 📅 iCalendar (.ics) 日历生成算法
├── Agent.md                  # 🤖 AI 智能体与未来维护者架构说明书
└── .gitignore                # 严格的脱敏与缓存忽略过滤规则
```

---

## 🚀 快速上手与运行

### 1. 运行原生安卓 App (`chd_app`)
确保电脑已安装好 Flutter SDK 与 Android 编译环境：
```bash
cd chd_app
flutter pub get
flutter run
```
若需生成正式 Release APK：
```bash
flutter build apk --release
```

### 2. 运行 Web 响应式版本
在本地 Python 环境下运行：
```bash
pip install -r requirements.txt
python app.py
```
在浏览器中打开 `http://localhost:8000` 即可使用。

### 3. 部署云端统计与公告后台
请详细参阅专属文档：👉 **[`server/README.md`](file:///f:/files/programs/课表/chd课表/server/README.md)**。

---

## 🔒 隐私与安全性保障

- **密码不落盘**：学号与认证密码仅保存在用户本地移动设备沙盒中（AES 加密），**绝不上报任何外部云端服务器**；
- **纯私有通信**：应用直接与学校官方服务器（`ids.chd.edu.cn` 和 `bkjw.chd.edu.cn`）通过安全协议交换数据；
- **全量安全脱敏**：开源代码库中杜绝任何真实个人学号、教务密码与数据库生产凭证，保护长大学子隐私安全。

---

## 📄 开源许可

本项目遵循 [MIT License](LICENSE) 协议开源。欢迎广大长大学子提交 PR、提出 Issue 或共同维护升级！
