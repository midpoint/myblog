+++
title = "cc-connect × 飞书双向指令通道搭建清单（Ubuntu 服务器）"
date = 2026-11-16T14:27:42+08:00
draft = false
tags = []
categories = []
+++

# cc-connect × 飞书双向指令通道搭建清单（Ubuntu 服务器）

目标：在飞书里给机器人发消息 → 服务器上的 Claude Code 执行 → 结果流式发回飞书。
原理：cc-connect 在服务器上运行，通过飞书**长连接（WebSocket）**收消息，**不需要公网 IP、域名或反向代理**。
依据：cc-connect 官方文档（github.com/chenhg5/cc-connect 的 INSTALL.md 与 docs/feishu.md，2026-11-16 核对）。

> 你现有的「CC → 飞书」单向通知（webhook 机器人）可以保留，两者不冲突，本清单是另起一条双向通道。

## 当前状态（2026-11-16 11:36 已打通 ✅）

- 桥已全线打通：飞书发消息 → CC 执行 → 回复流式发回飞书，11:33 日志见 `message received`，随后收到回信。
- 关键转折：旧应用建在**个人版租户**下时，所有 REST 调用都被平台策略拒绝（`code:21001`，拿机器人信息、发回复全被拒，长连接收消息却正常）。在**自己创建的企业版租户**下按路线 B 重建应用后，21001 消失，`feishu: bot identified` 正常出现。**结论：必须用企业版租户，个人版租户会报 21001。**
- 新应用的 ID（open_id 按应用隔离，旧 ID 全部失效）：
  - 新机器人 bot open_id：`ou_5e11d9d0c7e412028bc0d087b65601fd`
  - 你在新应用下的 user open_id：`ou_fb2739338fa93203d35f7d9f11ff4435`
  - 旧应用下的你：`ou_8a91f065ce22ff138bb5afb0702de56b`（已失效，别再用）
- ⚠️ 待办 1：`admin_from` 可能还填着旧 ID `ou_8a91…`，`/dir` 等管理员命令会被拒——把它换成新 ID `ou_fb27…` 再重启一次。`allow_from` 扫码绑定时已自动回填新 ID。
- ⚠️ 待办 2：**daemon 还没装**——现在还是前台跑，SSH 一断桥就停。装：`cc-connect daemon install --config <这份 config.toml 的绝对路径>` + `sudo loginctl enable-linger $USER`，再 `cc-connect daemon status` 确认 running。
- ⚠️ 注意：实际在用的 config 是当前目录的 `./config.toml`（日志 `path=config.toml`），不是 `~/.cc-connect/config.toml`，改配置和装 daemon 时别指错文件。
- `work_dir` 不会自动跟随终端里 CC 的目录（cc-connect 拉起的是自己的 CC 进程，无同步机制）。运行时切换用飞书里 `/dir <路径>` + `/new`；想多项目并行，见下方「多工作区」。
- 今早还遇到过模型名 `group/deepseek[1m]` 在 SDK 模式下被拒（`unrecognized_model`，进程被杀）；10:27 那轮 `turn complete` 已正常完成，之后未再出现——若复发，按第 8 节模型那行定位。
- **一项目一群已采用**（多工作区布局，见下方）；**群聊免 @ 直发已开启并验证可用**（2026-11-16 14:24 确认）：权限 `im:message.group_msg` 已加并发布 + 配置 `group_reply_all`，见下方「群聊免 @ 直发」。注意开启后在已启用群里发的每一句都会成为 CC 指令，只适合项目专用群。
- **消息精简**：过程消息（思考、工具调用）太多时用 `[display] mode = "quiet"`，只保留权限确认卡片和最终结果，见下方「精简消息：quiet 模式」。

### 多工作区（multi-workspace，一项目一聊天，并行跑）

```toml
[[projects]]
name = "chatchat"
mode = "multi-workspace"
base_dir = "/home/mj/projects"   # 所有项目的父目录

[projects.agent]
type = "claudecode"
# 这个模式下不用 work_dir
```

- 项目文件夹都放在 `base_dir` 下；每个项目在飞书里建一个群（机器人拉进去），群里发一次 `/workspace bind <文件夹名>` 绑定一次即可；之后在哪个群说话，CC 就在哪个项目里干活，各群会话隔离、可同时跑。
- 更细粒度：平台段加 `thread_isolation = true`，一个群里不同话题可绑不同项目。

### 精简消息：quiet 模式（只收确认 + 最终结果）

