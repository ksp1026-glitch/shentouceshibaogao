# JavaScript Attacks(客户端 JS 攻击)— DVWA Low

!!! info "环境信息"

    靶场：DVWA（XAMPP + Apache + MariaDB）
    难度：Low
    地址：`http://localhost/dvwa/vulnerabilities/javascript/`
    工具：浏览器开发者工具（F12）、Burp Suite Repeater
    目标：提交一个**非法的 phrase**，让服务器接受

---

## 一、漏洞原理

### 这个模块在说什么

先看一次正常提交的请求：

```http
POST /dvwa/vulnerabilities/javascript/ HTTP/1.1
Host: localhost
Content-Type: application/x-www-form-urlencoded
Cookie: security=low; PHPSESSID=...

token=8b479aefbd90795395b3e7089ae0dc09&phrase=success&send=Submit
```

| 参数 | 含义 |
|---|---|
| `phrase` | 你要提交的短语（下拉框里选 success / failure） |
| `token` | **由页面上的 JavaScript 计算出来的校验值** |
| `send` | 提交按钮 |

**服务器的校验逻辑是**：token 是否等于「根据 phrase 算出来的某个值」。

**"通关"的标准是**：让服务器接受一个**不是它预期值**的 phrase。

### 核心命题：客户端校验等于没有校验

这是本模块最重要的一课：

```
服务器发送 HTML + JavaScript  →  浏览器
                                    ↓
                       攻击者可以做三件事：
                       ① 读 JS 源码（F12）—— 看到完整算法
                       ② 改 JS 逻辑（F12 可编辑）—— 让它永远通过
                       ③ 完全不用 JS，用 Burp 直接构造请求
```

!!! danger "关键认知"

    **服务器不控制客户端。**

    客户端上运行的一切 —— 代码、变量、内存 —— 攻击者都能**读取、修改、绕过**。

    所以任何"在 JavaScript 里做安全校验"的设计，都只是给普通用户设的障碍，
    对攻击者完全透明。

    **安全校验必须发生在服务器端。**

---

## 二、利用过程

### 第 1 步：读客户端源码

打开 F12，在两个地方找 JS 代码：

| 位置 | 找什么 |
|---|---|
| **Sources** 标签 | 独立的 `.js` 文件（如 `javascript.js`） |
| **Elements** 标签 | 页面内联的 `<script>` 代码 |

**Low 难度下的实际源码**（从 F12 → Elements 里直接读到）：

```javascript
/* MD5 实现来自 blueimp/JavaScript-MD5，略去压缩后的代码 */
!function(n){"use strict";/* ...MD5 实现... */}(this);

function rot13(inp) {
    return inp.replace(/[a-zA-Z]/g, function(c){
        return String.fromCharCode((c<="Z"?90:122) >= (c=c.charCodeAt(0)+13) ? c : c-26);
    });
}

function generate_token() {
    var phrase = document.getElementById("phrase").value;
    document.getElementById("token").value = md5(rot13(phrase));
}

generate_token();
```

**关键在这一行：**

```javascript
document.getElementById("token").value = md5(rot13(phrase));
```

**token 的算法完整暴露：`md5(rot13(phrase))`**

!!! quote "这段代码说明了什么"

    整个"安全机制"只有一行，而且**它就写在浏览器的源码里**。

    攻击者不需要逆向、不需要爆破 —— **F12 一看就懂**。

    这就是本模块的核心：**算法本身不弱，弱的是它出现的位置。**

### 第 2 步：理解漏洞点在哪

!!! warning "问题不是「算法太弱」，而是「算法在客户端」"

    即使换成 SHA-256、加盐、加多轮哈希 —— **只要算的地方在浏览器里，攻击者就能读到算法。**

    真正的缺陷是：**token 只证明了「phrase 和 token 在数学上匹配」，**
    **没有证明「这个 token 是由合法页面生成的」。**

**正确设计的对比：**

| 错误做法 | 正确做法 |
|---|---|
| JS 算 token，服务器校验 | 服务器生成带**随机 nonce** 的 token 发给页面 |
| token 只依赖用户输入 | token 绑定**服务端会话状态** |
| 算法写在客户端 | 算法和密钥都在服务端 |

