# 渗透测试学习记录

广东工业大学 · 网络空间安全专业

这里记录我在渗透测试与 Web 安全方向的学习过程。每篇 writeup 都包含三个部分：

<div class="grid cards" markdown>

- :material-lightbulb-on: **漏洞原理**

    ---

    用自己的话讲清楚漏洞为什么存在，而不是照抄定义。

- :material-sword: **利用过程**

    ---

    完整的复现步骤、payload、关键请求与响应。

- :material-shield-check: **修复建议**

    ---

    从代码或配置层面说明怎么防。**只会在靶场打洞的人，不是安全工程师。**

</div>

---

## 开始阅读

| 章节 | 说明 |
|---|---|
| [Web 安全](web/index.md) | SQL 注入、XSS、文件上传、SSRF、XXE 等主流 Web 漏洞 |
| [CTF Writeup](ctf/index.md) | Web / Misc 方向题解 |
| [渗透测试报告](reports/index.md) | 完整打靶流程：信息收集 → 利用 → 提权 → 报告 |
| [工具与环境](tools/index.md) | Kali、Burp Suite、Docker 靶场搭建 |
| [学习计划](plan.md) | 本学期的学习进度表 |

---

## 练习范围说明

本记录中所有测试**仅针对**：

- 自己用 Docker / VMware 搭建的本地靶场
- PortSwigger Web Security Academy 等官方练习平台
- CTF 比赛题目
- 补天、漏洞盒子等**明确授权**的漏洞平台

!!! danger "底线"

    未经授权对他人系统进行扫描或渗透测试，违反《中华人民共和国网络安全法》。

    **这条线一次都不能碰。**
