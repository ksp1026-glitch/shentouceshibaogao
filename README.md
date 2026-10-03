# 渗透测试学习记录

> 广东工业大学 · 网络空间安全专业 · 2024 级
>
> 📖 在线浏览：https://ksp1026-glitch.github.io/shentouceshibaogao/

一个持续更新的渗透测试与 Web 安全学习记录。每篇都是亲手在靶场复现后写的，包含**漏洞原理、利用过程、修复建议**三部分。

---

## 📌 内容索引

| 分类 | 内容 | 篇数 |
|---|---|---|
| [Web 安全](docs/web/index.md) | SQL 注入、XSS、文件上传、文件包含、命令注入、SSRF、XXE | 0 |
| [CTF Writeup](docs/ctf/index.md) | Web / Misc 方向题解 | 0 |
| [渗透测试报告](docs/reports/index.md) | VulnHub / HackTheBox 完整打靶流程 | 0 |
| [工具与环境](docs/tools/index.md) | Kali、Burp Suite、Docker 靶场搭建 | 0 |

---

## 🛠 技能栈

**渗透测试**

- Burp Suite（抓包、改包、重放、Intruder）
- sqlmap、Nmap
- 手工注入 / 手工漏洞挖掘优先，工具为辅

**环境**

- Kali Linux、VMware
- Docker 部署靶场（DVWA / Pikachu / upload-labs）
- Linux 命令行、Shell 基础

**编程**

- Python（脚本编写）
- JavaScript / Vue（本站的构建基础）

---

## 🎯 学习进度

### 靶场

- [ ] DVWA 全关卡（Low / Medium / High）
- [ ] Pikachu
- [ ] upload-labs
- [ ] PortSwigger Web Security Academy
- [ ] VulnHub 入门机器 × 5

### 漏洞类型

- [ ] SQL 注入（联合查询 / 报错 / 盲注 / 宽字节）
- [ ] XSS（反射 / 存储 / DOM）
- [ ] 文件上传绕过
- [ ] 文件包含（本地 / 远程）
- [ ] 命令注入
- [ ] 目录遍历
- [ ] CSRF
- [ ] SSRF
- [ ] XXE
- [ ] 逻辑漏洞（越权 / 支付）

### 实战记录

- [ ] 补天 / 漏洞盒子 首次提交
- [ ] 参加第一场线上 CTF
- [ ] 完成第一份完整渗透测试报告

---

## ⚖️ 免责声明

本仓库所有内容：

1. **仅在自己搭建的本地靶场、CTF 比赛、以及明确授权的平台（补天、漏洞盒子、PortSwigger Academy 等）上进行**
2. 不包含任何未授权目标的测试记录
3. 不提供任何可直接用于攻击真实系统的工具或方法
4. 仅供安全学习与防御研究使用

**未经授权对他人系统进行渗透测试属于违法行为。** 请遵守《中华人民共和国网络安全法》。

---

## 🔧 本地构建

```bash
# 安装依赖
pip install -r requirements.txt

# 本地预览（http://127.0.0.1:8000）
mkdocs serve

# 构建静态站点
mkdocs build
```

推送到 `main` 分支后，GitHub Actions 会自动构建并部署到 Pages。

---

## 📬 联系

- GitHub：[@ksp1026-glitch](https://github.com/ksp1026-glitch)
- 在线站点：https://ksp1026-glitch.github.io/shentouceshibaogao/
