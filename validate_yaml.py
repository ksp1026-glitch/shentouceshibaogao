"""极简 YAML 语法校验器（仅覆盖本文件用到的子集）。
用于在无 PyYAML 环境下检查缩进、冒号、列表和 !!python/name: 标签是否规范。
"""
import re
import sys

PATH = "mkdocs.yml"


def main():
    with open(PATH, encoding="utf-8") as f:
        raw = f.readlines()

    errors = []
    stack = []  # (indent, kind)

    for i, line in enumerate(raw, 1):
        stripped = line.rstrip("\n")
        if not stripped.strip():
            continue
        if stripped.lstrip().startswith("#"):
            continue

        indent = len(stripped) - len(stripped.lstrip(" "))

        # Tab 缩进是 YAML 硬错误
        if "\t" in stripped[:indent]:
            errors.append(f"line {i}: 使用了 Tab 缩进（YAML 不允许）")

        # 缩进必须是偶数（本项目约定 2 空格）
        if indent % 2 != 0:
            errors.append(f"line {i}: 缩进 {indent} 不是 2 的倍数")

        content = stripped.strip()

        # 列表项
        if content.startswith("- "):
            rest = content[2:].strip()
            if rest and ":" not in rest and not rest.startswith(("!", "&", "*")):
                pass  # 纯标量列表项，合法
            continue

        # 键值对
        if ":" in content:
            key, _, value = content.partition(":")
            key = key.strip()
            if not key:
                errors.append(f"line {i}: 冒号前缺少键名")
            if re.search(r"\s:$", content) or content.endswith(":"):
                stack.append((indent, "map"))
            value = value.strip()
            if value.startswith("!!python/name:"):
                target = value[len("!!python/name:"):]
                if not re.match(r"^[\w.]+$", target):
                    errors.append(f"line {i}: 非法 python/name 目标 {target}")
            if value.startswith("[") and not value.endswith("]"):
                errors.append(f"line {i}: 内联列表未闭合")
            if value and not value.startswith(("'", '"', "[", "{")):
                if "#" in value:
                    errors.append(f"line {i}: 未加引号的值里含 #，会被当成注释")
        else:
            # 既不是列表也不是键值，可能是数值/布尔等顶层标量，仅提示
            pass

    # 检查是否有明显的重复顶层键
    top_keys = []
    for line in raw:
        if line.strip() and not line.startswith((" ", "\t", "#")) and ":" in line:
            top_keys.append(line.split(":")[0].strip())
    dupes = {k for k in top_keys if top_keys.count(k) > 1}
    if dupes:
        errors.append(f"重复的顶层键: {dupes}")

    print(f"检查 {len(raw)} 行")
    if errors:
        print("发现问题:")
        for e in errors:
            print("  -", e)
        sys.exit(1)
    print("YAML 结构校验通过")
    print(f"顶层键: {top_keys}")


if __name__ == "__main__":
    main()
