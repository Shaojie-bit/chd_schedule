/**
 * CHD 课表中心 - 核心交互与状态逻辑
 * Vanilla JavaScript (Zero Dependencies, Ultra Fast)
 */

// 作息时间表映射
const PERIOD_TIMES = [
  { num: 1, start: "08:00", end: "08:45" },
  { num: 2, start: "08:50", end: "09:35" },
  { num: 3, start: "10:05", end: "10:50" },
  { num: 4, start: "10:55", end: "11:40" },
  { num: 5, start: "14:00", end: "14:45" },
  { num: 6, start: "14:50", end: "15:35" },
  { num: 7, start: "16:00", end: "16:45" },
  { num: 8, start: "16:50", end: "17:35" },
  { num: 9, start: "19:00", end: "19:45" },
  { num: 10, start: "19:50", end: "20:35" },
  { num: 11, start: "20:40", end: "21:25" }
];

const WEEKDAY_NAMES = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];

// 全局应用状态
const state = {
  token: localStorage.getItem('chd_token') || '',
  user: null,
  semesters: [],
  currentSemesterId: '262',
  selectedWeek: 1,
  currentTeachingWeek: 1, // 真实当前教学周
  todayDayOfWeek: 0,      // 0=周一, 6=周日
  showNonCurrentWeeks: true,
  activeView: 'table',    // 'table' | 'list'
  courseData: null
};

// 默认输入为空，用户手动输入各自学号密码
const DEFAULT_USER = "";
const DEFAULT_PASS = "";

document.addEventListener('DOMContentLoaded', () => {
  initAuthForm();
  initEventListeners();
  calculateTodayInfo();
  checkExistingSession();
});

/* =========================================================
   今日日期与教学周计算
   ========================================================= */
function calculateTodayInfo() {
  const now = new Date();
  const day = now.getDay(); // 0 is Sunday
  state.todayDayOfWeek = day === 0 ? 6 : day - 1; // 转换为 0=周一, 6=周日

  const weekDayStr = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"][day];
  const dateStr = `${now.getFullYear()}年${now.getMonth() + 1}月${now.getDate()}日 ${weekDayStr}`;
  
  // 假设 2026-08-31 为第一周周一
  const termStart = new Date(2026, 7, 31); // 2026-08-31
  const diffDays = Math.floor((now - termStart) / (1000 * 60 * 60 * 24));
  let calcWeek = Math.floor(diffDays / 7) + 1;
  if (calcWeek < 1) calcWeek = 1;
  if (calcWeek > 20) calcWeek = 20;

  state.currentTeachingWeek = calcWeek;
  state.selectedWeek = calcWeek;

  const dateElem = document.getElementById('currentDateText');
  if (dateElem) dateElem.textContent = dateStr;

  const weekTag = document.getElementById('currentWeekTag');
  if (weekTag) weekTag.textContent = `教学周第 ${calcWeek} 周`;
}

/* =========================================================
   登录与身份认证
   ========================================================= */
function initAuthForm() {
  const uInput = document.getElementById('usernameInput');
  const pInput = document.getElementById('passwordInput');
  
  // 填充已保存的凭证或默认凭据
  const savedUser = localStorage.getItem('chd_saved_user') || DEFAULT_USER;
  const savedPass = localStorage.getItem('chd_saved_pass') || DEFAULT_PASS;
  
  if (uInput && !uInput.value) uInput.value = savedUser;
  if (pInput && !pInput.value) pInput.value = savedPass;

  // 密码显示/隐藏开关
  const pwdToggle = document.getElementById('pwdToggle');
  if (pwdToggle) {
    pwdToggle.addEventListener('click', () => {
      const type = pInput.getAttribute('type') === 'password' ? 'text' : 'password';
      pInput.setAttribute('type', type);
    });
  }

  // 登录按钮提交
  const loginForm = document.getElementById('loginForm');
  if (loginForm) {
    loginForm.addEventListener('submit', handleLoginSubmit);
  }
}

