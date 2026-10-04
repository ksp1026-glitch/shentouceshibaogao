# 工具与环境

记录我在渗透测试中使用的工具配置和环境搭建过程，方便重装时快速恢复。

---

## 环境清单

| 工具 | 用途 | 说明 |
|---|---|---|
| XAMPP (PHP 8.2) | Web 服务器 + 数据库 | Apache + MariaDB + PHP，开箱即用 |
| DVWA | 靶场 | 部署在 `E:\xampp\htdocs\dvwa` |
| 浏览器开发者工具 | 抓包 | F12 → Network，够用 |
| Burp Suite 社区版 | 抓包改包 | 进阶使用 |

---

## DVWA 靶场部署

### 一次性部署

```powershell
# 1. 部署 DVWA 到 Apache 并启用 GD 扩展
powershell -ExecutionPolicy Bypass -File .\tools\deploy-to-apache.ps1
```

### 每次使用

1. 打开 **XAMPP Control Panel**
2. **Apache** 和 **MySQL** 都点 **Start**（都变绿）
3. 浏览器访问 <http://localhost/dvwa/>
4. 登录 `admin` / `password`

### 停止

XAMPP Control Panel 里点两行的 **Stop**。

---

## 踩过的坑（值得记下来）

| 现象 | 原因 | 解法 |
|---|---|---|
| Docker 起不来：`virtualisation support wasn't detected` | BIOS 里 VT-x 未开启 | 进 BIOS 开 Virtualization Technology，或改用 XAMPP |
| `Access denied for user 'dvwa'@'localhost'` | 用户建在了另一个 MySQL 实例里 | 两套 MySQL 抢 3306，需统一到一套 |
| 密码哈希长度 = 0，任何密码都登录失败 | `CREATE USER IF NOT EXISTS` 静默跳过已存在的用户 | 改用 `DROP USER` + `CREATE USER` |
| PHP 内置服务器关掉终端就死 | 进程绑在父进程上 | 改用 Apache（Windows 服务） |
| 脚本"成功"了但文件其实没写进去 | 只读校验给了假阳性 | **写完必须回读确认** |

!!! tip "最大的教训"

    **换数据库服务时，账号不会跟着走。** 从 MySQL 8.4 切到 MariaDB，
    数据目录完全不同，原来建的用户凭空消失。

    所以任何"建用户"的脚本都必须**主动验证能否真的登录**，
    而不是只看命令退出码。

---

## 文档

- [Burp Suite 配置](burp-setup.md) —— 抓 HTTPS 包的完整步骤

---

## 笔记原则

1. **记录踩过的坑。** 报错信息和解决方式比成功步骤更有价值
2. **命令带参数说明。** 三个月后回来看要能直接复用
3. **不记录任何真实目标信息。**
