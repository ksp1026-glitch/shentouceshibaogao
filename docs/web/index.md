# Web 安全

Web 漏洞是我这个阶段的重点方向——入门最快、靶场最多、招聘岗位需求最大。

每篇 writeup 都按「原理 → 利用过程 → 为什么能成功 → 修复建议」的结构写。

---

## 漏洞清单

| 漏洞类型 | 靶场 | Writeup | 状态 |
|---|---|---|---|
| SQL 注入 | DVWA / Pikachu | [DVWA Low](sql-injection-dvwa.md) | ✅ |
| CSRF | DVWA | [DVWA Low](csrf-dvwa.md) | ✅ |
| XSS (DOM 型) | DVWA | [DVWA Low](xss-dom-dvwa.md) | ✅ |
| XSS (反射型 / 存储型) | DVWA / Pikachu | — | ⬜ |
| 文件上传 | upload-labs | — | ⬜ |
| 文件包含 | DVWA / Pikachu | — | ⬜ |
| 命令注入 | DVWA | — | ⬜ |
| 目录遍历 | DVWA | — | ⬜ |
| SSRF | Pikachu | — | ⬜ |
| XXE | PortSwigger | — | ⬜ |
| 逻辑漏洞 | — | — | ⬜ |

---

## 学习顺序建议

按「利用难度 + 出现频率」排的顺序：

1. **SQL 注入** — Web 漏洞之王，必学，也是理解数据库交互的入口
2. **XSS** — 前端安全的起点
3. **文件上传 / 文件包含** — 拿 shell 的主要途径
4. **命令注入 / 目录遍历** — 理解系统调用边界
5. **CSRF** — 理解身份认证机制
6. **SSRF / XXE** — 进阶，但实战中出现频率越来越高
7. **逻辑漏洞** — 最难，也最考验思维，无法用工具扫出来

---

## 常用靶场

| 靶场 | 部署 | 特点 |
|---|---|---|
| DVWA | `docker run -d -p 8080:80 vulnerables/web-dvwa` | 有 Low/Medium/High 三档难度，适合看防护演进 |
| Pikachu | `docker run -d -p 8081:80 area39/pikachu` | 中文，漏洞类型全 |
| upload-labs | 需自行部署 | 专练文件上传绕过 |
| PortSwigger Academy | 在线，免费 | 带自动验证，质量最高 |