async function checkExistingSession() {
  // 如果本地有完整课表缓存，先快速渲染缓存实现秒开
  const cachedData = localStorage.getItem('chd_cache_course_data');
  const cachedUser = localStorage.getItem('chd_cache_user');
  
  if (cachedData && cachedUser) {
    try {
      state.user = JSON.parse(cachedUser);
      state.courseData = JSON.parse(cachedData);
      renderUserProfile();
      renderSemestersDropdown([
        { id: "262", name: "2026-2027学年1学期", is_current: true },
        { id: "242", name: "2025-2026学年2学期", is_current: false }
      ]);
      renderWeekChips(state.courseData.max_weeks || 18);
      renderTimetable();
      renderTodayHero();
      renderListView();
      hideLoginOverlay();
    } catch (e) {
      console.warn("缓存数据解析失败:", e);
    }
  }

  // 尝试静默自动登录刷新最新数据
  if (localStorage.getItem('chd_auto_login') === 'true') {
    const u = localStorage.getItem('chd_saved_user');
    const p = localStorage.getItem('chd_saved_pass');
    if (u && p) {
      doLogin(u, p, "", true);
    }
  }
}

async function handleLoginSubmit(e) {
  if (e) e.preventDefault();
  const username = document.getElementById('usernameInput').value.trim();
  const password = document.getElementById('passwordInput').value;
  const captcha = document.getElementById('captchaInput')?.value.trim() || "";

  if (!username || !password) {
    showLoginError("请输入学号和密码");
    return;
  }

  await doLogin(username, password, captcha, false);
}

async function doLogin(username, password, captcha, isSilent = false) {
  const loginBtn = document.getElementById('loginBtn');
  const btnText = loginBtn?.querySelector('.btn-text');
  const btnSpinner = loginBtn?.querySelector('.btn-spinner');
  const errBanner = document.getElementById('loginError');

  if (!isSilent && loginBtn) {
    loginBtn.disabled = true;
    if (btnText) btnText.style.display = 'none';
    if (btnSpinner) btnSpinner.style.display = 'block';
  }
  if (errBanner) errBanner.style.display = 'none';

  try {
    const res = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password, captcha })
    });
    const data = await res.json();

    if (!data.success) {
      if (data.need_captcha) {
        showCaptchaInput(username);
      }
      showLoginError(data.message || "登录失败，请检查账号密码");
      return;
    }

    // 登录成功
    state.token = data.token;
    state.user = data.user;
    state.semesters = data.semesters || [];
    state.currentSemesterId = data.current_semester_id || '262';
    state.courseData = data.course_data;

    localStorage.setItem('chd_token', data.token);
    localStorage.setItem('chd_cache_user', JSON.stringify(data.user));
    localStorage.setItem('chd_cache_course_data', JSON.stringify(data.course_data));

    // 记住凭据
    const rememberMe = document.getElementById('rememberMe')?.checked;
    if (rememberMe) {
      localStorage.setItem('chd_saved_user', username);
      localStorage.setItem('chd_saved_pass', password);
      localStorage.setItem('chd_auto_login', 'true');
    } else {
      localStorage.removeItem('chd_saved_user');
      localStorage.removeItem('chd_saved_pass');
      localStorage.removeItem('chd_auto_login');
    }

    // 渲染全屏界面
    hideLoginOverlay();
    renderUserProfile();
    renderSemestersDropdown(state.semesters);
    renderWeekChips(state.courseData?.max_weeks || 18);
    renderTimetable();
    renderTodayHero();
    renderListView();

  } catch (err) {
    if (!isSilent) {
      showLoginError("网络连接失败，请确认服务已启动");
    }
  } finally {
    if (loginBtn) {
      loginBtn.disabled = false;
      if (btnText) btnText.style.display = 'inline';
      if (btnSpinner) btnSpinner.style.display = 'none';
    }
  }
}

function showLoginError(msg) {
  const errBanner = document.getElementById('loginError');
  if (errBanner) {
    errBanner.textContent = msg;
    errBanner.style.display = 'block';
  }
}

