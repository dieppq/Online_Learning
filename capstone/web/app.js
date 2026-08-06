const routes = {
  "/": "dashboard",
  "/dashboard": "dashboard",
  "/courses": "courses",
  "/students": "students",
  "/enrollments": "enrollments",
  "/payments": "payments",
  "/notifications": "notifications",
  "/platform": "platform",
};

const api = {
  users: "/api/users",
  courses: "/api/courses",
  progress: "/api/progress/u-1001/c-k8s-ckad",
  payment: "/api/payments/p-1001",
  notifications: "/api/notifications",
  enrolledCourses: "/api/users/u-1001/courses",
};

const state = {
  users: [],
  courses: [],
  enrolledCourses: [],
  progress: null,
  payment: null,
  notifications: [],
  userDetail: null,
  courseDetail: null,
  lastPayload: {},
  endpoints: [
    {
      service: "user-service",
      method: "GET",
      path: "/api/users",
      page: "students",
      browser: true,
      description: "Danh sách user",
    },
    {
      service: "user-service",
      method: "POST",
      path: "/api/users/register",
      page: "students",
      body: { name: "Le Minh", email: "minh@example.com" },
      description: "Đăng ký học viên",
    },
    {
      service: "user-service",
      method: "POST",
      path: "/api/users/login",
      page: "students",
      body: { email: "an@example.com" },
      description: "Đăng nhập mock",
    },
    {
      service: "user-service",
      method: "GET",
      path: "/api/users/u-1001",
      page: "students",
      browser: true,
      description: "Profile user",
    },
    {
      service: "course-service",
      method: "GET",
      path: "/api/courses",
      page: "courses",
      browser: true,
      description: "Catalog khóa học",
    },
    {
      service: "course-service",
      method: "POST",
      path: "/api/courses",
      page: "courses",
      body: { title: "Kubernetes rollout nâng cao" },
      description: "Tạo khóa học",
    },
    {
      service: "course-service",
      method: "GET",
      path: "/api/courses/c-k8s-ckad",
      page: "courses",
      browser: true,
      description: "Chi tiết khóa học",
    },
    {
      service: "course-service",
      method: "POST",
      path: "/api/courses/c-k8s-ckad/lessons",
      page: "courses",
      body: { title: "Debug rollout bằng kubectl" },
      description: "Thêm lesson",
    },
    {
      service: "course-service",
      method: "PUT",
      path: "/api/courses/c-k8s-ckad/lessons/l-01/content",
      page: "courses",
      body: "LearnHub lesson content stored in MinIO.",
      headers: { "Content-Type": "text/plain" },
      description: "Lưu nội dung lesson vào MinIO",
    },
    {
      service: "course-service",
      method: "GET",
      path: "/api/courses/c-k8s-ckad/lessons/l-01/content",
      page: "courses",
      browser: true,
      description: "Đọc nội dung lesson từ MinIO",
    },
    {
      service: "enrollment-service",
      method: "POST",
      path: "/api/enrollments",
      page: "enrollments",
      body: { user_id: "u-1001", course_id: "c-k8s-ckad" },
      description: "Tạo ghi danh",
    },
    {
      service: "enrollment-service",
      method: "GET",
      path: "/api/users/u-1001/courses",
      page: "enrollments",
      browser: true,
      description: "Khóa học của user",
    },
    {
      service: "enrollment-service",
      method: "POST",
      path: "/api/progress",
      page: "enrollments",
      body: { user_id: "u-1001", course_id: "c-k8s-ckad", lesson_id: "l-08" },
      description: "Cập nhật bài học hoàn thành",
    },
    {
      service: "enrollment-service",
      method: "GET",
      path: "/api/progress/u-1001/c-k8s-ckad",
      page: "enrollments",
      browser: true,
      description: "Tiến độ học",
    },
    {
      service: "payment-service",
      method: "POST",
      path: "/api/payments",
      page: "payments",
      body: { user_id: "u-1001", course_id: "c-k8s-ckad" },
      description: "Tạo payment",
    },
    {
      service: "payment-service",
      method: "GET",
      path: "/api/payments/p-1001",
      page: "payments",
      browser: true,
      description: "Chi tiết payment",
    },
    {
      service: "payment-service",
      method: "POST",
      path: "/api/payments/p-1001/confirm",
      page: "payments",
      body: {},
      description: "Confirm payment",
    },
    {
      service: "notification-service",
      method: "GET",
      path: "/api/notifications",
      page: "notifications",
      browser: true,
      description: "Danh sách thông báo",
    },
    {
      service: "notification-service",
      method: "POST",
      path: "/api/notifications/email",
      page: "notifications",
      body: { recipient: "an@example.com" },
      description: "Gửi email mock",
    },
    {
      service: "notification-service",
      method: "POST",
      path: "/api/notifications/course-reminder",
      page: "notifications",
      body: { user_id: "u-1001", course_id: "c-k8s-ckad" },
      description: "Gửi reminder khóa học",
    },
  ],
};

