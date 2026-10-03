# Burp Suite 配置（抓 HTTPS 包）

Burp Suite 社区版足够完成本阶段所有练习。

---

## 一、安装

从官网下载 Community Edition：<https://portswigger.net/burp/communitydownload>

需要 Java 环境（新版安装包已内置）。

---

## 二、配置浏览器代理

### 方式 A：用 Burp 内置浏览器（最省事）

Proxy → Intercept → 点 **Open browser**。

内置的 Chromium 已经配好代理和证书，**开箱即用，推荐新手用这个**。

### 方式 B：配置自己的浏览器

1. 安装代理插件（FoxyProxy 或 SwitchyOmega）
2. 新建代理配置：
   - 地址：`127.0.0.1`
   - 端口：`8080`
3. 访问 `http://burpsuite` 或 `http://127.0.0.1:8080` 下载 CA 证书

---

## 三、安装 CA 证书（HTTPS 抓包关键）

否则访问 HTTPS 网站时浏览器会报证书错误。

### Firefox

1. 访问 `http://127.0.0.1:8080`
2. 点右上角 **CA Certificate** 下载 `cacert.der`
3. 设置 → 隐私与安全 → 证书 → 查看证书 → 证书颁发机构 → 导入
4. 勾选「信任此 CA 标识网站」

### Chrome / Edge（Windows）

1. 下载 `cacert.der`
2. 双击安装 → 选择「本地计算机」→「受信任的根证书颁发机构」
3. 重启浏览器

---

## 四、验证配置成功

1. Burp 里确保 **Intercept is off**（不然请求会卡住）
2. 浏览器访问任意 HTTPS 网站
3. 打开 Burp → **Proxy → HTTP history**

能看到请求记录，就说明配置成功了。

---

## 五、常用功能

| 功能 | 位置 | 用途 |
|---|---|---|
| **Proxy → HTTP history** | 查看所有请求 | 先在这里看流量，再决定抓哪个 |
| **Repeater** | 右键 → Send to Repeater | ★ 最常用，反复改包重放 |
| **Intruder** | 右键 → Send to Intruder | 爆破、fuzz（社区版限速） |
| **Decoder** | 顶部菜单 | 编码解码（URL / Base64 / HTML） |
| **Comparer** | 顶部菜单 | 对比两次响应的差异 |

!!! tip "工作流建议"

    **Interceptor 平时关掉，只在需要精确控制某个请求时打开。**

    否则每个请求都要手动点 Forward，非常影响效率。日常用 HTTP history + Repeater 就够了。

---

## 六、常见问题

| 问题 | 原因 | 解决 |
|---|---|---|
| 浏览器打不开网页 | Intercept 开着 | 点 **Intercept is on** 切换为 off |
| 所有 HTTPS 都报证书错误 | CA 证书没装 | 重做第三步 |
| Burp 里看不到请求 | 浏览器代理没生效 | 检查代理插件是否启用、端口是否为 8080 |
| 端口 8080 被占用 | 靶场占用了 | 改 Burp 监听端口，或把靶场换到别的端口 |

---

## 参考

- PortSwigger 官方文档：<https://portswigger.net/burp/documentation>