async function showCaptchaInput(username) {
  const captchaGroup = document.getElementById('captchaGroup');
  const captchaImg = document.getElementById('captchaImg');
  if (captchaGroup) captchaGroup.style.display = 'block';

  try {
    const res = await fetch(`/api/captcha?username=${encodeURIComponent(username)}`);
    const data = await res.json();
    if (data.image && captchaImg) {
      captchaImg.src = `data:image/jpeg;base64,${data.image}`;
      captchaImg.onclick = () => showCaptchaInput(username);
    }
  } catch (e) {
    console.error("加载验证码失败:", e);
  }
}

function hideLoginOverlay() {
  const overlay = document.getElementById('loginOverlay');
  const app = document.getElementById('appContainer');
  if (overlay) overlay.style.display = 'none';
  if (app) app.style.display = 'block';
}

function showLoginOverlay() {
  const overlay = document.getElementById('loginOverlay');
  const app = document.getElementById('appContainer');
  if (overlay) overlay.style.display = 'flex';
  if (app) app.style.display = 'none';
}

/* =========================================================
   渲染逻辑 (User, Semesters, Week Chips)
   ========================================================= */
function renderUserProfile() {
  if (!state.user) return;
  const nameDisplay = document.getElementById('userNameDisplay');
  const majorDisplay = document.getElementById('userMajorDisplay');
  const avatar = document.getElementById('userAvatar');

  if (nameDisplay) nameDisplay.textContent = state.user.name || "同学";
  if (majorDisplay) majorDisplay.textContent = `${state.user.major || ''} ${state.user.student_id || ''}`.trim();
  if (avatar) avatar.textContent = (state.user.name || "学").charAt(0);
}

function renderSemestersDropdown(semesters) {
  const select = document.getElementById('semesterSelect');
  if (!select) return;
  select.innerHTML = '';

  semesters.forEach(sem => {
    const opt = document.createElement('option');
    opt.value = sem.id;
    opt.textContent = sem.name;
    if (sem.id === state.currentSemesterId) opt.selected = true;
    select.appendChild(opt);
  });

  select.onchange = async (e) => {
    await switchSemester(e.target.value);
  };
}

async function switchSemester(semesterId) {
  state.currentSemesterId = semesterId;
  try {
    const res = await fetch(`/api/schedule?semester_id=${semesterId}`, {
      headers: { 'X-Auth-Token': state.token }
    });
    const data = await res.json();
    state.courseData = data;
    renderWeekChips(data.max_weeks || 18);
    renderTimetable();
    renderTodayHero();
    renderListView();
  } catch (e) {
    alert("切换学期失败: " + e.message);
  }
}

function renderWeekChips(maxWeeks) {
  const container = document.getElementById('weekChipsScroll');
  if (!container) return;
  container.innerHTML = '';

  for (let w = 1; w <= maxWeeks; w++) {
    const chip = document.createElement('div');
    chip.className = `week-chip ${w === state.selectedWeek ? 'active' : ''} ${w === state.currentTeachingWeek ? 'is-today' : ''}`;
    chip.textContent = `第${w}周`;
    chip.onclick = () => {
      state.selectedWeek = w;
      updateWeekChipsActive();
      renderTimetable();
      renderTodayHero();
    };
    container.appendChild(chip);
  }
}

function updateWeekChipsActive() {
  const chips = document.querySelectorAll('.week-chip');
  chips.forEach((c, idx) => {
    if (idx + 1 === state.selectedWeek) {
      c.classList.add('active');
      c.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
    } else {
      c.classList.remove('active');
    }
  });
}

/* =========================================================
   今日待上课程 (Hero Banner)
   ========================================================= */
