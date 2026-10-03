# 工具与环境

记录我在渗透测试中使用的工具配置和环境搭建过程，方便重装时快速恢复。

---

## 环境清单

| 工具 | 用途 | 说明 |
|---|---|---|
| VMware Workstation | 虚拟机 | 运行 Kali |
| Kali Linux | 攻击机 | 集成工具 |
| Docker Desktop | 靶场部署 | 一条命令起靶场 |
| Burp Suite 社区版 | Web 抓包改包 | 核心工具 |
| 浏览器代理插件 | 配合 Burp | FoxyProxy 或 SwitchyOmega |

---

## 靶场部署

```bash
# DVWA
docker run -d -p 8080:80 vulnerables/web-dvwa

# Pikachu
docker run -d -p 8081:80 area39/pikachu
```

访问 `http://localhost:8080`，默认账号 `admin` / `password`。

---

## 文档

- [Burp Suite 配置](burp-setup.md) —— 抓 HTTPS 包的完整步骤

---

## 笔记原则

1. **记录踩过的坑。** 报错信息和解决方式比成功步骤更有价值
2. **命令带参数说明。** 三个月后回来看要能直接复用
3. **不记录任何真实目标信息。**