const money = new Intl.NumberFormat("vi-VN", {
  style: "currency",
  currency: "VND",
  maximumFractionDigits: 0,
});

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));

async function request(path, options = {}, viewOptions = {}) {
  const method = options.method || "GET";
  const init = {
    method,
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
  };

  if (options.body !== undefined && method !== "GET") {
    init.body = typeof options.body === "string" ? options.body : JSON.stringify(options.body);
  }

  const response = await fetch(path, init);
  const contentType = response.headers.get("content-type") || "";
  const payload = contentType.includes("application/json")
    ? await response.json()
    : { body: await response.text() };

  const envelope = {
    request: { method, path },
    status: response.status,
    ok: response.ok,
    response: payload,
  };

  state.lastPayload = envelope;
  if (!viewOptions.silent) {
    showResult(viewOptions.resultId || "rawOutput", envelope);
  }

  if (!response.ok) {
    throw new Error(payload.error || `HTTP ${response.status}`);
  }

  return payload;
}

async function loadData() {
  setApiStatus("loading", "Đang tải");

  try {
    const [users, courses, progress, payment, notifications, enrolledCourses] = await Promise.all([
      request(api.users, {}, { silent: true }),
      request(api.courses, {}, { silent: true }),
      request(api.progress, {}, { silent: true }),
      request(api.payment, {}, { silent: true }),
      request(api.notifications, {}, { silent: true }),
      request(api.enrolledCourses, {}, { silent: true }),
    ]);

    state.users = users.items || [];
    state.courses = courses.items || [];
    state.progress = progress;
    state.payment = payment;
    state.notifications = notifications.items || [];
    state.enrolledCourses = enrolledCourses.items || [];

    render();
    showResult("dashboardResult", {
      status: "loaded",
      users: state.users.length,
      courses: state.courses.length,
      notifications: state.notifications.length,
    });
    setApiStatus("ok", "API ready");
  } catch (error) {
    setApiStatus("error", "API lỗi");
    showResult("dashboardResult", { error: error.message });
  }
}

async function loadCourses(resultId = "coursesResult") {
  const payload = await request(api.courses, {}, { resultId });
  state.courses = payload.items || [];
  renderCourses();
  renderStats();
  return payload;
}

async function loadUsers(resultId = "studentsResult") {
  const payload = await request(api.users, {}, { resultId });
  state.users = payload.items || [];
  renderStudents();
  renderStats();
  return payload;
}

async function loadNotifications(resultId = "notificationsResult") {
  const payload = await request(api.notifications, {}, { resultId });
  state.notifications = payload.items || [];
  renderNotifications();
  return payload;
}

function setApiStatus(kind, label) {
  const el = $("#apiStatus");
  if (!el) return;
  el.className = `status-pill ${kind === "ok" ? "ok" : kind === "error" ? "error" : ""}`;
  el.textContent = label;
}

function showResult(resultId, payload) {
  const formatted = JSON.stringify(payload, null, 2);
  const targets = new Set(["rawOutput"]);

  if (resultId) {
    targets.add(resultId);
  }

  targets.forEach((id) => {
    const el = $(`#${id}`);
    if (el) {
      el.textContent = formatted;
    }
  });
}