默认 `full` 模式下，CC 的思考过程和每次工具调用都单独发一条消息，很吵。改成 quiet 后，过程消息全部隐藏，只剩两类：**需要你确认的权限卡片**（独立消息，不受影响）和**最终结果**（全程输出合并进一张卡片原地更新）。

在 config.toml 靠前位置（第一个 `[[projects]]` 之前）加全局段：

```toml
[display]
mode = "quiet"   # full（默认，逐条发）/ compact（隐藏思考和工具，文字逐段发）/ quiet（全合并一张卡）
# 可选再关掉回复末尾的状态行：
# reply_footer = false           # 关掉 token 统计行
# show_context_indicator = false # 关掉 [ctx: ~N%] 上下文提示
```

配套（建议一起加）：quiet 模式下卡片是原地更新的，飞书不会为「编辑消息」推送提醒，容易不知道任务已完成。在飞书平台段 `[projects.platforms.options]` 加：

```toml
done_emoji = "Done"   # 每次任务完成，机器人在你的消息上贴 ✅ 作为完成信号
```

改完重启 cc-connect 生效。想临时看详细过程，把 mode 改回 `compact` 或 `full` 重启即可，不影响会话。

### 群聊免 @ 直发（机器人直接读群消息）

默认群里必须 @机器人它才响应。免 @ 需要**两处都改**，缺一不可（2026-11-16 已按此开启并验证可用）：

1. **飞书平台层**：应用权限加 `im:message.group_msg`（获取群组中所有消息，敏感权限），并**创建新版本发布**。不开这个权限，飞书只把 @ 了机器人的群消息推给应用，cc-connect 再怎么配也收不到。
2. **cc-connect 配置层**：飞书平台段 `[projects.platforms.options]` 加一行（二选一），改完重启：

```toml
group_reply_all = true                                # 所有群免 @
# 或只限定指定群（群 ID 在群里发 /status 可见，或看日志里的 oc_ 值）：
group_reply_all_chats = ["oc_项目群1", "oc_项目群2"]
```

- ⚠️ 开启后，你在已启用群里发的**每一句**都会成为 CC 指令——只适合项目专用群；有闲聊的群用名单制或不开。`allow_from` 白名单仍生效，别人发的不会触发。私聊本来就不用 @，不受此设置影响。

---

## 0. 前提（顺序不能反）

- [ ] 服务器上 Claude Code 已安装且**已登录可用**：`claude --version` 能跑、先随便开一次会话确认登录态正常
  （cc-connect 只是桥，启动时会检查 agent 在不在；CC 没装好它会直接报错退出）
- [ ] Node.js 18+：`node -v`（走 npm 安装路线时需要）
- [ ] ⚠️ **不要在 Claude Code 的会话里面启动 cc-connect**（CLAUDECODE 环境变量会冲突）。所有 cc-connect 命令都在一个**普通的 SSH 终端**里执行

## 1. 安装 cc-connect

```bash
npm install -g cc-connect
cc-connect --version
```

- [ ] npm 下载慢/失败时改用官方二进制：
  `curl -L -o cc-connect https://github.com/chenhg5/cc-connect/releases/latest/download/cc-connect-linux-amd64 && chmod +x cc-connect && sudo mv cc-connect /usr/local/bin/`

## 2. 先跑一次，生成配置

```bash
cc-connect        # 首次运行自动生成 ~/.cc-connect/config.toml，然后 Ctrl+C 停掉
```

- [ ] 确认 `~/.cc-connect/config.toml` 已生成

## 3. 接入飞书：两条路线，二选一

### 路线 A：扫码快速配置（推荐，省掉手动建应用）

```bash
cc-connect feishu setup --project my-project
```

- [ ] 终端会打印二维码和 URL，用**手机飞书 App 扫码**，按提示完成机器人创建/授权
- [ ] 命令会自动把 `app_id`、`app_secret`、`allow_from`（白名单）写回 config.toml；扫码流程中飞书通常会**预配好权限与事件订阅**
- [ ] 扫码后仍建议去飞书开放平台核验一遍：应用已发布、权限状态正常、可用范围包含你自己
- [ ] `--project` 名字随便取（如 `my-project`）；项目不存在会自动创建
- [ ] 如果想改工作目录，改 config.toml 里该项目的 `work_dir` 为你跑 CC 的项目路径

### 路线 B：手动在飞书开放平台建应用（想完全掌控时用）