function renderTodayHero() {
  const container = document.getElementById('todayCardsContainer');
  if (!container || !state.courseData) return;

  const courses = state.courseData.courses || [];
  // 筛选出当天、当前选定周次的课程
  const todayCourses = courses.filter(c => 
    c.day === state.todayDayOfWeek && c.weeks.includes(state.selectedWeek)
  ).sort((a, b) => a.start_period - b.start_period);

  container.innerHTML = '';

  if (todayCourses.length === 0) {
    container.innerHTML = `
      <div class="today-empty-badge">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"></circle>
          <path d="m9 12 2 2 4-4"></path>
        </svg>
        <span>今日暂无课程安排，放松一下吧！</span>
      </div>
    `;
    return;
  }

  todayCourses.forEach((c, idx) => {
    const pill = document.createElement('div');
    pill.className = `today-course-pill ${idx === 0 ? 'next-up' : ''}`;
    pill.innerHTML = `
      <div class="pill-icon" style="background:${c.color.bg}; color:${c.color.text}; border: 1px solid ${c.color.border};">
        ${c.start_period}节
      </div>
      <div class="pill-info">
        <span class="pill-title">${c.course_name}</span>
        <div class="pill-details">
          <span>📍 ${c.room}</span>
          <span>⏰ ${c.period_desc}</span>
        </div>
      </div>
    `;
    pill.onclick = () => openCourseModal(c);
    container.appendChild(pill);
  });
}

/* =========================================================
   渲染主课表矩阵 (Timetable Grid)
   ========================================================= */
function renderTimetable() {
  const grid = document.getElementById('timetableGrid');
  if (!grid || !state.courseData) return;

  grid.innerHTML = '';

  // 1. 渲染顶部左上角表头
  const corner = document.createElement('div');
  corner.className = 'grid-header-cell';
  corner.innerHTML = '<span>节次</span><span class="header-date">时间</span>';
  grid.appendChild(corner);

  // 2. 渲染周一至周日表头
  WEEKDAY_NAMES.forEach((name, dayIndex) => {
    const header = document.createElement('div');
    const isToday = dayIndex === state.todayDayOfWeek;
    header.className = `grid-header-cell ${isToday ? 'is-today' : ''}`;
    header.innerHTML = `
      <span>${name}</span>
      <span class="header-date">${isToday ? '今日' : ''}</span>
    `;
    grid.appendChild(header);
  });

  // 3. 渲染左侧 1~11 节次及空白网格
  for (let p = 1; p <= 11; p++) {
    const timeInfo = PERIOD_TIMES[p - 1];
    
    // 节次时间单元格 (第1列)
    const pCell = document.createElement('div');
    pCell.className = 'grid-period-cell';
    pCell.style.gridColumn = '1';
    pCell.style.gridRow = `${p + 1}`;
    pCell.innerHTML = `
      <span class="period-num">${p}</span>
      <span class="period-time">${timeInfo.start}<br>${timeInfo.end}</span>
    `;
    grid.appendChild(pCell);

    // 7 个星期的空白背景格子 (列 2~8)
    for (let d = 0; d < 7; d++) {
      const empty = document.createElement('div');
      empty.className = 'grid-empty-cell';
      empty.style.gridColumn = `${d + 2}`;
      empty.style.gridRow = `${p + 1}`;
      grid.appendChild(empty);
    }
  }

  // 4. 渲染课程卡片
  const courses = state.courseData.courses || [];
  
  courses.forEach(course => {
    const isCurrentWeek = course.weeks.includes(state.selectedWeek);
    
    // 如果不处于当前选定周，且用户关闭了“显示非本周课程”，则隐藏
    if (!isCurrentWeek && !state.showNonCurrentWeeks) {
      return;
    }

    const card = document.createElement('div');
    card.className = `course-card ${!isCurrentWeek ? 'not-this-week' : ''}`;
    card.style.gridColumn = `${course.day + 2}`;
    card.style.gridRow = `${course.start_period + 1} / span ${course.period_span}`;
    
    // 应用柔和渐变与专属色彩
    card.style.background = course.color.bg;
    card.style.borderColor = course.color.border;
    card.style.color = course.color.text;

    card.innerHTML = `
      <div class="course-card-title">${course.course_name}</div>
      <div class="course-card-meta">
        <div class="course-card-room">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"></path>
            <circle cx="12" cy="10" r="3"></circle>
          </svg>
          <span>${course.room}</span>
        </div>
        <div class="course-card-teacher">👨‍🏫 ${course.teachers}</div>
        <div class="course-card-weeks">${course.weeks_str}${!isCurrentWeek ? ' (非本周)' : ''}</div>
      </div>
    `;

    card.onclick = (e) => {
      e.stopPropagation();
      openCourseModal(course);
    };

    grid.appendChild(card);
  });
}