function render() {
  renderStats();
  renderCourses();
  renderStudents();
  renderProgress();
  renderPayment();
  renderNotifications();
  renderEnrolledCourses();
  renderApiCatalog();
}

function renderStats() {
  setText("studentCount", state.users.length);
  setText("courseCount", state.courses.length);

  const progress = state.progress?.progress_percentage ?? 0;
  setText("progressPercent", `${progress}%`);
  setText("progressDetail", `${state.progress?.completed_lessons ?? 0}/${state.progress?.total_lessons ?? 0} lessons`);
  setText("paymentStatus", state.payment?.status || "-");
}

function renderCourses() {
  const rows = state.courses.map((course) => `
    <tr>
      <td>
        <span class="course-title">${escapeHtml(course.title)}</span>
        <span class="course-id">${escapeHtml(course.id)}</span>
      </td>
      <td>${escapeHtml(course.lessons ?? "-")}</td>
      <td>${course.price ? money.format(course.price) : "-"}</td>
      <td><button class="secondary-button compact-button" type="button" data-action="select-course" data-course="${escapeHtml(course.id)}">Chọn</button></td>
    </tr>
  `);

  $("#courseRows").innerHTML = rows.join("") || emptyRow(4, "Chưa có khóa học");

  $("#courseCards").innerHTML = state.courses.map((course) => `
    <article class="item">
      <h3>${escapeHtml(course.title)}</h3>
      <p>${escapeHtml(course.id)}</p>
      <div class="badge-row">
        <span class="badge">${escapeHtml(course.lessons ?? "-")} lessons</span>
        <span class="badge alt">${course.price ? money.format(course.price) : "draft"}</span>
      </div>
      <button class="secondary-button compact-button" type="button" data-action="select-course" data-course="${escapeHtml(course.id)}">Xem detail</button>
    </article>
  `).join("") || emptyBlock("Chưa có khóa học");
}

function renderCourseDetail() {
  const course = state.courseDetail;
  $("#courseDetails").innerHTML = detailRows({
    id: course?.id,
    title: course?.title,
    description: course?.description,
    lessons: Array.isArray(course?.lessons) ? `${course.lessons.length} lessons` : "-",
  });
}

function renderStudents() {
  $("#studentCards").innerHTML = state.users.map((user) => `
    <article class="item">
      <h3>${escapeHtml(user.name)}</h3>
      <p>${escapeHtml(user.email)}</p>
      <div class="badge-row">
        <span class="badge">${escapeHtml(user.role)}</span>
        <span class="badge alt">${escapeHtml(user.id)}</span>
      </div>
      <button class="secondary-button compact-button" type="button" data-action="select-user" data-user="${escapeHtml(user.id)}">Xem profile</button>
    </article>
  `).join("") || emptyBlock("Chưa có user");

  renderUserDetail();
}

function renderUserDetail() {
  const user = state.userDetail;
  $("#userDetails").innerHTML = detailRows({
    id: user?.id,
    name: user?.name,
    email: user?.email,
    role: user?.role,
  });
}

function renderProgress() {
  const progress = state.progress?.progress_percentage ?? 0;
  $("#progressRing").style.setProperty("--value", progress);
  setText("progressRingText", `${progress}%`);
  setText("progressCopy", `${state.progress?.completed_lessons ?? 0} lessons hoàn thành trên ${state.progress?.total_lessons ?? 0}`);

  $("#progressDetails").innerHTML = detailRows({
    user_id: state.progress?.user_id,
    course_id: state.progress?.course_id,
    completed: state.progress?.completed_lessons,
    total: state.progress?.total_lessons,
    percentage: `${progress}%`,
  });
}

