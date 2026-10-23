#!/usr/bin/env bash
# 新建一篇文章（Obsidian 用户也可以直接建文件夹，这个脚本只是省事）
#
#   ./scripts/new-post.sh "我的第一篇博客"
#   ./scripts/new-post.sh "Hugo 学习笔记" --tags hugo,教程
#
# 会在 content/posts/<slug>/index.md 生成 page bundle，
# 图片直接丢进同一个文件夹，正文里用 ![](图片名.png) 引用即可。

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

# 中文标题也要能生成目录名：转小写、空格转连字符、丢掉不安全的字符。
# 结果是中文 slug，URL 里会以百分号编码呈现，但 Obsidian 里看得懂。
SLUG="$(printf '%s' "$TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -e 's/[[:space:]]\+/-/g' -e 's#[/\\:*?"<>|]#-#g' -e 's/-\+/-/g' -e 's/^-//' -e 's/-$//')"

DIR="$ROOT/content/posts/$SLUG"
if [ -e "$DIR" ]; then
  echo "已存在: $DIR" >&2
  exit 1
fi

mkdir -p "$DIR"
TAGS_TOML=""
if [ -n "$TAGS" ]; then
  TAGS_TOML="tags = [$(printf '%s' "$TAGS" | awk -F, '{for(i=1;i<=NF;i++){printf "%s\"%s\"", (i>1?", ":""), $i}}')]"
fi

cat > "$DIR/index.md" <<EOF
+++
title = "$TITLE"
date = $(date +%Y-%m-%dT%H:%M:%S%:z)
draft = true
$TAGS_TOML
+++

在这里开始写正文。

<!--
写作提示：
- draft = true 时本地预览可见，但不会发布到线上。写完改成 false。
- 图片直接放在本文件夹，正文用 ![](图片名.png) 引用。
- 想加摘要，在 +++ 之后写一行 <!--more-->，之前的内容会成为列表页摘要。
-->
EOF

echo "已创建: $DIR/index.md"