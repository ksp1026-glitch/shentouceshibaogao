# XSS (存储型 / Stored) — DVWA Low

!!! info "环境信息"

    靶场：DVWA（XAMPP + Apache + MariaDB）
    难度：Low
    地址：`http://localhost/dvwa/vulnerabilities/xss_s/`
    工具：浏览器开发者工具（F12）
    目标：让 payload 存进数据库，并使**所有访客**都中招

---

## 一、漏洞原理

### 这个模块和其他 XSS 的区别

先看三种 XSS 的定位：

| 类型 | 注入点 | payload 存哪 | 影响范围 |
|---|---|---|---|
| **反射型** | URL 参数 | 不存储 | 只有点了链接的人 |
| **DOM 型** | URL 参数（客户端读取） | 不存储 | 只有点了链接的人 |
| **存储型** | 表单输入 | **数据库** | ★ **所有访问该页面的人** |

**存储型的危害最大**，因为它不需要诱导受害者点击特定链接 ——
**payload 被永久保存在服务器上，谁来看谁中招。**

### 这个模块的代码逻辑

DVWA 的留言板（Guestbook）功能：用户提交 Name 和 Message，存进数据库，然后在页面上展示。

**Low 难度的输出逻辑大致是这样：**

```php
// 从数据库读出留言
while ($row = mysqli_fetch_row($result)) {
    $name    = $row[0];
    $comment = $row[1];

    // 直接拼进 HTML，没有任何编码
    $guestbook .= "<div id=\"guestbook_comments\">Name: {$name}<br />"
                . "Message: {$comment}<br /></div>\n";
}
```

**问题**：`$name` 和 `$comment` 从数据库取出来后**原样拼进 HTML**，
浏览器把它当作**标记语言解析** —— 于是 `<img onerror=...>` 这类东西就获得了执行能力。

**注入路径**：

```
用户提交表单 → 存进数据库 → 页面读取 → 未编码输出 → 浏览器解析执行
                 ↑                                          ↓
            攻击者可控                                  代码执行
```

---

## 二、利用过程

### 第 1 步：观察表单结构

打开 `http://localhost/dvwa/vulnerabilities/xss_s/`，页面结构：

```
┌──────────────────────────────────────────┐
│  Name:    [ test          ]              │  ← 默认值 test
│  Message: [ test          ]              │  ← 默认值 test
│           [ Sign Guestbook ]             │
└──────────────────────────────────────────┘

────────────────────────────────────────────
Name: test
Message: test                                ← 已提交的留言（从数据库读出来）
```

**两个输入框都会渲染到页面上**，所以都是注入点。

!!! warning "注意 Message 框有长度限制"

    Message 输入框默认有 `maxlength="50"`。

    **payload 太长会被浏览器截断**，现象是"提交了但没效果"。
    短 payload 不受影响。

### 第 2 步：第一次尝试 —— `<script>` 标签（失败）

提交：

```html
<script>alert(10)</script>
```

**结果**：不弹窗。

**但 F12 → Elements 里能看到这个标签确实插进了 DOM。**

这是一个非常重要的现象，见下一节。

### 第 3 步：换成事件型 payload（成功）

提交：

```html
<img src=x onerror=alert(10)>
```

**结果**：✅ **弹窗**。

**原理**：

```
① 标签被插入 DOM
② 浏览器尝试加载 src="x"
③ 加载失败（x 不是有效地址）
④ 触发 onerror 事件 → 执行 alert(10)
```

**这个链条不依赖浏览器的脚本解析，所以对插入方式不敏感。**

### 第 4 步：持久化验证（关键证据）

存储型 XSS 的核心特征是**持久化**。做了三个验证：

| # | 验证方法 | 结果 | 说明 |
|---|---|---|---|
| 1 | 按 **F5 刷新页面** | ✅ **仍然弹窗** | payload 存在**数据库**里，不是内存 |
| 2 | **换一个浏览器**打开同一 URL | ✅ **照样弹窗** | 影响**所有访客**，不只提交者 |
| 3 | F12 → Network → Response | ✅ **响应正文里有 payload** | 服务器主动输出了它 |