function renderEnrolledCourses() {
  $("#enrolledCourses").innerHTML = state.enrolledCourses.map((course) => `
    <article class="item">
      <h3>${escapeHtml(course.title)}</h3>
      <p>${escapeHtml(course.course_id)}</p>
      <div class="meter" aria-label="Progress">
        <span style="width: ${Number(course.progress) || 0}%"></span>
      </div>
      <div class="badge-row">
        <span class="badge">${escapeHtml(course.progress ?? 0)}%</span>
      </div>
    </article>
  `).join("") || emptyBlock("Chưa có enrollment");
}

function renderPayment() {
  $("#paymentDetails").innerHTML = detailRows({
    id: state.payment?.id,
    user_id: state.payment?.user_id,
    course_id: state.payment?.course_id,
    amount: state.payment?.amount ? money.format(state.payment.amount) : "-",
    currency: state.payment?.currency,
    status: state.payment?.status,
    checkout_url: state.payment?.checkout_url,
  });
}

function renderNotifications() {
  $("#notificationCards").innerHTML = state.notifications.map((item) => `
    <article class="item">
      <h3>${escapeHtml(item.type)}</h3>
      <p>${escapeHtml(item.recipient || item.user_id || "-")}</p>
      <div class="badge-row">
        <span class="badge">${escapeHtml(item.status)}</span>
        <span class="badge alt">${escapeHtml(item.id)}</span>
      </div>
    </article>
  `).join("") || emptyBlock("Chưa có notification");
}

function renderApiCatalog() {
  $("#apiCatalog").innerHTML = state.endpoints.map((endpoint, index) => `
    <article class="item service-row">
      <div class="service-copy">
        <strong>${escapeHtml(endpoint.service)}</strong>
        <span class="endpoint-line">
          <b class="method ${endpoint.method.toLowerCase()}">${endpoint.method}</b>
          ${escapeHtml(endpoint.path)}
        </span>
        <small>${escapeHtml(endpoint.description)}</small>
      </div>
      <div class="api-actions">
        <a class="secondary-button compact-button" href="/${escapeHtml(endpoint.page)}" data-view-link="${escapeHtml(endpoint.page)}">UI</a>
        ${endpoint.browser ? `<a class="secondary-button compact-button" href="${escapeHtml(endpoint.path)}" target="_blank" rel="noopener">Open</a>` : `<span class="badge alt">${escapeHtml(endpoint.method)}</span>`}
        <button class="primary-button compact-button" type="button" data-action="call-api" data-endpoint="${index}">Call</button>
      </div>
    </article>
  `).join("");
}

function detailRows(data) {
  return Object.entries(data).map(([key, value]) => `
    <dt>${escapeHtml(key)}</dt>
    <dd>${escapeHtml(String(value ?? "-"))}</dd>
  `).join("");
}

function emptyRow(columns, text) {
  return `<tr><td colspan="${columns}" class="empty">${escapeHtml(text)}</td></tr>`;
}

function emptyBlock(text) {
  return `<p class="empty">${escapeHtml(text)}</p>`;
}

function setText(id, value) {
  const el = $(`#${id}`);
  if (el) {
    el.textContent = value;
  }
}

function readForm(form) {
  return Object.fromEntries(
    Array.from(new FormData(form).entries()).map(([key, value]) => [key, String(value).trim()])
  );
}

function pathSegment(value, fallback) {
  const raw = String(value || fallback || "").trim();
  return encodeURIComponent(raw);
}

function setAllInputs(name, value) {
  $$(`input[name="${name}"]`).forEach((input) => {
    input.value = value;
  });
}

