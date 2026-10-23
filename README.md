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
│   │   └── plugins/
│   │       ├── obsidian-git/    # 自动 commit + push
│   │       └── hugo-new-post/   # 一键新建文章
│   ├── templates.md       # 新文章模板（draft，不会发布）
│   ├── posts/
│   │   └── hello-hugo/
│   │       ├── index.md   # 文章
│   │       └── image.png  # 同目录的图片
│   ├── about.md
│   ├── archives.md
│   └── search.md
├── assets/css/extended/custom.css  # 站点级自定义样式
├── themes/PaperMod/       # 主题源码（已本地化）
├── scripts/
│   ├── new-post.sh        # 命令行新建文章
│   └── check.sh           # 推送前自检
├── CLAUDE.md              # 项目约定速查
└── .github/workflows/hugo.yml  # 构建 + 部署
```

每篇文章是**一个文件夹**（Hugo 的 page bundle），图片和正文放在一起。

## GitHub 配置（已完成，仅作记录）

1. **推送仓库**（本机到 GitHub 的 SSH 已验证可用）：

   ```bash
   git remote add origin git@github.com:midpoint/myblog.git
   git push -u origin main
   ```

2. **开启 Pages**：仓库 → Settings → Pages → Build and deployment → Source 选 **GitHub Actions**。

   不要选 "Deploy from a branch"，那套走的是另一条流水线，和本仓库的 workflow 冲突。

3. 第一次 push 后到 **Actions** 标签页看 `Build and deploy Hugo site` 是否跑通。
   成功后站点在 `https://midpoint.github.io/myblog/`。

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

访问 http://localhost:1313/myblog/ （注意路径带 `/myblog/`，和 baseURL 一致）。

## 写作流程

### 每台设备一次性准备

1. Obsidian → Open folder as vault → 选择本仓库的 **`content/`** 目录。
2. Settings → Community plugins → 关闭 **Restricted mode**。
   插件已经随仓库装好（`obsidian-git`、`hugo-new-post`），关掉限制后会自动加载。
3. 确认这台机器的 `git` 可用且 `git push` 免密（本机 SSH key 已配好）。
   插件调用的是系统 git。

### 日常写作

**方式一：一键新建（推荐）**

1. 命令面板（`Ctrl/Cmd + P`）执行 **`Hugo New Post: 新建博客文章`**，
   或点左侧边栏的 `+` 图标。
2. 输入文章标题，回车。
3. 自动创建 `content/posts/<标题 slug>/index.md`，写好 front matter 并打开，
   光标停在正文位置。
4. 图片直接拖进同一文件夹，Obsidian 会插入 `![](图片名.png)`。
5. 定稿后把 `draft` 改成 `false`。停止编辑约 1 分钟后自动 commit + push，
   Actions 随后构建发布。

同名文章已存在时，文件夹会自动加 `-2`、`-3` 后缀，不会覆盖。中文标题直接用作
文件夹名和 URL，标点会被替换成 `-`。

**方式二：手动建文件夹**

在 `content/posts/` 下新建文件夹，里面新建 `index.md`，手动写 front matter。
适合从别处搬文章进来的场景。

### 文章模板

模板在 **`content/templates.md`**，命令面板执行 `Hugo New Post: 打开文章模板`
即可编辑。

- 新建文章时，插件替换模板里第一行 `title` 和 `date`，其余内容原样复制。
- 可以在这里加默认字段，比如 `tags`、`categories`、`summary`，会带到每篇新文章。
- **不要**把模板里的 `draft` 改成 `false`，否则模板本身会被发布到 `/templates/`。

### 命令行方式（可选）

```bash
./scripts/new-post.sh "文章标题" --tags 标签1,标签2
```

与 Obsidian 命令共用 `content/templates.md`，生成 page bundle，默认 `draft = true`。

### 快捷键

`.obsidian/hotkeys.json` 里已经设好：

| 键 | 命令 | 说明 |
|---|---|---|
| `F8` | 新建博客文章 | 等同命令面板里的 `Hugo New Post: 新建博客文章` |
| `F9` | Git: Push | 只推送已有提交；commit 由自动同步负责 |

### 本地自检

改动配置、主题或模板后，推送前跑一遍：

```bash
./scripts/check.sh
```

会检查 wikilink、模板 draft 状态、构建警告，以及首页/搜索索引/RSS 等关键产物。

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

