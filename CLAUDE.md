# 博客项目说明

个人博客：Hugo + PaperMod + GitHub Pages，文章在 Obsidian 中写。
线上：https://midpoint.github.io/myblog/
仓库：git@github.com:midpoint/myblog.git

## 改动前必看

- **Obsidian vault = `content/`**，不是仓库根目录。
- **不要使用 Obsidian wikilink**（`[[x]]` / `![[x.png]]`）。Hugo 不解析，会原样输出成文字。
  `content/.obsidian/app.json` 已锁定 Markdown 链接 + 相对路径 + 附件存当前文件夹。
- 文章是 page bundle：`content/posts/<slug>/index.md`，图片与 `index.md` 同目录。
- `content/templates.md` 是新文章模板，**必须保持 `draft = true`**，否则会发布到 `/templates/`。
  新建文章时插件/脚本替换第一行 `title` 和 `date`，其余字段原样复制。
- 两个 Obsidian 插件随仓库分发：
  - `obsidian-git`：停止编辑约 1 分钟后自动 commit + pull + push，只提交 `content/`。
  - `hugo-new-post`：命令「新建博客文章」，生成 page bundle。
- 主题 vendored 在 `themes/PaperMod/`（无 submodule）。可直接改，升级需手动覆盖。
- 中文界面依赖 `i18n/zh-CN.yaml`；Hugo 不会把 `zh-CN` 回退到主题的 `zh.yaml`。
- 站点级自定义 CSS：`assets/css/extended/custom.css`。

## 常用命令

```bash
hugo server -D                            # 预览（含草稿）→ localhost:1313/myblog/
hugo --gc --minify                        # 生产构建
./scripts/check.sh                        # 构建 + wikilink/模板/产物自检
./scripts/new-post.sh "标题" --tags a,b   # 命令行新建文章（读取 templates.md）
```

## 部署

push 到 `main` → GitHub Actions → GitHub Pages。Pages 的 Source 必须是 **GitHub Actions**。
CI 用 `configure-pages` 输出的 `base_url` 覆盖 `baseURL`；本地 `baseURL` 在
`config/_default/hugo.toml`。

## 注意事项

- Hugo 默认不发布 `draft: true` 和未来日期的文章。
- 仓库配置/文档改动不会被 obsidian-git 自动提交（插件开了 `limitToVault`），需手动 commit + push。
- 本机访问 GitHub API 受限，SSH 可用；下载 GitHub Release 用 `https://gh-proxy.com/<原 URL>`。