async function handleSubmit(action, form) {
  const data = readForm(form);

  try {
    setApiStatus("loading", "Đang gọi");

    if (action === "user-detail") {
      const payload = await request(`/api/users/${pathSegment(data.user_id, "u-1001")}`, {}, { resultId: "studentsResult" });
      state.userDetail = payload;
      renderUserDetail();
    }

    if (action === "user-register") {
      const payload = await request("/api/users/register", {
        method: "POST",
        body: { name: data.name, email: data.email },
      }, { resultId: "studentsResult" });
      state.users = [payload, ...state.users.filter((user) => user.id !== payload.id)];
      renderStudents();
      renderStats();
    }

    if (action === "user-login") {
      await request("/api/users/login", {
        method: "POST",
        body: { email: data.email },
      }, { resultId: "studentsResult" });
    }

    if (action === "course-detail") {
      const payload = await request(`/api/courses/${pathSegment(data.course_id, "c-k8s-ckad")}`, {}, { resultId: "coursesResult" });
      state.courseDetail = payload;
      renderCourseDetail();
    }

    if (action === "course-create") {
      const payload = await request("/api/courses", {
        method: "POST",
        body: { title: data.title },
      }, { resultId: "coursesResult" });
      state.courses = [payload, ...state.courses.filter((course) => course.id !== payload.id)];
      renderCourses();
      renderStats();
    }

    if (action === "lesson-create") {
      await request(`/api/courses/${pathSegment(data.course_id, "c-k8s-ckad")}/lessons`, {
        method: "POST",
        body: { title: data.title },
      }, { resultId: "coursesResult" });
    }

    if (action === "lesson-content-upload") {
      await request(`/api/courses/${pathSegment(data.course_id, "c-k8s-ckad")}/lessons/${pathSegment(data.lesson_id, "l-01")}/content`, {
        method: "PUT",
        headers: { "Content-Type": "text/plain" },
        body: data.content,
      }, { resultId: "coursesResult" });
    }

    if (action === "user-courses") {
      const payload = await request(`/api/users/${pathSegment(data.user_id, "u-1001")}/courses`, {}, { resultId: "enrollmentsResult" });
      state.enrolledCourses = payload.items || [];
      renderEnrolledCourses();
    }

    if (action === "enrollment-create") {
      await request("/api/enrollments", {
        method: "POST",
        body: { user_id: data.user_id, course_id: data.course_id },
      }, { resultId: "enrollmentsResult" });
    }

    if (action === "progress-detail") {
      const payload = await request(`/api/progress/${pathSegment(data.user_id, "u-1001")}/${pathSegment(data.course_id, "c-k8s-ckad")}`, {}, { resultId: "enrollmentsResult" });
      state.progress = payload;
      renderProgress();
      renderStats();
    }

    if (action === "progress-update") {
      await request("/api/progress", {
        method: "POST",
        body: { user_id: data.user_id, course_id: data.course_id, lesson_id: data.lesson_id },
      }, { resultId: "enrollmentsResult" });
    }

    if (action === "payment-detail") {
      const payload = await request(`/api/payments/${pathSegment(data.payment_id, "p-1001")}`, {}, { resultId: "paymentsResult" });
      state.payment = payload;
      renderPayment();
      renderStats();
    }

    if (action === "payment-create") {
      const payload = await request("/api/payments", {
        method: "POST",
        body: { user_id: data.user_id, course_id: data.course_id },
      }, { resultId: "paymentsResult" });
      state.payment = payload;
      setAllInputs("payment_id", payload.id);
      renderPayment();
      renderStats();
    }

    if (action === "payment-confirm") {
      const payload = await request(`/api/payments/${pathSegment(data.payment_id, "p-1001")}/confirm`, {
        method: "POST",
        body: {},
      }, { resultId: "paymentsResult" });
      state.payment = { ...state.payment, ...payload };
      renderPayment();
      renderStats();
    }

    if (action === "notification-email") {
      const payload = await request("/api/notifications/email", {
        method: "POST",
        body: { recipient: data.recipient },
      }, { resultId: "notificationsResult" });
      state.notifications = [payload, ...state.notifications];
      renderNotifications();
    }

    if (action === "notification-reminder") {
      const payload = await request("/api/notifications/course-reminder", {
        method: "POST",
        body: { user_id: data.user_id, course_id: data.course_id },
      }, { resultId: "notificationsResult" });
      state.notifications = [payload, ...state.notifications];
      renderNotifications();
    }

    setApiStatus("ok", "Action OK");
  } catch (error) {
    setApiStatus("error", "Action lỗi");
    showResult(resultIdForAction(action), { error: error.message, action });
  }
}