正常情况下不需要手动发布。Obsidian 的 Git 插件每分钟检查一次，有改动就：

1. commit，消息格式 `content: 自动同步 2026-10-23 14:30:00`，正文列出改动的文件
2. pull（`pullBeforePush`，多设备时避免互相覆盖）
3. push

随后 `.github/workflows/hugo.yml` 自动构建部署，通常一分钟内生效。

插件配置在 `content/.obsidian/plugins/obsidian-git/data.json`，关键项：

| 设置 | 值 | 作用 |
|---|---|---|
| Auto commit-and-sync interval | 1 分钟 | 定时检查，有改动才提交 |
| Auto commit-and-sync after stopping file edits | 开 | 编辑过程中不提交，停下来才提交 |
| Limit file operations to the vault | 开 | 只提交 `content/` 内的改动，不碰仓库其他文件 |
| Disable popups for no changes | 开 | 没改动时不弹通知 |

手动兜底（插件出问题或改的是仓库其他文件时）：

```bash
git add -A && git commit -m "post: 文章标题" && git push
```

工作流本身还有两个细节：

- **并发控制**：连续 push 时，正在进行的部署会跑完，排队中的旧任务作废，
  避免线上出现半发布状态。
- **显式 baseURL**：从 `configure-pages` 取地址，换仓库名/域名不用改代码。

## 常用修改

| 想改什么 | 改哪里 |
|---|---|
| 站名、描述、作者、社交链接 | `config/_default/hugo.toml` 的 `[params]` |
| 首页欢迎语 | 同上，`[params.homeInfoParams]` |
| 导航菜单 | `config/_default/menus.zh-cn.toml` |
| 界面文案（目录、上一页、阅读时间） | `i18n/zh-CN.yaml` |
| 新文章默认内容 | `content/templates.md` |
| 自定义样式 | `assets/css/extended/custom.css` |
| 主题外观 | `themes/PaperMod/`（vendored，可直接改） |
| 构建与部署 | `.github/workflows/hugo.yml` |
| 域名 / 仓库名 | `config/_default/hugo.toml` 的 `baseURL`；自定义域名另加 `static/CNAME` |

仓库配置和文档的改动**不会**被 Obsidian 插件自动提交（`limitToVault` 只提交 `content/`），
需要手动：

```bash
git add -A && git commit -m "chore: ..." && git push
```

改完先跑 `./scripts/check.sh`，需要逐页看效果再用 `hugo server -D`。

更完整的项目约定见 [`CLAUDE.md`](CLAUDE.md)。

## 常见问题

**文章写了但线上没有？** 检查 front matter 的 `draft` 是否为 `true`，
以及 `date` 是不是未来时间——Hugo 默认不发布未来日期的文章。

**Git 插件没生效？** 确认 Settings → Community plugins 里 Restricted mode 已关闭，
且插件列表里 `Git` 是启用状态。插件要求 Obsidian 1.13.0 以上。状态栏没有 Git 图标
就说明没加载；命令面板执行 `Git: Commit-and-sync` 可以看到具体报错。

**自动提交了但没 push 成功？** 插件用的是系统 git 和本机 SSH key。在终端执行
`cd content && git push` 复现一下，通常是 SSH key 或网络问题。本机已配好，
换设备时需要重新配 SSH。

**换设备写作？** clone 仓库，把 `content/` 作为 vault 打开，关掉 Restricted mode 即可，
插件和设置都在仓库里。避免两台设备同时编辑同一篇，否则 pull 时会有合并冲突。

**写完立刻关了 Obsidian？** 定时器没跑到就退出的话，这次改动会在下次打开时补提交。
急的话关之前执行一次 `Git: Commit-and-sync`。

**怎么确认真的推上去了？** 状态栏的 Git 图标会显示待推送提交数；也可以看
`https://github.com/midpoint/myblog/commits/main`，或命令面板里的 `Git: Open history`。

**图片显示不出来？** 确认图片和 `index.md` 在同一个文件夹，正文里是
`![](图片名.png)` 而不是 `![[图片名.png]]`。

**改了主题想保留？** 主题是直接拷进 `themes/PaperMod/` 的源码，可以随意改。
升级主题需要重新拉一份覆盖，注意别冲掉自己的改动。

**构建时报 `enableGitInfo` 相关警告？** 本地仓库要有 Git 历史。新 clone 的仓库正常，
纯本地新建目录时 `git init` 并至少提交一次即可。
