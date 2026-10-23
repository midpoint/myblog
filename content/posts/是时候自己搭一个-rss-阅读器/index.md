+++
title = "是时候自己搭一个 RSS 阅读器"
date = 2026-10-23T15:14:46+08:00
draft = false
tags = []
categories = []
+++

**作者：Kevin Purdy ｜ 2026年10月16日**

> 原文：[It’s time to make your own RSS reader](https://tailscale.com/blog/self-hosted-rss-reader-freshrss)（Tailscale Blog）

也许你没感觉到，但互联网上仍然存在一种阅读方式：由**你自己**（而不是算法）来挑选、整理你想读的内容。这种方式就是 RSS（简易信息聚合）。你可以免费地把它自托管在自己手里，还可以借助 Tailscale 搭出一个随时随地都能访问的阅读器。

为什么要动手做这个听起来有点"复古"的项目？也许你只是想在刷信息流的时候少一点 doom 式焦虑；也许你已经受够了那些为注意力优化的设计、千篇一律的软文广告，以及同一条"新闻"被推荐 12 遍。又或者，如今是 2026 年，你可能想给 AI 智能体喂一个聚焦的订阅源，让它帮你挑出重点。

本文将带你搭建 **FreshRSS**——它既是 RSS 聚合器（负责抓取订阅源的中心枢纽），也是阅读器（负责把订阅源内容展示给你）。它是最容易自托管的项目之一，无论你家里有没有专门的硬件。而且我们会通过 Tailscale 给 FreshRSS 分配一个专属的安全 URL：它完全不暴露在公网上，但你又能轻松访问。

RSS 就是这种"非算法"的解药：你自己选择关注哪些网站（有时还能细到具体主题或作者），然后就等着接收它们的更新。用过几次 RSS、尝到它带来的清爽感之后，你就很难再回到别的阅读方式了。它有一种独立、小众的气质，因为这种个性化、高密度的阅读体验从来就不是主流默认值。不过这也挺好的——说实话，它就是很香。

在开始搭建之前，你需要先有一个 Tailscale 账号。Personal 个人版是免费的，设备数量不限、支持多用户，用来跑这么一个读新闻的小项目完全够。

---

## 第一步：为 FreshRSS 配置 Docker

我们用 Docker 来做，因为 Docker 就是 FreshRSS 官方推荐的部署方式。如果你以前从没装过 Docker 容器，听起来可能有点吓人。但我们这次从小处入手，用一个已经把 Tailscale 直接内置进去的配置文件来启动。不管你是部署在 VPS（虚拟专用服务器）、一台旧笔记本、树莓派还是 Mac mini 上，FreshRSS 的安装步骤用 Docker 都会大同小异。

下面是最省心的路线：

1. **桌面端装 Docker**：如果你那台 7×24 小时开机的机器跑的是 Windows 或 macOS，就去下载对应系统的 Docker Desktop 应用。装好后启动它，然后跟着往下走。
    
2. **打开终端**：在没有桌面环境的 Linux 系统（比如 VPS）上，你本来就在终端（严格说叫 shell）里。Windows 上启动"终端"（Terminal）或 PowerShell 都行；macOS 上直接打开 Terminal；树莓派系统或其他带桌面的 Linux 上，找到名字叫 terminal 或 “term” 的应用打开即可。
    
3. **检查是否已有较新的 Docker**：在终端输入下面这行命令并回车：
    
    ```
    docker compose version
    ```
    
    如果返回了版本号，就可以继续往下走。如果没有，运行下面这个脚本——它会在几乎所有主流 Linux 系统上安装并更新 Docker：
    
    ```
    curl -fsSL https://get.docker.com | sh
    ```
    
    然后退出 Linux 系统再重新登录一次，之后你就可以在关键命令前不用再加 `sudo` 也能用 Docker 了。
    
4. **修复权限**：如果你没有跑上面那个 Docker 官方脚本，就在终端里输入下面这条命令，让自己能执行 Docker 的关键操作：
    
    ```
    sudo usermod -aG docker $USER
    ```
    
    （注意 `-G` 是大写）。然后退出并重新登录，或者运行 `newgrp docker` 让自己立即进入正确的用户组。
    
5. **测试一切正常**：在终端输入下面命令，拉取一个测试镜像：
    
    ```
    docker run hello-world
    ```
    

关于 Docker 的安装和容器的启动，我们在一期 Docker + Tailscale 入门 YouTube 视频里讲过。如果本文里有哪一步你不太理解，Alex 的视频示例可能会有帮助。

---

## 第二步：建一个 Docker 目录

在你的设备（或 VPS）上建一个目录，用来存放 Docker 容器相关的东西，比如 FreshRSS 的配置。考虑到以后可能还会有别的项目，最好把它放在你的用户主目录里。在 Linux、macOS（以及可 SSH 登录的 VPS）上，命令长这样：

```
mkdir -p ~/docker
```

这里的 `~` 是主目录的简写，实际路径是 `/home/你的用户名/docker`（把"你的用户名"换成你自己的）。在 Windows 的 PowerShell 里则是：`mkdir $HOME\docker`。

---

## 第三步：下载 ScaleTail 的 FreshRSS 项目

ScaleTail 是一个仓库，里面装满了各种已经配好的容器，一键启动就能自动接入你的 Tailscale 网络（tailnet）。我已经把 FreshRSS 加进了 ScaleTail 仓库。你要做的就是下载这个目录、改几行配置文件、然后启动容器。

如果你用的是 macOS 或 Linux，可以用 `git` 命令把整个 ScaleTail 仓库克隆下来（它很小），然后进到 FreshRSS 目录里操作：

```
cd ~/docker
git clone https://github.com/tailscale-dev/ScaleTail.git
cd ScaleTail/services/freshrss
```

有些 macOS 用户会被提示安装"Xcode Command Line Tools"，装上就好——你现在显然已经是开发者了。

如果你在 Windows 上，而且 `git` 命令没跑通，我建议你别再费劲往 PowerShell 里装 Git 了，得不偿失。改成直接下载 ScaleTail 仓库的 ZIP 压缩包，把 ZIP 文件移到你刚才在主目录里建的那个 `docker` 文件夹中，就地解压，会得到一个 `ScaleTail-main` 目录。然后进到 `ScaleTail-main/services/freshrss` 里即可。（后文凡是出现 `ScaleTail` 目录名的地方，Windows 用户都换成 `ScaleTail-main`。）

现在我们来把这套配置好，让它通过 Tailscale 连接。

---

## 第四步：获取并填写你的密钥和变量

如果你还没注册 Tailscale 账号，先注册一个，并在跑 Docker 的那台设备上安装 Tailscale。一旦 Tailscale 在那台设备上跑起来，你就能从 tailnet 里的任何其他设备访问它。这样以后排查问题就方便多了，尤其是当这台设备没接屏幕和键盘的时候。你还可以后续配置 Tailscale SSH，让访问更省事。

在 Tailscale 的网页管理控制台里，进入 **Settings（设置）> Keys（密钥）**，点击 **Generate Auth Key（生成认证密钥）** 按钮。给这个密钥起个名字，比如 `freshrss`。如果你看到"Pre-approved（预批准）"选项，把它打开。

点击生成密钥后，把密钥复制下来——**先别关这个窗口**，下一步马上要用。

在你的 `~/docker/ScaleTail/services/freshrss` 目录里有一个 `.env` 文件，我们要把密钥填进去。如果你有喜欢的文本编辑器，直接用它打开 `.env`；没有的话，在 macOS 和 Linux 上可以运行：

```
nano ~/docker/ScaleTail/services/freshrss/.env
```

这会在一个极简的终端编辑器 `nano` 里打开 `.env`。用方向键移到 `TS_AUTHKEY=` 这一行，把光标放到等号后面。粘贴时，Mac 用 Command+V，Linux 用 Control+Shift+V。这一行最终应该长这样：`TS_AUTHKEY=ts-abcxyz …`。

粘好密钥后先别急着关文件，还有几处要改：

- 在 `TZ=` 这一行的等号后面填你的时区，用"tz"格式，比如 `Asia/Shanghai`。
- `TAILNET_NAME=` 这一项，去你的网页管理控制台的 DNS 设置里看你的 Tailnet DNS 名称。如果还没改过，可以点 “Rename tailnet” 起一个比那串默认字母数字好记的名字。如果你这是 Tailscale 上的第一个容器，正好顺手摇一个新的半随机名字。不管怎样，把控制台里显示的那部分粘进来，比如 `velociraptor-noodlefish.ts.net`。
- `ADMIN_PASSWORD` 和 `ADMIN_API_PASSWORD` 旁边各填一个像样的密码——前者保护你的 FreshRSS 管理面板登录，后者保护外部对其订阅源和数据的访问。
- `ADMIN_EMAIL` 填你自己的邮箱。
- 最后，如果你不想让这个节点在 tailnet 里显示为 `freshrss`，就在 `.env` 文件顶部附近的 `SERVICE=` 那一行改掉名字。

填完密钥、时区、tailnet 名、密码和邮箱（呼！）之后，依次按：Control+O（"Write out"，即保存）、回车（确认文件名）、Ctrl+X（退出）。

Windows 用户最推荐用 Visual Studio Code（VSCode）。装好后用它打开 `docker\ScaleTail-main\services\freshrss` 目录里的 `.env` 文件，把上面提到的所有内容都改好：认证密钥、时区、tailnet 名（可选）、密码、邮箱。然后在 VSCode 右下角看一眼，确保显示的是 `LF`；如果显示 `CRLF`，就改成 `LF`（"Linux 文件结尾"，这事有点怪），再保存文件。

---

## 第五步：启动 FreshRSS

是时候启动我们的中心枢纽了。在终端里，先确认你正处在放着 `.env` 和 `compose.yaml` 的那个目录（如果你沿用了上面的布局，就是 `cd ~/docker/ScaleTail/services/freshrss`），然后输入：

```
docker compose up -d
```

这是告诉 Docker：用你的 compose 文件把容器"起来"（即让它运行起来）；`-d` 是"detached（分离模式）"的意思，代表即使你最后关掉这个终端，它也会继续在后台跑。

你应该会看到 Docker 拉取镜像、创建网络和卷（虚拟磁盘）、然后逐个启动容器。它们成功了吗？可以用 `docker compose ps` 查看每个容器的状态。`tailscale-freshrss` 最终应该显示 `healthy`（健康），`app-freshrss` 显示 `running`（运行中）。如果不对，可以跑 `docker compose logs tailscale` 看看日志。如果你看到关于密钥或"auth"过期、无效的报错，就去新建一个 Tailscale 密钥，填回 `.env` 文件，再跑一次 `docker compose up -d`。

等 FreshRSS 运行健康、Tailscale 也装好并连上之后，打开浏览器访问：

```
http://<设备名>.<tailnet名>.ts.net
```

把 `<设备名>` 换成你起的节点名（比如 `freshrss`），把 `<tailnet名>` 换成你的 tailnet 名（比如 `noodlefish-velociraptor`，可以在管理控制台的 DNS 设置里找到）。

记得去 **Settings（设置）> Configuration（配置）> Display（显示）** 里挑一个你喜欢的主题。（配图里用的是 Nord 主题。）

---

## 第六步：配置 FreshRSS

在浏览器里打开 FreshRSS，用你刚才在 `.env` 里设置的用户名密码登录。

进来了。接下来你得把订阅源收集起来。通常，你可以直接把一个网站的主页 URL 粘进 FreshRSS 的"添加订阅源"输入框，它会自动找到 RSS 地址。

如果这样没反应，就翻到你感兴趣网站的页脚，那里常常能找到 RSS 或 Feeds 的链接——有时它们只藏在网站的博客或新闻栏目里。EFF 的 RSS 指南在如何整理订阅列表方面有很好的建议，包括怎么从社交网站、YouTube、Reddit、Tumblr 等地方抓取订阅源。

### 把其他阅读器（以及 AI）接到 FreshRSS 上

你想把 FreshRSS 配合 NetNewsWire 或其他阅读 App 一起用？想把它开放给 AI 智能体，让它扫描你的订阅源、把最相关的新闻提醒给你？都只要点几下鼠标。

在 FreshRSS 的设置里，进入 **Authentication（认证）** 一节，勾选 “Allow API access（允许 API 访问）"，点击提交。接着在设置的 **Profile（个人资料）** 里往下翻一点，你应该能看到 API 密码已经设好了（就是你在 `.env` 里填的那个）。如果没有，就在这里设一下再提交。

打开这个 API 之后，你就能把 NetNewsWire、Reeder、FeedMe 等各种 App 接到 FreshRSS 上。以 NetNewsWire 为例：进入 Settings > Add Account，在 Self-Hosted（自托管）分类里选 FreshRSS。填入你的 API URL——要么是你的 tailnet 地址：

```
https://freshrss.<你的tailnet>.ts.net/api/greader.php
```

要么是本地地址：

```
http://<IP地址>:8080/api/greader.php
```

然后填用户名和你的 **API 密码（不是网页登录密码！）**，就可以开始阅读了。

想把 Claude、ChatGPT、Hermes 或其他大模型接到你的订阅源上？用的是同一个 API URL：你的智能体可以 POST 你的用户名和 API 密码来换取一个认证令牌，然后就开始干活。

---

## 现在，你带着力量阅读了

我自己有一个大模型在读我的 FreshRSS 订阅源，每天两次，为我整理出 Tailscale 技术领域里最值得关注的要点。它能抓住有趣的东西、把上下文交代清楚。但它更妙的作用是：推着我主动去翻完整的订阅列表——既看看那些我**没料到**会出现的东西，也顺便补一补视野之外的新闻和动态。

Google Reader 的死亡是互联网写作者、读者和爱好者心中的一个标志性时刻，但它并不是 RSS 的死亡。它或许标志着一件大事：在大多数人眼里，互联网那种"分布式、开放"的感觉从此变了味。它本应成为一记警钟。如果你想要的东西比那些顺着你的上网习惯精准投喂的内容更好，就得自己花一点心思去策展。你得自己去发掘、去分类，把那些有想法的观点和令人惊喜的"兔子洞"收进你的订阅列表。这是播种式的工作，时间越久回报越大。

出发吧，去收集一批订阅源，把它们安放在你自己的网络上。