/* =========================================================
   渲染课程清单视图 (List View)
   ========================================================= */
function renderListView() {
  const container = document.getElementById('coursesCardsGrid');
  const countTag = document.getElementById('coursesCountTag');
  if (!container || !state.courseData) return;

  const courses = state.courseData.courses || [];
  // 根据课程名称去重
  const uniqueCourses = [];
  const nameSet = new Set();
  courses.forEach(c => {
    if (!nameSet.has(c.course_name)) {
      nameSet.add(c.course_name);
      uniqueCourses.push(c);
    }
  });

  if (countTag) countTag.textContent = `共 ${uniqueCourses.length} 门课程`;
  container.innerHTML = '';

  uniqueCourses.forEach(c => {
    const item = document.createElement('div');
    item.className = 'course-list-item';
    item.innerHTML = `
      <div class="item-head">
        <div class="item-title" style="color: ${c.color.text};">${c.course_name}</div>
        <span class="item-category">${c.category}</span>
      </div>
      <div class="item-details">
        <div><strong>课程代码:</strong> ${c.course_code || '未录入'}</div>
        <div><strong>主讲教师:</strong> ${c.teachers}</div>
        <div><strong>上课地点:</strong> ${c.room}</div>
        <div><strong>周次时间:</strong> ${c.weeks_str} · ${c.day_name} ${c.period_desc}</div>
        <div><strong>学分:</strong> ${c.credits} 学分</div>
      </div>
    `;
    item.onclick = () => openCourseModal(c);
    container.appendChild(item);
  });
}

/* =========================================================
   模态弹窗与详情展示 (Course Modal, Grades, Export)
   ========================================================= */
function openCourseModal(course) {
  const modal = document.getElementById('courseModal');
  if (!modal) return;

  document.getElementById('modalCourseName').textContent = course.course_name;
  document.getElementById('modalCourseCode').textContent = course.course_code || course.full_name;
  document.getElementById('modalCourseCategory').textContent = course.category || "课程";
  document.getElementById('modalCourseRoom').textContent = course.room;
  document.getElementById('modalCourseTeachers').textContent = course.teachers;
  document.getElementById('modalCourseTime').textContent = `${course.day_name} ${course.period_desc}`;
  document.getElementById('modalCourseWeeks').textContent = `${course.weeks_str} · ${course.credits} 学分`;

  // 渲染 1~20 周分布点阵
  const weeksGrid = document.getElementById('modalWeeksGrid');
  if (weeksGrid) {
    weeksGrid.innerHTML = '';
    for (let w = 1; w <= 20; w++) {
      const b = document.createElement('div');
      const active = course.weeks.includes(w);
      b.className = `week-cell-badge ${active ? 'active' : ''}`;
      b.textContent = `${w}`;
      weeksGrid.appendChild(b);
    }
  }

  modal.style.display = 'flex';
}

function closeCourseModal() {
  const modal = document.getElementById('courseModal');
  if (modal) modal.style.display = 'none';
}

let allCourseGrades = [];
let allGradesSummary = [];

