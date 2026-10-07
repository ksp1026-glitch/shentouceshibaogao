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
| `phrase` | 你想提交的短语（**页面上唯一可见的输入框**） |
| `token` | **隐藏字段**，由页面上的 JavaScript 自动计算填入 |
| `send` | 提交按钮 |

### 界面长什么样

**页面上只有一个输入框**，token 是隐藏字段（源码原文）：

```html
<p>Submit the word "success" to win.</p>
<form name="low_js" method="post">
    <input type="hidden" name="token" value="" id="token" />          <!-- 隐藏，JS 自动填 -->
    <label for="phrase">Phrase</label>
    <input type="text" name="phrase" value="ChangeMe" id="phrase" />  <!-- 唯一可见的 -->
    <input type="submit" id="send" name="send" value="Submit" />
</form>
```

渲染出来是这样：

```
Submit the word "success" to win.

Phrase: [ ChangeMe        ]
        [    Submit      ]
```

!!! warning "注意默认值 `ChangeMe`"

    输入框的默认值是 `ChangeMe`，**不是空的**。

    页面加载时 `generate_token()` 会立即执行一次，所以初始 token 是
    `md5(rot13("ChangeMe"))` = `8b479aefbd90795395b3e7089ae0dc09`。

    **如果只把 Phrase 改成 `success` 而不更新 token，提交必然失败** ——
    因为 token 还是 `ChangeMe` 的哈希。

    这个细节在实操中很容易卡住（我就在这里卡过一次）。

### 服务器的校验逻辑

```php
if ( $phrase == "success" ) {
    if ( $token == md5(str_rot13("success")) ) {   // ← 服务端自己算
        $message = "Well done!";
    } else {
        $message = "Invalid token.";
    }
} else {
    $message = "You got the phrase wrong.";
}
```

**两个条件必须同时满足**：

1. `phrase` 必须是 `success`
2. `token` 必须等于 `md5(str_rot13("success"))`

**实测值**（用 Node 与 Python 双实现交叉验证）：

| 计算 | 结果 |
|---|---|
| `str_rot13("success")` | `fhpprff` |
| **期望 token** | **`38581812b435834ebf84ebcc2c6424d6`** |
| 对照：`md5(rot13("ChangeMe"))` | `8b479aefbd90795395b3e7089ae0dc09` |

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

### 第 3 步：先通过 —— 把答案填出来

**服务器要的就是 `success` 这个词，所以第一步是正常通关。**

**你只需要填一个框：**

| 位置 | 填什么 |
|---|---|
| **Phrase**（可见输入框） | `success` |
| Token（隐藏字段） | **不用管**，页面 JS 会填 |

**但有个坑**：输入框默认值是 `ChangeMe`，页面加载时已经算过一次 token。

**如果你只改 Phrase 而不更新 token，会得到 `Invalid token.`**

**解决办法 —— 在 Console 里手动触发一次重新计算：**

```javascript
document.getElementById('phrase').value = 'success';
document.getElementById('token').value  = md5(rot13('success'));
```

**然后点 Submit → `Well done!`**

**① 更简单的办法**：直接在页面上输入 `success`，然后**点一下页面其他地方**（触发 blur 事件），有些难度下会自动更新 token。

**② 最保险的办法**：用上面那两行 Console 代码手动设置。

**Token 是攻击者可以自己算的 —— 这就是漏洞所在。**

F12 → **Console**：

```javascript
md5(rot13('success'))
```

复制返回的 32 位字符串，粘贴进 Token 框。

**点 Submit → 通过。**

!!! success "实测结果"

    ```
    Phrase : success
    Token  : md5(rot13("success"))
    结果   : 服务器接受 ✅
    ```

    **注意**：Token 是**你自己算出来的**，而不是页面给的 ——
    但服务器**完全无法区分**这两者。这就是漏洞的实证。

### 第 4 步：核心问题 —— 那这算漏洞吗

**"填出 success"本身不算攻击**，它只是通关条件。

**真正的漏洞在这里**：

> **服务器想用 token 来证明「这个请求是从我的页面发出的」。**
> **但 token 的算法公开在客户端，输入也由用户控制 —— 所以谁都能算。**

**攻击者能做的三件事（这才是漏洞的价值）：**

| # | 做法 | 说明 |
|---|---|---|
| ① | **绕过页面直接构造请求** | 用 Burp / curl 直接发，完全不加载页面 JS |
| ② | **改客户端的校验逻辑** | F12 改 JS，让它返回任意值 |
| ③ | **重放** | 因为 token 是纯函数、无随机数，同一个 phrase 永远对应同一个 token |

**所以：如果这个机制被用来保护真实业务**（比如"验证用户是否有权限提交这个金额"），
**攻击者就能伪造任意合法请求。**

### 第 5 步：用 Burp 演示"完全绕过页面"（实测通过）

**这是本模块最有说服力的一步** —— 证明不依赖页面的 JavaScript，也能让服务器接受。

#### 抓一个真实请求

用 Burp 代理浏览器（推荐用 Burp 内置浏览器，开箱即用），在页面上点一次 Submit，拦到的原始请求是：

