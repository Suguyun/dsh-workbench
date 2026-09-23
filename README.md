# dsh-workbench

DeepSeek Harness（dsh）的**整机迁移包**。把本机实际在用的 dsh 配置导出成一个可版本化的仓库，
换机器时拉下来跑一次脚本，就能把「profile + 插件 + agent 预设 + 全局设置」还原回去。

导出时间：**2026-09-23** · 实测环境：dsh CLI `0.1.5-rc.1`（内置 `dsh-base`/`dsh-web-app` 为 `0.1.5-rc.2`）、
Node `v24.14.0`、pnpm `11.22.0`

## 一句话：能迁移什么，不能迁移什么

| | 内容 |
|---|---|
| ✅ **能** | 插件依赖与加载顺序、组合树与覆盖层、agent 预设、全局设置（脱敏）、浏览器扩展的宿主插件 |
| ❌ **不能** | 凭据真值、历史会话、运行状态、浏览器里的扩展设置、以及 dsh CLI 本体 |

**它不会把「整台 dsh」搬过去。** 它搬的是「可版本化的那部分配置」，剩下的必须手工补 —— 见
[迁移后必须手工做的事](#迁移后必须手工做的事)。

## 目录结构

```
dsh-workbench/
├── bootstrap.sh                 # 迁移脚本（默认预演，--apply 才写文件）
├── settings.yaml                # 全局设置备份，已脱敏 →  ~/.dsh/settings.yaml
├── credentials.example.env      # 凭据字段清单（没有真值）→  ~/.dsh/.env
├── profiles/                    # →  ~/.dsh/profiles/<name>/
│   ├── web/                     #   主 profile（11 个 bundle）
│   └── dsh-tui/                 #   纯终端 profile
├── agent-presets/               # →  ~/.dsh/.agent-presets/<name>/
│   └── liangshen/               #   「梁神模式」预设
├── LICENSE
└── README.md
```

## 新机器迁移

### 一键（推荐）

```bash
gh repo clone Suguyun/dsh-workbench ~/dsh-workbench
cd ~/dsh-workbench

./bootstrap.sh              # ① 先预演：只打印计划，不写任何文件
./bootstrap.sh --apply      # ② 确认后执行
```

`bootstrap.sh` 做的事：把 `profiles/*` 和 `agent-presets/*` 铺到 `$DSH_HOME`，逐个目录跑
`pnpm install`，最后执行 `dsh-insight install`。已存在的 profile / 预设**默认跳过**，
要覆盖加 `--force`（覆盖前会先备份到 `$DSH_HOME/backups/migrate-<时间戳>/`）。

常用开关：

| 开关 | 作用 |
|---|---|
| `--settings` | 连带安装 `settings.yaml`（默认**不动**你的全局设置，装前会备份旧的） |
| `--force` | 已存在的 profile / 预设也覆盖 |
| `--no-install` | 只铺文件，不跑 `pnpm install` |
| `--no-extension` | 不跑 `dsh-insight install` |
| `--no-cli` | 跳过 dsh CLI 的存在性检查 |

可覆盖的环境变量：`DSH_HOME`（默认 `~/.dsh`）、`DSH_CLI_VERSION`（默认 `0.1.5-rc.1`）。

### 手工等价步骤

```bash
# 1. 先装 CLI —— 本仓库不含 dsh 本体
npm i -g @deepseek-ai/dsh@0.1.5-rc.1

# 2. profile 必须落在 ~/.dsh/profiles/<名字>，dsh 只从这里发现 profile
mkdir -p ~/.dsh/profiles
cp -R profiles/web ~/.dsh/profiles/web
cd ~/.dsh/profiles/web && pnpm install

# 3. 可选的第二个 profile 与 agent 预设
cp -R profiles/dsh-tui ~/.dsh/profiles/dsh-tui && (cd ~/.dsh/profiles/dsh-tui && pnpm install)
mkdir -p ~/.dsh/.agent-presets && cp -R agent-presets/liangshen ~/.dsh/.agent-presets/liangshen

# 4. 全局设置：**别整份覆盖**，挑你要的段合并进 ~/.dsh/settings.yaml

# 5. 浏览器扩展
./node_modules/.bin/dsh-insight install   # 在 ~/.dsh/profiles/web 下执行

dsh --profile web
```

## 迁移后必须手工做的事

### 1. 凭据（脚本刻意不碰）

`credentials.example.env` 是字段清单，里面**没有真值**。把需要的行拷进 `~/.dsh/.env` 并填：

| 变量 | 必填? | 用途 |
|---|---|---|
| `CUSTOM_API_KEY` | **必填** | `settings.yaml` 里 provider `custom-anthropic`（`apiKeyEnv`）用的 key |
| `DEEPSEEK_API_KEY` | 用官方模型时必填 | dsh 官方 provider `deepseek-official` |
| `TAVILY_API_KEY` | 可选 | `@liustack/modsearch` 搜索质量（不填走 keyless 兜底） |
| `EXA_API_KEY` | 可选 | 同上 |

dsh 加载 `.env` 的顺序是 **进程环境 > `$DSH_HOME/.env` > 调用目录的 `.env`**。注意第三层：
它会随 clone 下来的文件一起旅行，**别把 key 放那里**。`~/.dsh/.env` 才是你自己的。

也可以沿用旧机器的 `~/.dsh/.credentials.yaml`（dsh 凭据服务管理，设置界面可编辑）—— 手工拷过去即可，
本仓库不收录它。

### 2. `settings.yaml` 里的占位符

仓库里那份**已脱敏**：provider 名、`apiKeyEnv`、`baseURL` 全是占位符，**照抄连不上任何模型**。
必须换成你自己的 provider。模型 id、1M 上下文与输出上限保持原值。

### 3. 浏览器扩展

跑过 `dsh-insight install` 后，去 `chrome://extensions` 打开开发者模式，
「加载已解压的扩展程序」指向 `~/Library/Application Support/dsh-insight/extension`。
扩展内部的设置（划词浮标文字、`insight_autopush` 等）存在浏览器里，**不随仓库走**。

## 内容明细

### `profiles/web` — 主 profile（11 个 bundle，按加载顺序）

| # | 包 | 声明版本 | 作用 |
|---|----|---------|------|
| 1 | `@deepseek-ai/dsh-base` | 随 CLI | 核心：agent / session / llm / tools |
| 2 | `@deepseek-ai/dsh-web-app` | 随 CLI | Web 界面 |
| 3 | `dshmarket` | `^1.58.0` | 可视化插件市场 |
| 4 | `dsh-better-sidebar` | `^0.19.1` | VSCode 式右侧边栏，按会话隔离 |
| 5 | `dsh-context` | `^0.54.4` | 上下文洞察与管理 |
| 6 | `@liustack/modsearch` | `^5.10.4` | 联网搜索 / X 搜索 / 网页抓取 |
| 7 | `@deepseek-harness-tui/dsh-tui` | `^0.10.2` | 交互式终端界面 |
| 8 | `dsh-restart-button` | `^0.1.2` | 侧栏一键重启按钮 |
| 9 | `dsh-smart-restart` | `^0.5.1` | 重启后唤醒主 agent |
| 10 | `dsh-cool-theme` | `0.6.1` | 主题（34 套预设、明暗跟随） |
| 11 | `dsh-insight` | `github:Suguyun/dsh-insight` | 浏览器伴侣：划词即解读 + 读页面/抓包/驱动浏览器 |

前两项由 CLI 自带，不出现在 `dependencies` 里，但必须列在 `dsh.profile.bundles` 中才会加载。

`dsh-insight` 是唯一**不在 npm 上**的依赖，直接指向源码仓库 <https://github.com/Suguyun/dsh-insight>
（[dsh-chrome](https://github.com/stuarthu/dsh-chrome) 的 fork，MIT，© 2026 Stuart Hu）。
`github:` 不带 ref 时跟随默认分支 `main`。

**页面自动注入默认关闭**：`dsh-insight` 自己的 bundle patch 就把 `dsh-insight-page-injector`
注释掉了。要打开需两处一起开（只开一处会静默空转）：挂上该行 + 扩展侧
`chrome.storage.local.set({ insight_autopush: true })`。

### `profiles/dsh-tui` — 纯终端 profile

只装 `@deepseek-harness-tui/dsh-tui@0.10.1`，加载 `dsh-base` + `dsh-tui` 两个 bundle。

### `agent-presets/liangshen` — 「梁神模式」

主 Agent 与子 Agent 首轮都保持 Minimal 双工具，首次工具调用后开放完整目录，压缩后重新锚定。
自包含：只 import 同目录的 `.mjs`，不依赖本机路径。内含 `agent.cordis.yml` + 6 个 `.mjs` + `preset.yml`。

### `settings.yaml` / `credentials.example.env`

见上文「迁移后必须手工做的事」。

## 不包含（也不该包含）

- **凭据真值** —— `~/.dsh/.credentials.yaml`、`.env` 一律不入库
- **历史会话** —— `~/.dsh/sessions/`（约 14M）
- **运行状态** —— `~/.dsh/storages/`（约 4.3M，含 `workspace.json`、会话投影缓存）、`attachments/`
- **`node_modules/` 与 `pnpm-lock.yaml`** —— 只记录依赖声明，不锁解析结果
- **dsh CLI 本体** —— 用 npm 装，见上文

## ⚠️ 安全提示

`settings.yaml` 里的 `permission.defaultPreset` 是 **`danger-full-access`** ——
工具调用默认不再逐次询问。这是导出时本机的设置，为忠实迁移而保留原值。
新机器上不希望如此，就把 `defaultPreset` 改成 `ask`，或整段删掉走默认值。

## 维护

本仓库是**手动导出的快照**，不会自动跟随任何机器变化。改了插件或设置后，重新导出并提交。
`bootstrap.sh` 只负责「往外铺」，不负责「往回收」。

## 许可

MIT，见 `LICENSE`。