async function openGradesModal(forceRefresh = false) {
  const modal = document.getElementById('gradesModal');
  if (!modal) return;
  modal.style.display = 'flex';

  const courseTbody = document.getElementById('gradeCoursesTableBody');
  const summaryTbody = document.getElementById('gradesSummaryTableBody');
  
  if (allCourseGrades.length === 0 || forceRefresh) {
    if (courseTbody) courseTbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 30px;">正在加载每门课程具体成绩数据...</td></tr>';
    if (summaryTbody) summaryTbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding: 30px;">正在加载各学期绩点概览...</td></tr>';

    try {
      const url = forceRefresh ? '/api/grades?force_refresh=true' : '/api/grades';
      const res = await fetch(url, {
        headers: { 'X-Auth-Token': state.token }
      });
      const data = await res.json();
      
      if (data.success) {
        allCourseGrades = data.course_grades || [];
        allGradesSummary = data.summary || [];
        
        // 缓存到本地 localStorage 便于下次秒开
        localStorage.setItem('chd_cache_grades', JSON.stringify(data));

        initGradesUI();
      } else {
        if (courseTbody) courseTbody.innerHTML = `<tr><td colspan="7" style="color:red; text-align:center;">数据获取异常: ${data.error || '请稍后重试'}</td></tr>`;
      }
    } catch (e) {
      // 如果网络请求失败，尝试从本地缓存恢复
      const cached = localStorage.getItem('chd_cache_grades');
      if (cached) {
        const data = JSON.parse(cached);
        allCourseGrades = data.course_grades || [];
        allGradesSummary = data.summary || [];
        initGradesUI();
      } else {
        if (courseTbody) courseTbody.innerHTML = `<tr><td colspan="7" style="color:red; text-align:center;">成绩加载失败: ${e.message}</td></tr>`;
      }
    }
  } else {
    initGradesUI();
  }
}

function initGradesUI() {
  // 1. 最新 GPA 顶部高亮
  if (allGradesSummary.length > 0) {
    const latest = allGradesSummary[0];
    const gpaValEl = document.getElementById('latestGpaVal');
    const gpaSubEl = document.getElementById('gpaSummarySubtitle');
    if (gpaValEl) gpaValEl.textContent = latest.gpa || "3.72";
    if (gpaSubEl) gpaSubEl.textContent = `最新学期（${latest.academic_year} 第${latest.term}学期）修读 ${latest.course_count} 门，共 ${latest.total_credits} 学分，平均绩点 ${latest.gpa}`;
  }

  // 2. 学期筛选下拉框去重填充
  const select = document.getElementById('gradeSemesterSelect');
  if (select) {
    const semSet = new Map();
    allCourseGrades.forEach(c => {
      if (c.semester_id && !semSet.has(c.semester_id)) {
        semSet.set(c.semester_id, c.semester_name || c.term);
      }
    });

    select.innerHTML = '<option value="all">全部学期课程</option>';
    semSet.forEach((name, id) => {
      const opt = document.createElement('option');
      opt.value = id;
      opt.textContent = name;
      select.appendChild(opt);
    });

    select.onchange = filterAndRenderCourseGrades;
  }

  // 3. 绑定搜索框
  const searchInput = document.getElementById('gradeSearchInput');
  if (searchInput) {
    searchInput.oninput = filterAndRenderCourseGrades;
  }

  // 4. 渲染两张表格
  filterAndRenderCourseGrades();
  renderGradesSummaryTable(allGradesSummary);

  // 5. 绑定标签页切换
  setupGradeTabs();
}

function setupGradeTabs() {
  const tabCoursesBtn = document.getElementById('tabCoursesBtn');
  const tabSummaryBtn = document.getElementById('tabSummaryBtn');
  const coursesPanel = document.getElementById('gradeCoursesPanel');
  const summaryPanel = document.getElementById('gradeSummaryPanel');

  if (tabCoursesBtn && tabSummaryBtn && coursesPanel && summaryPanel) {
    tabCoursesBtn.onclick = () => {
      tabCoursesBtn.classList.add('active');
      tabSummaryBtn.classList.remove('active');
      coursesPanel.style.display = 'block';
      summaryPanel.style.display = 'none';
    };

    tabSummaryBtn.onclick = () => {
      tabSummaryBtn.classList.add('active');
      tabCoursesBtn.classList.remove('active');
      coursesPanel.style.display = 'none';
      summaryPanel.style.display = 'block';
    };
  }

  const refreshBtn = document.getElementById('btnRefreshGrades');
  if (refreshBtn) {
    refreshBtn.onclick = () => openGradesModal(true);
  }
}

