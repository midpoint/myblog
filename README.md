# Midpoint's Blog

用 Hugo + GitHub Pages + GitHub Actions 搭建的静态博客，文章在 Obsidian 里写。

## 技术栈

| 组件 | 用途 | 说明 |
|---|---|---|
| [Hugo](https://gohugo.io/) 0.168.0 | 静态站点生成 | 单文件可执行程序，无运行时依赖 |
| [PaperMod](https://github.com/adityatelange/hugo-PaperMod/) | 主题 | 已直接放进 `themes/`，不依赖 Git submodule |
| GitHub Actions | 构建与部署 | push 到 `main` 自动发布 |
| GitHub Pages | 托管 | 无需服务器 |
| [Obsidian](https://obsidian.md/) | 写作 | vault 指向 `content/` 目录 |

## 目录结构

```
.
├── config/_default/
│   ├── hugo.toml          # 站点主配置
│   └── menus.zh-cn.toml   # 导航菜单
├── content/               # ← Obsidian vault 指向这里
│   ├── .obsidian/         # Obsidian 设置（随仓库走，换设备保持一致）
│   ├── posts/
│   │   └── hello-hugo/
│   │       ├── index.md   # 文章
│   │       └── image.png  # 同目录的图片
│   ├── about.md
│   ├── archives.md
│   └── search.md
├── layouts/               # 站点级模板覆盖（目前为空，按需添加）
├── themes/PaperMod/       # 主题源码（已本地化）
├── scripts/new-post.sh    # 新建文章脚本
└── .github/workflows/hugo.yml  # 构建 + 部署
```

每篇文章是**一个文件夹**（Hugo 的 page bundle），图片和正文放在一起。

## 首次配置 GitHub

1. **推送仓库**（本机到 GitHub 的 SSH 已验证可用）：

   ```bash
   git remote add origin git@github.com:<用户名>/<仓库名>.git
   git push -u origin main
   ```

2. **开启 Pages**：仓库 → Settings → Pages → Build and deployment → Source 选 **GitHub Actions**。

   不要选 "Deploy from a branch"，那套走的是另一条流水线，和本仓库的 workflow 冲突。

3. 第一次 push 后到 **Actions** 标签页看 `Build and deploy Hugo site` 是否跑通。
   成功后站点在 `https://<用户名>.github.io/<仓库名>/`。

### 换仓库名或自定义域名

- 换仓库名：`config/_default/hugo.toml` 里的 `baseURL` 改一下只影响本地预览；
  CI 构建时用 `actions/configure-pages` 输出的地址覆盖，站内链接会自动适配。
- 自定义域名：在仓库 Settings → Pages 里填域名，并在 `static/` 下放 `CNAME` 文件。

## 本地环境

Hugo 已经装在 `~/.local/bin/hugo`（v0.168.0 extended）。如果新开终端找不到命令：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

建议把这行加进 `~/.bashrc`。

本地预览：

```bash
hugo server          # 只显示已发布文章
hugo server -D       # 包含 draft: true 的草稿
hugo server --buildFuture   # 包含未来日期的文章
```

访问 http://localhost:1313/blog/ （注意路径带 `/blog/`，和 baseURL 一致）。

## 写作流程

### 方式一：Obsidian（推荐）

1. Obsidian → Open folder as vault → 选择本仓库的 **`content/`** 目录。
2. 在 `content/posts/` 下新建文件夹（文件夹名就是 URL 里的 slug）。
3. 文件夹里新建 `index.md`，开头写 front matter：

   ```toml
   +++
   title = "文章标题"
   date = 2026-10-23T10:00:00+08:00
   draft = false
   tags = ["标签1", "标签2"]
   categories = ["分类"]
   +++
   ```

4. 图片直接拖进同一个文件夹，Obsidian 会自动插入 `![](图片名.png)`。
5. 写完把 `draft` 改成 `false`，提交推送。

### 方式二：命令行

```bash
./scripts/new-post.sh "文章标题" --tags 标签1,标签2
```

会在 `content/posts/` 下生成 page bundle，默认 `draft = true`。

### ⚠️ Obsidian 的关键设置

仓库里 `content/.obsidian/app.json` 已经配好了下面三项，**不要关掉**：

| 设置 | 值 | 原因 |
|---|---|---|
| Use [[Wikilinks]] | **关闭** | Hugo 只认标准 Markdown 链接。`![[图片.png]]` 会原样显示成文字 |
| New link format | Relative path to file | 生成 `![](image.png)` 这样的相对路径 |
| Default location for new attachments | In the same folder as current file | 图片落在 page bundle 里，随文章一起管理 |

如果你在别处已经有一批写了 wikilink 的笔记，搬进来之前要先转成 Markdown 链接，
否则图片和双链都会失效。

## 发布

```bash
git add -A
git commit -m "post: 文章标题"
git push
```

推送后 Actions 自动构建部署，通常一分钟内生效。

工作流做了两件事值得注意：

- **并发控制**：连续 push 时，正在进行的部署会跑完，排队中的旧任务作废，
  避免线上出现半发布状态。
- **显式 baseURL**：从 `configure-pages` 取地址，换仓库名/域名不用改代码。

## 常见问题

**文章写了但线上没有？** 检查 front matter 的 `draft` 是否为 `true`，
以及 `date` 是不是未来时间——Hugo 默认不发布未来日期的文章。

**图片显示不出来？** 确认图片和 `index.md` 在同一个文件夹，正文里是
`![](图片名.png)` 而不是 `![[图片名.png]]`。

**改了主题想保留？** 主题是直接拷进 `themes/PaperMod/` 的源码，可以随意改。
升级主题需要重新拉一份覆盖，注意别冲掉自己的改动。

**构建时报 `enableGitInfo` 相关警告？** 本地仓库要有 Git 历史。新 clone 的仓库正常，
纯本地新建目录时 `git init` 并至少提交一次即可。