```http
POST /dvwa/vulnerabilities/javascript/ HTTP/1.1
Host: localhost
Content-Type: application/x-www-form-urlencoded
Cookie: security=low; PHPSESSID=<浏览器真实session>

token=8b479aefbd90795395b3e7089ae0dc09&phrase=success&send=Submit
```

**注意这里的 token 是 `8b479aef...`** —— 它不是 `success` 的哈希，而是**默认值 `ChangeMe` 的哈希**：

```
md5(rot13("ChangeMe")) = 8b479aefbd90795395b3e7089ae0dc09
```

**原因**：页面加载时 `generate_token()` 用默认值 `ChangeMe` 算了一次。
之后把 Phrase 改成 `success` 时，**如果没触发重新计算，token 就还是旧的**。

**所以这个请求会失败**，服务器返回 `Invalid token.`

#### 替换 token 为攻击者自己算的值

**只改 `token=` 这一个值**，其余全部不动：

```http
POST /dvwa/vulnerabilities/javascript/ HTTP/1.1
Host: localhost
Content-Type: application/x-www-form-urlencoded
Cookie: security=low; PHPSESSID=<浏览器真实session>

token=38581812b435834ebf84ebcc2c6424d6&phrase=success&send=Submit
```

**发送 → 服务器返回 `Well done!`**

!!! success "实测结果"

    ```
    token  = 38581812b435834ebf84ebcc2c6424d6   ← 攻击者自己算的
    phrase = success
    响应   = Well done!  ✅
    ```

#### 为什么这一步是决定性的

**`38581812b435834ebf84ebcc2c6424d6` 这个值，页面的 JavaScript 从来没有计算过。**

它是攻击者在**浏览器之外**独立算出来的，然后手工塞进请求。

**服务器无法区分这两种来源：**

| 来源 | token 值 | 服务器判断 |
|---|---|---|
| 页面 JS 计算 | `38581812...` | 通过 |
| **攻击者自己计算** | `38581812...` | **通过（完全相同）** |

**因为两者数值一样，服务器没有任何依据区分。**

这就是"客户端校验等于没有校验"的实证。

!!! note "一个额外的发现"

    **token 和它保护的数据之间没有任何绑定关系。**

    页面可以给你一个基于 `ChangeMe` 的 token，你随手换成基于 `success` 的另一个，
    服务器只比对「最终的 token 和 phrase 是否匹配」——
    它不关心 token 是谁生成的、什么时候生成的。

    **如果这个机制真的想证明"请求来自我的页面"，它至少应该保证
    "token 是刚刚根据当前 phrase 生成的"。但它做不到 —— 因为它是一个无状态的纯函数。**

### 第 6 步：其他几种实操方式

**方式 A：F12 Console 自己算（最省事，推荐）**

**页面自带的 `md5()` 和 `rot13()` 函数可以直接调用** —— 因为源码已经在页面里定义了它们。

```javascript
md5(rot13('success'))     // 得到合法 token
```

**先验证 rot13 的行为**（理解算法）：

```javascript
['Hack','success','failure'].forEach(p => console.log(p, '->', rot13(p)));
```

输出（已用 Node 与 Python 双实现交叉验证）：

| 输入 | rot13 后 |
|---|---|
| `success` | `fhpprff` |
| `failure` | `snvyher` |
| `Hack` | `Unpx` |
| `Pwned` | `Cjarq` |
| `ABCDEFG` | `NOPQRST` |

**规律**：字母表位移 13 位，大小写各自独立（`A`↔`N`、`a`↔`n`）。

**方式 B：一键填表并提交**

```javascript
document.getElementById('phrase').value = 'success';
document.getElementById('token').value  = md5(rot13('success'));
```

回到页面点 **Submit**。

**方式 C：改 JS 逻辑（演示"客户端代码不可信"）**

F12 → **Elements** → 双击那段 `<script>` → 改掉 `generate_token()`：

```javascript
// 原来：document.getElementById("token").value = md5(rot13(phrase));
// 改成固定值：
document.getElementById("token").value = "anything";
```

**结果**：服务器**会拒绝** —— 因为算出的值不等于 `md5(rot13("success"))`。

!!! tip "这一步的结论很关键"

    **改客户端能骗过页面，但骗不过服务器。**

    这反而更准确地说明了问题：**客户端代码可以被任意篡改，
    所以服务器绝不能依赖它计算出的任何结果。**

**方式 D：在线 MD5 工具**

手动算 `md5("fhpprff")`（`fhpprff` 是 `success` 的 rot13 结果）—— 任意在线工具都行。

### 第 7 步：验证

提交后出现成功提示。

**验证要点**：

| 检查 | 说明 |
|---|---|
| Token 是你自己算的 | 没依赖页面自动填充 |
| 用 Burp 手工构造也能过 | 证明**完全不需要浏览器** |
| 同一个 phrase 永远同一个 token | 说明**可重放** |

**第 2 条最重要** —— 它证明这个校验机制**对外部攻击者完全无效**。

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