1. [ ] open.feishu.cn → 控制台 → **创建企业自建应用**（⚠️ 2026-11-16 实测：建在**个人版租户**下会报 `21001 Access denied due to platform policy`，REST 调用全被拒，必须用**企业版租户**——自己免费创建一个企业即可，你就是超级管理员）
   - 名称填 `cc-connect`，描述填 `Claude Code 远程助手`
2. [ ] 左侧「凭据与基础信息」记下 **App ID**（cli_ 开头）和 **App Secret**（妥善保存）
3. [ ] 左侧「应用能力」→「机器人」→ **启用机器人**
4. [ ] 左侧「权限管理」搜索并添加以下权限，然后点「申请发布」：

   | 权限 | 标识 | 用途 |
   | --- | --- | --- |
   | 获取与更新用户基本信息 | `contact:user.base:readonly` | 获取用户信息 |
   | 获取群组中用户@机器人消息 | `im:message.group_at_msg:readonly` | 接收群消息 |
   | 读取单聊消息 | `im:message.p2p_msg:readonly` | 读取私聊内容 |
   | 以应用身份发送群消息 | `im:message:send_as_bot` | 回复消息 |
   | 获取群组中所有消息（敏感权限） | `im:message.group_msg` | 机器人免 @ 读群消息必需（本机已启用）；加完必须发布新版本才生效，cc-connect 侧还要配 `group_reply_all`，见顶部「群聊免 @ 直发」 |

5. [ ] 左侧「事件与回调」→「事件配置」→ 订阅方式选 **「使用长连接接收事件」** → 保存 → 添加事件：**接收消息 `im.message.receive_v1`**
6. [ ] 同页「回调配置」→ 同样选长连接 → 添加回调：**卡片回调 `card.action.trigger`**
   （不加这个，飞书里点权限确认等卡片按钮会没反应/超时；实在加不了，就在 config.toml 里设 `enable_feishu_card = false` 退回纯文本交互）
7. [ ] 左侧「版本管理与发布」→ 创建版本 → 保存并发布（个人版发布后立即生效；企业版需管理员审批）
8. [ ] 把凭证绑到 cc-connect（二选一）：
   ```bash
   cc-connect feishu setup --project my-project --app cli_你的AppID:你的AppSecret
   ```
   或手动把 `app_id` / `app_secret` 填进 config.toml 的 feishu 平台段（结构见第 4 节）

## 4. config.toml 参考结构（对照检查用）

```toml
[[projects]]
name = "my-project"

[projects.agent]
type = "claudecode"

[projects.agent.options]
work_dir = "/你跑CC的项目绝对路径"
mode = "default"
# mode 可选: default / acceptEdits / plan / auto / bypassPermissions(yolo)
# 远程通道建议保持 default: 敏感操作会在飞书里弹确认; 不要轻易用 bypassPermissions

[[projects.platforms]]
type = "feishu"

[projects.platforms.options]
app_id = "cli_axxxxxxxxxxxx"
app_secret = "xxxxxxxxxxxxxxxx"
# allow_from = "ou_你的open_id"   # 白名单, 见第 6 节, 务必确认不是 "*"
```

- [ ] `work_dir` 是绝对路径，指向你希望 CC 操作的项目目录
- [ ] 一个 config 可以放多个 `[[projects]]`，不同项目目录分别桥接

## 5. 启动与验证

```bash
cc-connect        # 前台先跑一次验证, 别急着装服务
```

- [ ] 日志出现以下三行即长连接成功：
  ```
  level=INFO msg="platform started" project=my-project platform=feishu
  level=INFO msg="cc-connect is running" projects=1
  [Info] connected to wss://msg-frontier.feishu.cn/ws/v2?...
  ```
- [ ] 飞书里搜索机器人名称 → **私聊**发一句「你好，报一下当前目录」→ 能收到 CC 的流式回复 = 通了
- [ ] 群聊用法：群设置 → 群机器人 → 添加这个机器人；群里默认要 **@机器人** 才会触发回复
- [ ] 试一次需要确认的操作（如让它改个小文件），确认飞书里能收到权限确认卡片且按钮可点

## 6. 常驻运行（systemd）

```bash
cc-connect daemon install --config ~/.cc-connect/config.toml
sudo loginctl enable-linger $USER
cc-connect daemon status
```

