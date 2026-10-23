+++
title = "用 Hugo 搭这个博客：从零到自动发布"
date = 2026-10-23T10:00:00+08:00
draft = false
tags = ["hugo", "博客", "GitHub Actions"]
categories = ["建站"]
summary = "记录这个博客的技术选型和搭建过程：为什么是 Hugo，怎么和 Obsidian 配合，以及 push 之后自动部署的整条链路。"
+++

这个站点由 [Hugo](https://gohugo.io/) 生成，托管在 GitHub Pages 上，写作工具是 Obsidian。这篇记录一下为什么这么选，以及整条链路怎么跑起来。

## 为什么是 Hugo

静态站点生成器里，Hugo 的构建速度是压倒性的。几百篇文章的站点，构建通常在一秒内完成，本地预览几乎没有等待感。

另一个关键点是**单文件可执行程序**。Hugo 没有运行时依赖，也不需要 Node.js 或 Ruby 环境，这意味着：

- 本地和 CI 的行为完全一致，不会出现"我电脑上好好的"
- CI 里装 Hugo 只需几秒，不用缓存一堆依赖

对比一下，Jekyll 需要 Ruby 环境，Hexo 需要 Node，Eleventy 也需要 Node。多一层运行时，就多一处可能出问题的地方。

## 主题选择

用的是 [PaperMod](https://github.com/adityatelange/hugo-PaperMod/)。选它的原因很实际：

| 关注点 | PaperMod 的表现 |
|---|---|
| 加载速度 | 纯 CSS，无 JS 框架，首屏快 |
| 中文支持 | 内置 CJK 排版处理，不会出现奇怪的字间距 |
| 搜索 | 内置本地搜索，不需要第三方服务 |
| 深色模式 | 跟随系统，也可手动切换 |

值得一提的是它不依赖 Hugo extended 版本（没有 SCSS 编译需求），部署时少一个约束。

## 与 Obsidian 的配合

整个仓库就是 Obsidian 的 vault，具体来说 vault 指向 `content/` 目录：

```
content/
├── posts/
│   ├── hello-hugo/
│   │   ├── index.md      ← 文章
│   │   └── screenshot.png ← 同目录的图片
│   └── another-post/
│       └── index.md
├── about.md
└── archives.md
```

每篇文章是一个文件夹（Hugo 叫 page bundle），图片和正文放在一起。这样做有两个好处：正文里写 `![](图片名.png)` 就能引用，路径短；要删一篇文章，删整个文件夹就行，不会留下孤儿图片。

Obsidian 里可以直接拖拽图片进笔记，默认就会存到当前文件夹，和这个结构天然匹配。

## 自动部署

`git push` 到 main 分支后，GitHub Actions 会自动完成构建和发布，流程是这样：

1. 检出代码，拉取完整 git 历史（用于计算文章的 `lastmod`）
2. 安装指定版本的 Hugo
3. 执行 `hugo --gc --minify` 生成静态文件到 `public/`
4. 上传产物并推送到 GitHub Pages

工作流里有两个细节值得说。

**并发控制**。如果连续 push 两次，我们不希望两次部署同时进行——那会让站点处于不一致的状态。所以设置了 `cancel-in-progress: false`，保证正在进行的部署跑完，排队中的旧任务作废。

**baseURL 显式传入**。没有在配置里写死域名，而是从 `configure-pages` 步骤动态获取。这样将来换自定义域名，只需要改仓库设置，不用动代码。

## 写作流程

日常写一篇新文章的完整流程：

```bash
# 1. 生成文章骨架
./scripts/new-post.sh "文章标题" --tags 标签1,标签2

# 2. 在 Obsidian 里写，写完把 draft 改成 false

# 3. 本地预览确认
hugo server -D

# 4. 发布
git add -A && git commit -m "post: 文章标题" && git push
```

推送后大约一分钟，站点就更新了。

## 小结

这套组合的核心优势是**没有需要维护的服务端**。没有服务器要打补丁，没有数据库要备份，没有运行时依赖会过期。整个站点就是一堆 Markdown 文件加一个 CI 配置，备份就是 `git clone`。

对一个写作优先的博客来说，这是最省心的结构。