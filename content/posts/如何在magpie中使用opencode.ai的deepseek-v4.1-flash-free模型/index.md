+++
title = "如何在magpie中使用opencode.ai的deepseek-v4.1-flash-free模型"
date = 2026-11-03T17:03:57+08:00
draft = false
tags = []
categories = []
+++

在 Magpie 里要用这个免费模型，不要走 DeepSeek 官方 provider，也不要填你自己的 OpenCode key——要装一个专门的社区插件，它用共享的公开凭据接入 Zen 免费池。

方法一：装 OpenCode Zen Free 插件（推荐）

命令行两步：

bash

```
magpie plugin add @magpie-community/opencode-zen-free-auth
magpie plugin login opencode-zen-free
```

登录时密钥一栏填 `public`——不需要个人 API key，填你自己的 key 也没用，它只认这个共享凭据，你的个人 Zen key 是填到 Magpie 内置的 OpenCode Zen provider 里用的。

图形界面同理：Magpie 顶部「插件」页搜 OpenCode Zen Free 安装，再登录、密钥填 `public`。

方法二：给目标 Agent 指派模型

插件会自动发现 Zen 当前的免费模型，模型名格式是 `opencode-zen-free/<模型ID>`，所以你要的这个就是：

```
opencode-zen-free/deepseek-v4.1-flash-free
```

在 Magpie 的 Agents 页，给你想用的 Agent（Claude Code、Codex、OpenCode 都行）选这个模型，开一个新会话生效；或者用命令行，套 Magpie 给 Agent 指派模型的通用格式：

bash

```
magpie codex opencode-zen-free/deepseek-v4.1-flash-free
magpie claude opencode-zen-free/deepseek-v4.1-flash-free
```

原理一句：Zen 的免费模型官方只发给“看起来像 OpenCode”的客户端，Magpie 内置预设和这个插件干的就是带上 OpenCode 的请求头去问，所以在别的工具里直接调 Zen 接口会被拒、在 Magpie 里能用——其预设代码里写得很直白：免费模型只服务 OpenCode，Magpie 就以 OpenCode 的身份去请求，且这个预设本身是免 key 的，提示就是 “free models need no key”。

拉不到模型时的排查：这正是有人提过的 bug——Zen 上线了这个免费模型但 Magpie 里刷不出来，官方已确认修复，要求 Magpie 升到 v0.1.1258 以上、插件升到 0.1.9 以上，然后刷新一次 provider 模型就会出现。所以如果你现在列表里没有 `deepseek-v4.1-flash-free`，先更新这两个，再刷新，别急着改配置。

如果安装失败：
这是网络问题，不是插件或配置的问题：`EOF` 是从 GitHub Releases 下载 Bun 1.4.2 时连接中途被掐断了——插件还没开始装，第一步拉 Bun 运行时就死在路上了。国内直连 GitHub 的 release 下载很常见，原样重试偶尔能成，反复 EOF 就得换路。

Magpie 官方给了两个现成的解法，按推荐顺序：

1. 开国内镜像（首选）  
打开 Magpie 应用 →「插件」页 → 打开 「国内镜像 / Mirrors in China」 开关，再装插件（直接在插件页里装，或回终端重跑你那条命令）。这个开关会让插件页的下载先走国内镜像：Bun 的安装包走 npmmirror 的二进制镜像、npm 包走 `registry.npmmirror.com`、插件列表走 jsDelivr，且 Bun 的 zip 仍然按官方 SHA-256 校验，不怕镜像给错文件。

纯命令行也有个兜底开关，就是优先级低一档（先试官方、网络出错才切镜像）：

bash

```
MAGPIE_MIRRORS=on magpie plugin add @magpie-community/opencode-zen-free-auth
```

官方说明：镜像兜底默认关闭，`MAGPIE_MIRRORS=on` 打开后，只在网络错误、429、5xx 这类情况下才切镜像——你这个 EOF 正好属于网络错误。你要是反复 EOF，还是用上面那个镜像优先的开关更干脆。

2. 你有本地代理的话（比如 Clash）  
Magpie 认 `MAGPIE_PROXY`，也认通用的 `HTTPS_PROXY` / `ALL_PROXY`，端口换成你自己的：

bash

```
HTTPS_PROXY=http://127.0.0.1:7890 ALL_PROXY=http://127.0.0.1:7890 \magpie plugin add @magpie-community/opencode-zen-free-auth
```

装成功后接着上一步的流程走就行：`magpie plugin login opencode-zen-free`，密钥填 `public`。