**第 2 条是存储型危害最大的直接证据** —— 攻击者只提交一次，之后**每个访问者都会中招**。

**第 3 条是"后端过滤是否有效"的判据**，见下一节对比。

---

## 三、三个必须理解的知识点

### 知识点 1：为什么 `<script>` 不执行，而 `onerror` 会

这是**浏览器规范明确规定的行为**，不是偶然：

| 插入方式 | `<script>` 会执行？ | `onerror` 会触发？ |
|---|---|---|
| `document.write()` | ✅ 会 | ✅ 会 |
| **`innerHTML`** | ❌ **不会** | ✅ **会** |

**HTML5 规范规定：通过 `innerHTML` 插入的 `<script>` 不会执行。**

这是浏览器的安全设计 —— 防止"用 JS 拼字符串就直接获得代码执行"。

**但事件属性不受这个限制** —— 只要标签真的进了 DOM，
`onerror` / `onload` / `onfocus` 这些**事件处理器就会正常触发**。

!!! tip "这就是事件型 payload 更可靠的原因"

    真实渗透里，事件型 payload 用得比 `<script>` 多得多，
    因为它**对不同插入方式的适应性更好**。

    常见的事件型 payload：

    ```html
    <img src=x onerror=alert(1)>
    <svg onload=alert(1)>
    <input autofocus onfocus=alert(1)>
    <details open ontoggle=alert(1)>
    ```

**对照实验**：同样的 `<script>` 在 **XSS (DOM)** 模块里**能执行** ——
因为那边用的是 `document.write()`。**同一个标签、不同 sink，结果不同。**

### 知识点 2：三种 XSS 的对比（基于实测）

这是我打了三个模块后的实测对比：

| | XSS (DOM) | XSS (Stored) |
|---|---|---|
| payload 出现在服务器响应里？ | ❌ **没有** | ✅ **有** |
| 后端过滤（`htmlspecialchars`）有效？ | ❌ **无效** | ✅ **有效** |
| 刷新后还在？ | ❌ 没了 | ✅ **在** |
| 影响范围 | 点了链接的人 | ★ **所有访客** |
| 防护应该加在哪 | **客户端安全 API** | **服务端输出编码** |

**为什么 DOM 型的后端过滤无效**：参数从未被服务器处理，
payload 是浏览器拿到响应之后由 JS 拼进 DOM 的。

**为什么存储型的后端过滤有效**：payload 必须经过服务器输出这一步，
在这里做 HTML 实体编码就能拦住它。

### 知识点 3：存储型的完整攻击场景

```
① 攻击者在留言板提交：<img src=x onerror="恶意JS">
              ↓
② payload 存进数据库
              ↓
③ 任何用户访问留言板
              ↓
④ 服务器把 payload 原样输出到 HTML
              ↓
⑤ 每个访客的浏览器都执行恶意 JS
              ↓
⑥ 恶意 JS 可以：窃取 Cookie、篡改页面、发起请求、键盘记录
```

**不需要诱导任何人点击特定链接** —— 这是它比反射型危险得多的原因。

---

## 四、修复建议

### 方案 1：输出编码（针对存储型的根本解法）

**在输出到 HTML 时做实体编码**：

```php
// PHP
$name    = htmlspecialchars($row[0], ENT_QUOTES, 'UTF-8');
$comment = htmlspecialchars($row[1], ENT_QUOTES, 'UTF-8');
```

**效果**：`<img onerror=...>` 会被编码成 `&lt;img onerror=...&gt;`，
浏览器把它当**文字显示**，不解析成标签。

