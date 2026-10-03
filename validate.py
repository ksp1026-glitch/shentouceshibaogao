"""离线校验脚本：检查 mkdocs.yml 的 nav 配置与 Markdown 内部链接是否都指向真实文件。
不依赖任何第三方库。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.join(ROOT, "docs")
MKDOCS = os.path.join(ROOT, "mkdocs.yml")


def check_nav_files():
    """从 mkdocs.yml 里抽出所有 .md 路径，检查文件是否存在。"""
    with open(MKDOCS, encoding="utf-8") as f:
        lines = f.readlines()

    md_paths = []
    for line in lines:
        # 匹配形如 "  - 标题: path/to/file.md" 或 "- path/to/file.md"
        for m in re.finditer(r"[\w./-]+\.md", line):
            md_paths.append(m.group(0))

    print("=== nav 引用检查 ===")
    missing = []
    for p in sorted(set(md_paths)):
        full = os.path.join(DOCS, p)
        ok = os.path.isfile(full)
        print(f"  {'OK  ' if ok else 'MISS'} {p}")
        if not ok:
            missing.append(p)
    return missing


def check_internal_links():
    """扫描所有 md 文件里的相对链接，检查目标是否存在。"""
    print("\n=== Markdown 内部链接检查 ===")
    missing = []
    total = 0

    for dirpath, _dirnames, filenames in os.walk(DOCS):
        for fn in filenames:
            if not fn.endswith(".md"):
                continue
            src = os.path.join(dirpath, fn)
            with open(src, encoding="utf-8") as f:
                text = f.read()

            for m in re.finditer(r"\[[^\]]*\]\(([^)]+)\)", text):
                target = m.group(1).strip()

                # 跳过外部链接和纯锚点
                if target.startswith(("http://", "https://", "mailto:", "#")):
                    continue

                total += 1
                path_part = target.split("#")[0]
                if not path_part:
                    continue

                dest = os.path.normpath(os.path.join(dirpath, path_part))
                if not os.path.exists(dest):
                    rel_src = os.path.relpath(src, ROOT)
                    missing.append(f"{rel_src}  ->  {target}")

    print(f"  共检查 {total} 个内部链接")
    for item in missing:
        print(f"  BROKEN  {item}")
    if not missing:
        print("  全部有效")
    return missing


def check_assets():
    """检查 docs 目录结构完整性。"""
    print("\n=== 目录结构 ===")
    for sub in ["", "web", "ctf", "reports", "tools"]:
        d = os.path.join(DOCS, sub)
        exists = os.path.isdir(d)
        files = sorted(f for f in os.listdir(d) if f.endswith(".md")) if exists else []
        print(f"  docs/{sub or '.'}/  {'OK' if exists else 'MISS'}  {files}")


if __name__ == "__main__":
    nav_missing = check_nav_files()
    link_missing = check_internal_links()
    check_assets()

    print("\n" + "=" * 50)
    problems = len(nav_missing) + len(link_missing)
    if problems == 0:
        print("校验通过：配置与链接全部有效")
        sys.exit(0)
    else:
        print(f"发现 {problems} 个问题，需要修复")
        sys.exit(1)
