# dsh-workbench

DeepSeek Harness（dsh）**当前实际在用的 profile 快照** —— 本仓库内容等于本机
`~/.dsh/profiles/web` 的配置与依赖声明，用来整体替换先前那版 workbench 组合。

- **11 个 bundle**：2 个官方 + 8 个社区 + 1 个本地 fork（`dsh-insight`）
- **端口**：走 dsh 默认（3080）。要与源 profile 并存请用 `--port`，或按
  `cordis.patch.yml` 顶部注释追加一条 `webserver` 覆盖
- **实测环境**：dsh CLI `0.1.5-rc.1`（内置 `dsh-base` / `dsh-web-app` 为 `0.1.5-rc.2`）、
  Node `v24.14.0`、pnpm `11.22.0`

## 安装

```bash
gh repo clone Suguyun/dsh-workbench ~/.dsh/profiles/workbench
cd ~/.dsh/profiles/workbench
pnpm install

# 浏览器扩展半边（划词解读 + 浏览器工具需要；不装则这部分功能不可用）
./node_modules/.bin/dsh-insight install

dsh --profile workbench
```

`dsh-insight install` 会把扩展拷到
`~/Library/Application Support/dsh-insight/extension`，随后在 `chrome://extensions`
打开开发者模式，用「加载已解压的扩展程序」指向该目录。升级 `dsh-insight` 后需重跑一次。

## 依赖清单（按 bundle 加载顺序）

| # | 包 | 声明版本 | 作用 |
|---|----|---------|------|
| 1 | `@deepseek-ai/dsh-base` | 0.1.5-rc.2（随 CLI） | 核心：agent / session / llm / tools |
| 2 | `@deepseek-ai/dsh-web-app` | 0.1.5-rc.2（随 CLI） | Web 界面 |
| 3 | `dshmarket` | `^1.58.0` | 可视化插件市场：浏览、搜索、一键安装 |
| 4 | `dsh-better-sidebar` | `^0.19.1` | VSCode 式右侧边栏（文件/编辑器/终端/git/浏览器），按会话隔离 |
| 5 | `dsh-context` | `^0.54.4` | 上下文洞察与管理（仪表盘 + context 命令） |
| 6 | `@liustack/modsearch` | `^5.10.4` | 联网搜索 / X 搜索 / 网页抓取 |
| 7 | `@deepseek-harness-tui/dsh-tui` | `^0.10.2` | 交互式终端界面 |
| 8 | `dsh-restart-button` | `^0.1.2` | 侧栏一键重启按钮（`POST /dsh-restart`） |
| 9 | `dsh-smart-restart` | `^0.5.1` | 检测服务重启并在启动后唤醒主 agent |
| 10 | `dsh-cool-theme` | `0.6.1` | 主题（34 套预设、明暗跟随） |
| 11 | `dsh-insight` | `github:Suguyun/dsh-insight` | 浏览器伴侣：划词即解读 + 让 agent 读页面/抓包/驱动浏览器 |

前两项由 dsh CLI 自带，因此不出现在 `dependencies` 里，但仍必须列在
`dsh.profile.bundles` 中才会加载。列表就是加载顺序。

## dsh-insight

本仓库唯一**不在 npm 上**的依赖，用 `github:` 协议直接指向源码仓库：

- 仓库：<https://github.com/Suguyun/dsh-insight>
- 它是 [dsh-chrome](https://github.com/stuarthu/dsh-chrome)（MIT，© 2026 Stuart Hu）的 fork，
  把上游的浏览器伴侣做成「划词即解读 + 侧栏多轮追问 + Markdown 渲染」，
  并沿用其有界化的页面注入实现。
- 尚未发布到 npm；`github:` 不带 ref 时跟随默认分支 `main`，所以
  `pnpm update dsh-insight` 会拉到最新提交。上游发布 npm 包后可以把声明换成版本号。

它的 bundle patch 挂了 3 行（`dsh-insight-bridge`、`dsh-insight-browser-tools`、
`dsh-insight-selection`），第 4 行 `dsh-insight-page-injector` 被注释掉 ——
即**页面正文不会自动进入上下文**。

## 页面自动注入（默认关闭）

要打开必须**两处一起开**，只开一处会静默空转、不报错：

1. 按 `dsh-insight/cordis.patch.yml` 的说明挂上 `dsh-insight-page-injector`；
2. 扩展侧执行 `chrome.storage.local.set({ insight_autopush: true })`。

代价：你浏览的每个页面正文都会进模型上下文；当活动标签页恰好是 dsh 自己的会话界面时，
正文就是整段对话、而对话里又含有先前注入的「当前页面」消息，会自我复制逐轮放大。
dsh-insight 的实现是有界版本（单次 4000 字符、命中自身回声整条跳过、单会话累计 60000 字符封顶）。

## 敏感信息与隐私

本仓库是**公开**的，因此刻意不收录：

- `~/.dsh/.credentials.yaml` —— 模型与服务凭据
- `~/.dsh/sessions/`、`attachments/`、`storages/` —— 会话记录与运行数据
- `node_modules/`、`pnpm-lock.yaml` —— 只记录依赖声明，不锁定解析结果

`settings.yaml` 是附带的一份全局设置备份，**已脱敏**：provider 名、`apiKeyEnv`、
`baseURL` 全都换成了占位符 —— 直接照抄连不上任何模型，请改成你自己的。
它不属于 profile，要用请自行合并进 `~/.dsh/settings.yaml`。

## 更新依赖

```bash
dsh plugin --profile workbench add <pkg>      # 安装并自动加入 bundles
dsh plugin --profile workbench remove <pkg>   # 移除
```

也可手工编辑 `package.json` 的 `dsh.profile.bundles` 调整顺序或删除条目。

本仓库是**手动快照**，不会自动跟随本机变化；改动后请同步 `package.json`。

## 许可

MIT，见 `LICENSE`。`dsh-insight` 同为 MIT，并派生自 dsh-chrome（MIT，© 2026 Stuart Hu）。