function filterAndRenderCourseGrades() {
  const selectVal = document.getElementById('gradeSemesterSelect')?.value || 'all';
  const query = (document.getElementById('gradeSearchInput')?.value || '').trim().toLowerCase();

  const filtered = allCourseGrades.filter(c => {
    const matchSem = (selectVal === 'all' || c.semester_id === selectVal);
    const matchQuery = !query || c.course_name.toLowerCase().includes(query) || (c.category && c.category.toLowerCase().includes(query));
    return matchSem && matchQuery;
  });

  const countBadge = document.getElementById('gradeCourseCountBadge');
  if (countBadge) {
    countBadge.textContent = `共 ${filtered.length} 门课程`;
  }

  const tbody = document.getElementById('gradeCoursesTableBody');
  if (!tbody) return;
  tbody.innerHTML = '';

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 25px; color:var(--text-muted);">暂无匹配课程成绩</td></tr>';
    return;
  }

  filtered.forEach(c => {
    const tr = document.createElement('tr');
    
    // 成绩等级与色彩徽章判定
    let badgeClass = 'good';
    const s = String(c.score || '').trim();
    const num = parseFloat(s);
    if (s === '优秀' || s === '优' || (!isNaN(num) && num >= 90)) {
      badgeClass = 'excellent';
    } else if (s === '良好' || s === '良' || (!isNaN(num) && num >= 80)) {
      badgeClass = 'good';
    } else if (s === '中等' || s === '中' || (!isNaN(num) && num >= 70)) {
      badgeClass = 'medium';
    } else if (s === '及格' || s === '合格' || (!isNaN(num) && num >= 60)) {
      badgeClass = 'pass';
    } else if (s && s !== '') {
      badgeClass = 'fail';
    }

    tr.innerHTML = `
      <td><small style="color:var(--text-muted);">${c.term}</small></td>
      <td>
        <strong style="color:var(--text-primary); font-size:0.92rem;">${c.course_name}</strong>
        <div style="font-size:0.75rem; color:var(--text-muted);">${c.course_code || ''}</div>
      </td>
      <td><span class="item-category">${c.category}</span></td>
      <td><strong>${c.credits}</strong></td>
      <td>
        <div style="font-size:0.78rem; line-height:1.3; color:var(--text-secondary);">
          <span>平时: ${c.usual_score || '-'}</span><br>
          <span>期末: ${c.exam_score || '-'}</span>
        </div>
      </td>
      <td><span class="score-badge ${badgeClass}">${c.score || '暂无'}</span></td>
      <td><strong class="gpa-num-tag">${c.gpa || '-'}</strong></td>
    `;
    tbody.appendChild(tr);
  });
}