### 第 3 步：构造攻击

**目标**：提交一个非法 phrase（比如 `Hack`），但让服务器接受。

```
① 算 rot13("Hack")   →  "Unpx"
② 算 md5("Unpx")     →  32 位哈希
③ 用这个哈希作为 token，phrase 填 Hack，发出请求
```

**服务器算出的 `md5(rot13("Hack"))` 和你的 token 一致 → 校验通过。**

**服务器无法区分**：这个 token 是页面 JS 算的，还是攻击者自己算的。

### 第 4 步：实操 —— 四种方式

**方式 A：Burp Repeater（最直接）**

1. 正常提交一次 `success`，用 Burp 抓包
2. 右键 → **Send to Repeater**
3. 修改请求体：

```
token=<你算出的 md5>&phrase=Hack&send=Submit
```

4. 点 **Send**，观察响应

**方式 B：F12 Console 直接算（最省事，推荐首选）**

**页面自带的 `md5()` 和 `rot13()` 函数可以直接调用** —— 因为上面那段源码已经在页面里定义了它们。

F12 → **Console** 标签，输入：

```javascript
md5(rot13('Hack'))
```

**直接返回 32 位合法 token。** 连在线 MD5 工具都不用找。

**先验证 rot13 的行为**（理解算法）：

```javascript
['Hack','success','failure'].forEach(p => console.log(p, '->', rot13(p)));
```

输出（已交叉验证）：

| 输入 | rot13 后 |
|---|---|
| `Hack` | `Unpx` |
| `success` | `fhpprff` |
| `failure` | `snvyher` |
| `Pwned` | `Cjarq` |
| `ABCDEFG` | `NOPQRST` |

**规律很清楚**：字母表位移 13 位，大小写各自独立（`A`↔`N`、`a`↔`n`）。

**然后一次性设置表单并提交：**

```javascript
document.getElementById('phrase').value = 'Hack';
document.getElementById('token').value = md5(rot13('Hack'));
```

回到页面点 **Submit**。

!!! success "实测结果"

    ```
    payload : phrase=Hack
              token=md5(rot13("Hack"))
    结果    : 服务器接受 ✅
    ```

    **关键**：`Hack` 不是下拉框里的合法选项（只有 `success` / `failure`），
    但服务器照样接受了 —— 因为 token 在数学上是正确的。

**方式 C：改 JS 逻辑（最能说明问题）**

F12 → **Elements** → 双击那段 `<script>` → 把校验改成永远通过：

```javascript
// 原来是 md5(rot13(phrase))，改成固定值
document.getElementById("token").value = "anything";
```

**这直接演示了「客户端代码完全不可信」。**

**方式 D：在线工具**

用任意在线 MD5 工具算 `md5("Unpx")`。

### 第 5 步：验证

提交后，服务器返回成功提示，**而且接受的 phrase 不是我方预设的合法值**。

**这就证明了**：攻击者不需要通过页面，就能构造出"合法"的请求。

---

## 三、为什么能成功

| 环节 | 说明 |
|---|---|
| **算法暴露在客户端** | F12 就能读到 token 的完整生成逻辑 |
| **无服务端密钥** | token 只依赖用户可控的 `phrase`，不含任何秘密 |
| **无随机性** | 同一个 phrase 永远算出同一个 token，可重放 |
| **校验与生成分离** | 服务器信任了客户端计算的中间结果 |

**最关键的一条**：**token 里没有任何"只有服务器知道"的东西。**

如果 token 是 `md5(rot13(phrase) + server_secret)`,那攻击者算不出来 ——
**因为 `server_secret` 从未发送到客户端。**

---

## 四、修复建议

### 方案 1：把校验逻辑移到服务端（根本解法）

**不要在客户端算 token 然后送去校验。** 正确流程：

```
① 用户提交 phrase
        ↓
② 服务器根据 phrase + 服务端密钥 + 会话状态，自己校验
        ↓
③ 服务器返回结果
```

**客户端只负责收集输入和展示结果，不做任何安全判断。**