- [ ] ⚠️ **`enable-linger` 必做**：用户级 systemd 服务默认在你最后一个 SSH 会话断开时被停掉；不开启 linger，你一关终端桥就断了（daemon install 时若未开启它会给出警告）
  （替代方案：`sudo cc-connect daemon install ...` 装成系统级服务，与登录会话无关）
- [ ] ⚠️ `--config` 必须指向你实际在用的那份 config.toml 的**绝对路径**（本次实测是当前目录的 `./config.toml`，不是 `~/.cc-connect/config.toml`），否则服务会读另一份没修好的配置
- [ ] 常用命令：`cc-connect daemon start|stop|restart|status`；看日志 `cc-connect daemon logs -f`

## 7. 安全（重要，别跳过）

- [ ] **白名单**：config.toml 里确认 feishu 平台的 `allow_from` 只包含**你自己的**飞书 open_id（ou_ 开头），不要留 `"*"`
  - 路线 A 扫码时会自动回填；路线 B 手动绑凭证时，setup 也会处理 `allow_from`，绑完打开 config.toml 核对一眼
  - 找不到自己的 open_id 时：先启动 cc-connect，给机器人发一条消息，再看 `cc-connect daemon logs`（或前台日志）里记录的发送者 ID，填回去后重启服务
- [ ] 心里有数：能给这个机器人发消息的人 = 能让服务器上的 CC 执行命令的人。机器人不要拉进无关的群，可用范围只留自己
- [ ] App Secret 只存在服务器的 config.toml 里，不要发到聊天/群里

## 8. 常见问题速查

| 现象 | 查什么 |
| --- | --- |
| 发消息没反应 | 服务在跑吗（daemon status）→ 日志里长连接连上没 → 事件订阅有 `im.message.receive_v1` 吗 → 改过订阅/权限后**重新发布版本**了吗；换了新应用 = 换了新机器人，旧私聊窗口/旧群里的机器人已下线，要重新搜新机器人名或重新拉进群 |
| 回复发不出去，报 21001 | 应用建在个人版租户下会被平台策略拒 REST 调用，换企业版租户重建应用并换凭证（`cc-connect feishu bind`）；企业版还要在管理后台审批通过、可用范围包含自己 |
| 事件订阅里「已添加事件」是空的、加不上 | 顺序锁：先确认机器人能力已启用、权限已批，再到「事件配置」先选**使用长连接接收事件**并点**保存**，保存成功后再点「添加事件」；若按钮本身是灰的或报「角色未授权」，是你在这个租户里没有开发角色——自己创建的企业就用创建者账号登录 admin.feishu.cn 给自己开权限，或换自己当管理员的租户重建 |
| CC 进程被杀，报 `unrecognized_model`（如 `group/deepseek[1m]`） | 模型名是网关分组写法，SDK 模式不认；`grep -rn "group/deepseek" config.toml ~/.claude/settings.json` 定位来源，换成网关真正的模型 ID（如去掉 `group/` 前缀和 `[1m]` 后缀），或在 config 里用 `[[projects.agent.providers]]` 正式配 provider |
| `/dir` 等管理员命令被拒 | `admin_from` 里还是旧应用下的 open_id（open_id 按应用隔离）；换成新应用下日志里 `user=` 那串再重启 |
| 想多项目同时操作 | 单 work_dir 一次只能一个项目；改 `mode = "multi-workspace"` + `base_dir`，每群 `/workspace bind <文件夹名>`，见顶部「多工作区」 |
| 群里不 @ 机器人没反应 | 两处缺一不可：应用权限 `im:message.group_msg` 加了**并发布新版本**了吗；config 里飞书平台段有 `group_reply_all = true`（或该群在 `group_reply_all_chats` 名单里）吗；改完重启了吗，见顶部「群聊免 @ 直发」 |
| 消息太多、刷屏 | `[display] mode = "quiet"`：只留权限确认和最终结果；再加飞书平台段 `done_emoji = "Done"` 作完成信号，见顶部「精简消息：quiet 模式」 |
| 启动就退出，报 claude CLI not found | CC 没装好或不在 PATH；先在同终端确认 `claude --version` |
| 在 CC 会话里启动报错 | 换一个普通终端启动，别在 CC 会话内 |
| 提示 session already in use | 之前的 CC 进程还占着会话，在飞书里发 `/new` 开新会话 |
| 想看详细日志 | config.toml 里 `[log] level = "debug"` 后重启 |

---

参考：官方仓库 https://github.com/chenhg5/cc-connect ；飞书接入指南 docs/feishu.md；安装指南 INSTALL.md（同仓库）。