!!! warning "必须在「输出」时编码，不只是「输入」时过滤"

    **输入过滤是可以绕过的** —— 编码、大小写、畸形标签等方式都能突破黑名单。

    **正确做法：数据原样存进数据库，在每次输出时做编码。**

    这也是 DVWA 的 High 难度在做的事。**对比 Low 和 High 的源码差别很明显。**

### 方案 2：内容安全策略（CSP）—— 纵深防御

```http
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'
```

**效果**：即使 payload 成功注入 DOM，浏览器也**拒绝执行内联脚本**。

**注意**：CSP 是**第二道防线**，不能替代输出编码。
而且如果策略里写了 `'unsafe-inline'`，等于没加。

### 方案 3：`HttpOnly` Cookie

```php
session_set_cookie_params(['httponly' => true, 'samesite' => 'Lax']);
```

**作用有限但值得加**：让 JS 读不到 `document.cookie`，
攻击者就无法通过 XSS 窃取会话凭证。

**但它不能阻止 XSS 本身** —— 攻击者仍能在页面上执行任意操作。

### 方案 4：富文本场景用白名单

如果业务**必须**允许用户输入 HTML（如博客、论坛），
不能用简单的 `htmlspecialchars`（会把格式也编码掉）。

**这时要用 HTML 净化库做白名单过滤**：

```php
// 例如 HTMLPurifier
$clean = HTMLPurifier::getInstance()->purify($userHtml);
```

**只允许安全的标签和属性，`onerror` / `onload` / `<script>` 等全部移除。**

### 方案 5：`Content-Type` 与 `X-Content-Type-Options`

```http
Content-Type: text/html; charset=utf-8
X-Content-Type-Options: nosniff
```

**辅助措施**，防止浏览器把内容当成其他类型解析（如 MIME 嗅探攻击）。

---

## 五、Low / Medium / High 的防护演进

| 难度 | 防护手段 | 绕过思路 |
|---|---|---|
| **Low** | 无过滤 | `<img src=x onerror=alert(1)>` 直接成功 |
| **Medium** | `str_replace` 过滤 `<script>` | 换成不用 `<script>` 的事件型 payload 即可（如 `<img onerror>`） |
| **High** | 更强正则、`htmlspecialchars` | 基本被拦住，需要找其他绕过点 |
| **Impossible** | 正确的输出编码 | 无绕过 |

!!! success "我实测的结论"

    我在 **Low** 难度用 `<img src=x onerror=alert(10)>` 成功。

    **注意 Medium 的防护方式很典型**：只过滤了 `<script>` 字符串 ——
    这是一种**黑名单思维**，换成其他标签就绕过了。

    **这正是"输入过滤不可靠"的实际例子。**

---

## 六、总结

| 要点 | 结论 |
|---|---|
| 漏洞本质 | 数据库里的数据被未编码地输出到 HTML，被当作代码执行 |
| 与 DOM 型的核心区别 | **payload 在服务器响应里**，后端过滤**有效** |
| 危害最大的原因 | **持久化 + 影响所有访客** |
| 根本修复 | **输出时做 HTML 实体编码** |
| 纵深防御 | CSP + HttpOnly Cookie |

**我在这关学到的三件事**：

**1. `<script>` 不是万能 payload。**
通过 `innerHTML` 插入的 `<script>` 不会执行 —— 这是规范规定的。
**必须根据 sink 类型选择 payload**，事件型更通用。

**2. 存储型的验证方法很明确。**
"刷新还在 + 换浏览器还弹 + 响应正文里有 payload" —— 这三条同时成立，
才能确认是真正的存储型漏洞。**光看"弹窗了"是不够的。**

**3. 同一个防护措施在不同漏洞上效果完全不同。**
`htmlspecialchars` 对存储型有效，对 DOM 型**完全无效**。
**这说明"我们有输出编码"不能作为笼统的安全结论。**

---

## 参考

- DVWA 官方仓库：<https://github.com/digininja/DVWA>
- OWASP XSS 防护速查表：<https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html>
- HTML5 规范中关于 `innerHTML` 不执行 script 的说明：<https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html>
