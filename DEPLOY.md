# 部署与维护指南

这份文档记录这个站点是怎么搭起来的，以及日常怎么写新文章。

---

## 一、技术选型

| 组件 | 选择 | 原因 |
|---|---|---|
| 静态站点生成 | **MkDocs** | 配置简单，30 分钟上手 |
| 主题 | **Material for MkDocs** | 自带搜索、深色模式、代码高亮、中文支持 |
| 部署 | **GitHub Actions** | push 即自动构建部署 |
| 托管 | **GitHub Pages** | 免费 |

**为什么不用 SPA（Vue/React）**：

单页应用的内容全靠 JavaScript 渲染，搜索引擎抓不到正文，分享链接也没有预览卡片。对作品集来说，**内容是主角，框架只是容器**。MkDocs 生成的是纯静态 HTML，每个页面都有完整的正文。

---

## 二、本地环境

### 首次安装

```bash
# 进入仓库目录
cd shentouceshibaogao

# 创建虚拟环境
python -m venv .venv

# Windows 激活
.venv\Scripts\activate

# macOS / Linux 激活
source .venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

### 本地预览

```bash
mkdocs serve
```

浏览器打开 <http://127.0.0.1:8000>。**改文件会自动刷新**，写文章时一直开着。

### 构建

```bash
mkdocs build
```

产物在 `site/` 目录（已在 `.gitignore` 里忽略，不用提交）。

---

## 三、首次部署到 GitHub Pages

### 第 1 步：开启 Pages

1. 打开仓库页面 → **Settings** → 左侧菜单找到 **Pages**
2. **Source** 选择 **GitHub Actions**（不是 "Deploy from a branch"）
3. 保存

### 第 2 步：推送代码

```bash
git add .
git commit -m "chore: 初始化 MkDocs 站点"
git push origin main
```

### 第 3 步：等待部署完成

1. 打开仓库的 **Actions** 标签
2. 看到 **Deploy Docs to GitHub Pages** 工作流，等它变成绿色 ✅（约 1-2 分钟）
3. 访问 <https://ksp1026-glitch.github.io/shentouceshibaogao/>

### 如果部署失败

| 现象 | 原因 | 解决 |
|---|---|---|
| Actions 里没有工作流 | `.github/workflows/deploy.yml` 没推上去 | 检查文件路径，注意 `.github` 前面的点 |
| 构建报错 `--strict` | 有 Markdown 链接指向不存在的文件 | 按报错提示修正链接 |
| Pages 404 | Source 没设成 GitHub Actions | 回到第 1 步 |

!!! tip "关于 `--strict`"

    工作流里用了 `mkdocs build --strict`，它会把**警告当错误**。

    好处是能逼你保持链接有效；坏处是拼错一个链接名就构建失败。

    如果觉得太严格，可以去掉 `--strict`。

---

## 四、怎么写一篇新文章

### 第 1 步：新建 Markdown 文件

放到对应分类目录下，文件名用**英文小写加连字符**：

```
docs/web/sql-injection-dvwa.md      ✅
docs/web/SQL注入.md                  ❌ 中文名容易出编码问题
```

### 第 2 步：套用模板

每篇文章的结构固定：

```markdown
# 标题

!!! info "环境信息"

    靶场：
    难度：
    测试地址：
    使用工具：

## 一、漏洞原理

（用自己的话讲清楚，不要照抄定义）

## 二、利用过程

## 三、为什么能成功

## 四、修复建议

## 五、总结

## 参考
```

!!! warning "「修复建议」这一节不要跳过"

    这是区分「会在靶场打洞的人」和「能做安全工程的人」的关键。

    面试官最想看到的不是你会打，而是**你知道怎么防**。

### 第 3 步：注册到导航

编辑 `mkdocs.yml` 的 `nav` 部分：

```yaml
nav:
  - Web 安全:
      - web/index.md
      - SQL 注入:
          - DVWA 入门: web/sql-injection-dvwa.md
          - 盲注实战: web/sql-injection-blind.md   # ← 加这一行
```

### 第 4 步：本地预览

```bash
mkdocs serve
```

确认排版没问题。

### 第 5 步：提交

```bash
git add .
git commit -m "docs: 新增 SQL 盲注 writeup"
git push origin main
```

推送后 Actions 会自动部署。

---

## 五、推荐的工作流

```bash
# 1. 开始写之前，先拉一次
git pull

# 2. 开着本地预览
mkdocs serve

# 3. 写文章 → 保存 → 浏览器自动刷新 → 检查

# 4. 写完提交
git add .
git commit -m "docs: xxx"
git push
```

---

## 六、目录结构说明

```
shentouceshibaogao/
├── README.md              ← GitHub 主页显示的内容（作品集入口）
├── LICENSE.md             ← 许可与免责声明
├── mkdocs.yml             ← 站点配置（导航、主题、插件）
├── requirements.txt       ← Python 依赖
├── .gitignore
├── .github/
│   └── workflows/
│       └── deploy.yml     ← 自动部署工作流
└── docs/                  ← ★ 所有内容都在这里
    ├── index.md           ← 站点首页
    ├── plan.md            ← 学习计划
    ├── web/               ← Web 漏洞
    │   ├── index.md       ← 分类索引页
    │   └── *.md
    ├── ctf/               ← CTF 题解
    ├── reports/           ← 完整渗透测试报告
    └── tools/             ← 工具配置笔记
```

---

## 七、常用命令速查

| 命令 | 作用 |
|---|---|
| `mkdocs serve` | 本地预览（热重载） |
| `mkdocs build` | 构建静态站点到 `site/` |
| `mkdocs build --strict` | 构建，且把警告当错误 |
| `git add . && git commit -m "..." && git push` | 提交并触发部署 |

---

## 参考

- MkDocs 文档：<https://www.mkdocs.org/>
- Material for MkDocs：<https://squidfunk.github.io/mkdocs-material/>