function renderGradesSummaryTable(summaryList) {
  const tbody = document.getElementById('gradesSummaryTableBody');
  if (!tbody) return;
  tbody.innerHTML = '';

  if (!summaryList || summaryList.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:20px;">暂无学期概览数据</td></tr>';
    return;
  }

  summaryList.forEach(g => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><strong>${g.academic_year}</strong></td>
      <td>第 ${g.term} 学期</td>
      <td>${g.course_count} 门</td>
      <td>${g.total_credits} 学分</td>
      <td><strong style="color:var(--accent-primary); font-size:1.05rem;">${g.gpa}</strong></td>
    `;
    tbody.appendChild(tr);
  });
}

function closeGradesModal() {
  const modal = document.getElementById('gradesModal');
  if (modal) modal.style.display = 'none';
}

function openExportModal() {
  const modal = document.getElementById('exportModal');
  if (modal) modal.style.display = 'flex';
}

function closeExportModal() {
  const modal = document.getElementById('exportModal');
  if (modal) modal.style.display = 'none';
}

function startDownloadIcs() {
  const startDate = document.getElementById('termStartDateInput')?.value || "2026-08-31";
  const url = `/api/export/ics?semester_id=${state.currentSemesterId}&term_start=${startDate}`;
  
  // 使用当前 token 触发下载
  fetch(url, {
    headers: { 'X-Auth-Token': state.token }
  })
  .then(res => res.blob())
  .then(blob => {
    const blobUrl = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = blobUrl;
    a.download = `CHD课表_${state.currentSemesterId}.ics`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.URL.revokeObjectURL(blobUrl);
    closeExportModal();
  })
  .catch(err => {
    alert("生成日历文件失败: " + err.message);
  });
}

/* =========================================================
   事件监听器绑定
   ========================================================= */
function initEventListeners() {
  // 退出登录
  document.getElementById('logoutBtn')?.addEventListener('click', async () => {
    if (confirm("确定要退出当前账号并返回登录页吗？")) {
      localStorage.removeItem('chd_token');
      localStorage.removeItem('chd_auto_login');
      showLoginOverlay();
    }
  });

  // 上一周 / 下一周切换
  document.getElementById('prevWeekBtn')?.addEventListener('click', () => {
    if (state.selectedWeek > 1) {
      state.selectedWeek--;
      updateWeekChipsActive();
      renderTimetable();
      renderTodayHero();
    }
  });

  document.getElementById('nextWeekBtn')?.addEventListener('click', () => {
    const maxW = state.courseData?.max_weeks || 18;
    if (state.selectedWeek < maxW) {
      state.selectedWeek++;
      updateWeekChipsActive();
      renderTimetable();
      renderTodayHero();
    }
  });

  // 视图切换 (周视图 / 列表视图)
  const viewTableBtn = document.getElementById('viewTableBtn');
  const viewListBtn = document.getElementById('viewListBtn');
  const timetableSec = document.getElementById('timetableSection');
  const listViewSec = document.getElementById('listViewSection');

  viewTableBtn?.addEventListener('click', () => {
    viewTableBtn.classList.add('active');
    viewListBtn.classList.remove('active');
    timetableSec.style.display = 'block';
    listViewSec.style.display = 'none';
  });

  viewListBtn?.addEventListener('click', () => {
    viewListBtn.classList.add('active');
    viewTableBtn.classList.remove('active');
    timetableSec.style.display = 'none';
    listViewSec.style.display = 'block';
  });

  // 非本周课程微淡/隐藏开关
  const toggleWeeks = document.getElementById('toggleNonCurrentWeeks');
  toggleWeeks?.addEventListener('change', (e) => {
    state.showNonCurrentWeeks = e.target.checked;
    renderTimetable();
  });

  // 模态弹窗关闭与打开
  document.getElementById('modalCloseBtn')?.addEventListener('click', closeCourseModal);
  document.getElementById('courseModal')?.addEventListener('click', (e) => {
    if (e.target.id === 'courseModal') closeCourseModal();
  });

  document.getElementById('btnGrades')?.addEventListener('click', openGradesModal);
  document.getElementById('gradesCloseBtn')?.addEventListener('click', closeGradesModal);
  document.getElementById('gradesModal')?.addEventListener('click', (e) => {
    if (e.target.id === 'gradesModal') closeGradesModal();
  });

  document.getElementById('btnExportIcs')?.addEventListener('click', openExportModal);
  document.getElementById('exportCloseBtn')?.addEventListener('click', closeExportModal);
  document.getElementById('exportModal')?.addEventListener('click', (e) => {
    if (e.target.id === 'exportModal') closeExportModal();
  });

  document.getElementById('startDownloadIcsBtn')?.addEventListener('click', startDownloadIcs);

  // ESC 键关闭所有弹窗
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      closeCourseModal();
      closeGradesModal();
      closeExportModal();
    }
  });
}