### 方案 2：token 必须包含服务端生成的随机值

如果确实需要一个 token 机制，正确做法是：

```php
// 服务端生成并存入 session
$_SESSION['csrf_token'] = bin2hex(random_bytes(32));
```

```html
<input type="hidden" name="user_token" value="<?= $_SESSION['csrf_token'] ?>">
```

```php
// 服务端校验
if (!hash_equals($_SESSION['csrf_token'], $_POST['user_token'] ?? '')) {
    die('Invalid token');
}
```

**为什么有效**：随机值在**服务端生成**，攻击者无法预知，也无法自己算出。

!!! tip "和 CSRF 那篇的联系"

    这其实是**同一个设计缺陷的不同表现**：

    - CSRF：服务器只用 Cookie 判断身份，不验证请求来源
    - JavaScript Attacks：服务器信任客户端算出的 token，不验证其来源

    **共同点：服务器把「客户端提供的东西」当成了可信输入。**

### 方案 3：绝不把安全逻辑写在前端

```javascript
// ❌ 错误：用 JS 判断权限、判断成功失败
if (userInput === "admin") { showAdminPanel(); }

// ❌ 错误：用 JS 隐藏敏感数据
if (!isAdmin) { document.getElementById("secret").style.display = "none"; }

// ✅ 正确：敏感数据根本不发送给无权限用户
```

**核心原则**：

> **前端只负责体验，后端负责安全。**
>
> 前端做的一切校验，目的只是给用户即时反馈，**绝不能作为安全依据**。

### 方案 4：敏感数据不下发

**如果数据不该被看到，就不要发给浏览器。**

很多"前端隐藏"的做法是无效的 —— 数据已经在响应里了，攻击者 F12 就能看到：

```html
<!-- ❌ 数据已经在响应里了，只是 CSS 隐藏 -->
<div id="admin-panel" style="display:none">...</div>

<!-- ✅ 无权限用户根本收不到这段 HTML -->
```

---

## 五、Low / Medium / High 的防护演进

| 难度 | 防护手段 | 绕过思路 |
|---|---|---|
| **Low** | rot13 + MD5 明文混淆 | 直接读源码，Console 里调 `md5(rot13(x))` 算出 token |
| **Medium** | JS 代码混淆（变量名变成 `_0x4a2b`） | 用 JS 格式化工具还原，或直接在 Console 里调用现成函数 |
| **High** | token 引入**随机值** | 需要分析随机数生成逻辑，通常需结合其他漏洞 |

**High 难度的意义**：如果 token 依赖服务端下发的随机值，客户端算出算法也没用。

**这与 CSRF 的 High 难度（加入 token）是同一个设计思路。**

---

## 六、总结

| 要点 | 结论 |
|---|---|
| 漏洞本质 | 服务器信任了客户端计算的中间结果 |
| 根本修复 | 安全逻辑全部在服务端；token 必须含服务端随机值 |
| 常见误判 | 「我把 JS 混淆了，攻击者看不懂」—— 混淆不是加密，可还原 |
| 检测思路 | 看请求里有没有「客户端算出、服务器信任」的参数 |

**我在这关学到的**：

前面几个模块（SQL 注入、XSS、CSRF）都是**注入类**漏洞 ——
攻击者把恶意数据送进某个处理流程。

**这个模块不一样，它是个"设计类"漏洞**：代码本身没有 bug，
但**架构上把不该信任的东西当成了可信**。

这提示我：**评估一个系统时，不只要看"代码写得对不对"，
还要看"每个数据来源是否可信"。**

另一个体会是 × **前端代码从来不是安全边界**。
面试时如果被问"前端做参数校验有意义吗"，答案是：
**有，但只是为了用户体验；安全校验必须在后端重做一遍。**

---

## 参考

- DVWA 官方仓库：<https://github.com/digininja/DVWA>
- OWASP 客户端安全备忘单：<https://cheatsheetseries.owasp.org/cheatsheets/Client_Side_Security_Cheat_Sheet.html>
- OWASP 前端安全：<https://owasp.org/www-project-top-10-client-side-security-risks/>