async function handleAction(action, element) {
  try {
    setApiStatus("loading", "Đang gọi");

    if (action === "call-api") {
      const endpoint = state.endpoints[Number(element.dataset.endpoint)];
      await request(endpoint.path, {
        method: endpoint.method,
        body: endpoint.body,
        headers: endpoint.headers,
      }, { resultId: "rawOutput" });
    }

    if (action === "refresh-courses") {
      await loadCourses();
    }

    if (action === "refresh-users") {
      await loadUsers();
    }

    if (action === "refresh-notifications") {
      await loadNotifications();
    }

    if (action === "refresh-platform") {
      renderApiCatalog();
      showResult("rawOutput", { endpoints: state.endpoints.length, ingress: "localhost" });
    }

    if (action === "quick-enroll") {
      await request("/api/enrollments", {
        method: "POST",
        body: { user_id: "u-1001", course_id: "c-k8s-ckad" },
      }, { resultId: "dashboardResult" });
    }

    if (action === "quick-progress") {
      await request("/api/progress", {
        method: "POST",
        body: { user_id: "u-1001", course_id: "c-k8s-ckad", lesson_id: "l-08" },
      }, { resultId: "dashboardResult" });
    }

    if (action === "select-course") {
      const courseID = element.dataset.course;
      setAllInputs("course_id", courseID);
      const payload = await request(`/api/courses/${pathSegment(courseID, "c-k8s-ckad")}`, {}, { resultId: "coursesResult" });
      state.courseDetail = payload;
      renderCourseDetail();
      activateView("courses");
    }

    if (action === "select-user") {
      const userID = element.dataset.user;
      setAllInputs("user_id", userID);
      const payload = await request(`/api/users/${pathSegment(userID, "u-1001")}`, {}, { resultId: "studentsResult" });
      state.userDetail = payload;
      renderUserDetail();
      activateView("students");
    }

    setApiStatus("ok", "Action OK");
  } catch (error) {
    setApiStatus("error", "Action lỗi");
    showResult("rawOutput", { error: error.message, action });
  }
}

function resultIdForAction(action) {
  if (action.startsWith("user-")) return "studentsResult";
  if (action.startsWith("course-") || action.startsWith("lesson-")) return "coursesResult";
  if (action.startsWith("enrollment-") || action.startsWith("progress-") || action === "user-courses") return "enrollmentsResult";
  if (action.startsWith("payment-")) return "paymentsResult";
  if (action.startsWith("notification-")) return "notificationsResult";
  return "rawOutput";
}

function activateView(view, push = true) {
  const nextView = view || "dashboard";
  $$(".nav-item").forEach((item) => item.classList.toggle("active", item.dataset.viewLink === nextView));
  $$(".view").forEach((section) => section.classList.toggle("active", section.id === `view-${nextView}`));

  if (push) {
    const nextPath = nextView === "dashboard" ? "/dashboard" : `/${nextView}`;
    if (window.location.pathname !== nextPath) {
      window.history.pushState({ view: nextView }, "", nextPath);
    }
  }
}

function viewFromPath(pathname) {
  const cleanPath = pathname.replace(/\/+$/, "") || "/";
  return routes[cleanPath] || "dashboard";
}

function bindEvents() {
  document.body.addEventListener("click", (event) => {
    const viewLink = event.target.closest("[data-view-link]");
    if (viewLink) {
      event.preventDefault();
      activateView(viewLink.dataset.viewLink);
      return;
    }

    const button = event.target.closest("[data-action]");
    if (!button) return;
    handleAction(button.dataset.action, button);
  });

  document.body.addEventListener("submit", (event) => {
    const form = event.target.closest("[data-submit-action]");
    if (!form) return;
    event.preventDefault();
    handleSubmit(form.dataset.submitAction, form);
  });

  $("#refreshButton").addEventListener("click", loadData);

  window.addEventListener("popstate", () => {
    activateView(viewFromPath(window.location.pathname), false);
  });
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

bindEvents();
activateView(viewFromPath(window.location.pathname), false);
loadData();
