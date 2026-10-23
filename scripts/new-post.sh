#!/usr/bin/env bash
# 新建一篇文章（与 Obsidian 的「新建博客文章」命令共用同一个模板）
#
#   ./scripts/new-post.sh "文章标题"
#   ./scripts/new-post.sh "Hugo 学习笔记" --tags hugo,教程
#
# 生成 content/posts/<slug>/index.md，默认 draft = true。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TITLE="${1:-}"
[ -z "$TITLE" ] && { echo "用法: $0 \"文章标题\" [--tags a,b]" >&2; exit 1; }
shift || true

TAGS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tags) TAGS="${2:-}"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

python3 - "$ROOT" "$TITLE" "$TAGS" <<'PY'
import datetime
import os
import re
import sys

root, title, tags = sys.argv[1], sys.argv[2], sys.argv[3]

# 与 Obsidian 插件保持一致的 slug 规则：保留中文，危险字符转 -
slug = re.sub(r'[\\/:*?"<>|#^\[\]]', '-', title.strip().lower())
slug = re.sub(r'\s+', '-', slug)
slug = re.sub(r'-+', '-', slug).strip('-').strip('.') or 'untitled'

base = os.path.join(root, 'content', 'posts', slug)
folder = base
n = 2
while os.path.exists(os.path.join(folder, 'index.md')):
    folder = f'{base}-{n}'
    n += 1
os.makedirs(folder, exist_ok=True)

with open(os.path.join(root, 'content', 'templates.md'), encoding='utf-8') as fh:
    content = fh.read()

now = datetime.datetime.now().astimezone().strftime('%Y-%m-%dT%H:%M:%S%z')
now = now[:-2] + ':' + now[-2:]

def esc(value):
    return value.replace('\\', '\\\\').replace('"', '\\"')

content, title_count = re.subn(
    r'^title\s*=.*$', lambda m: f'title = "{esc(title)}"', content, count=1, flags=re.M)
content, date_count = re.subn(
    r'^date\s*=.*$', lambda m: f'date = {now}', content, count=1, flags=re.M)

if title_count != 1 or date_count != 1:
    sys.exit('模板缺少 title 或 date 行，请检查 content/templates.md')

if tags:
    tag_list = ', '.join(f'"{t.strip()}"' for t in tags.split(',') if t.strip())
    content, _ = re.subn(
        r'^tags\s*=.*$', lambda m: f'tags = [{tag_list}]', content, count=1, flags=re.M)

path = os.path.join(folder, 'index.md')
with open(path, 'w', encoding='utf-8') as fh:
    fh.write(content)
print(f'已创建: {path}')
PY
