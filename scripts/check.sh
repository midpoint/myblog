#!/usr/bin/env bash
# 本地自检：构建站点并检查几个容易出错的点。
# 改动配置、主题、模板后跑一遍再推送。

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/bin:$PATH"

fail=0

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "1/4 检查 Obsidian wikilink"
# Hugo 不解析 [[...]] / ![[...]]，出现在正文里会原样漏出。
if grep -rnE '!?\[\[[^]]+\]\]' content --include='*.md'; then
  echo "↑ 发现 wikilink，请改成 Markdown 链接 ![](图片名.png)"
  fail=1
else
  echo "OK"
fi

say "2/4 检查文章模板"
if grep -q '^draft = true' content/templates.md; then
  echo "OK: templates.md 仍是 draft"
else
  echo "templates.md 的 draft 不是 true，模板本身会被发布到 /templates/"
  fail=1
fi

say "3/4 构建"
if ! hugo --gc --minify --panicOnWarning; then
  echo "构建失败，见上面的输出"
  exit 1
fi

say "4/4 检查产物"
[ -f public/index.html ] || { echo "缺少 public/index.html"; fail=1; }
[ -f public/index.json ] || { echo "缺少搜索索引 public/index.json"; fail=1; }
[ -f public/index.xml ] || { echo "缺少 RSS public/index.xml"; fail=1; }
if [ -d public/templates ]; then
  echo "模板目录被发布到了 public/templates/"
  fail=1
fi
echo "文章页数量: $(find public/posts -mindepth 2 -maxdepth 2 -name index.html | wc -l)"

if [ "$fail" -eq 0 ]; then
  printf '\n\033[32m全部检查通过\033[0m\n'
else
  printf '\n\033[31m有检查项未通过\033[0m\n'
  exit 1
fi
