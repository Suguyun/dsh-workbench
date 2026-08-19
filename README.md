# dsh-workbench

DeepSeek Harness(dsh)精选工作 profile:**一个 Web 界面覆盖三类工作流** —— 写代码/开发、数据/办公、通用助手。定位"精而稳":10 个 bundle(2 官方 + 8 社区),全部经 npm 验证可装,不碰 GitHub 源码插件,不影响现有 profile。

- 端口:**3081**(避开 web profile 的 3080)
- 回滚:删除 profile 目录即整体还原
- 依赖:dsh CLI ≥ v0.1.0-rc.7、pnpm ≥ 11、Node ≥ 22

## 安装

profile 名 = `~/.dsh/profiles/` 下的目录名,可任意取名(下面用 `workbench`):

```bash
# 方式一:gh 克隆到 profiles 目录
gh repo clone Suguyun/dsh-workbench ~/.dsh/profiles/workbench
cd ~/.dsh/profiles/workbench && pnpm install

# 方式二:手动复制(把本仓库目录放到 ~/.dsh/profiles/<name>/ 下再 pnpm install)

# 启动
dsh --profile workbench            # → http://127.0.0.1:3081
dsh --profile workbench --port 8080   # 临时换端口
dsh --profile workbench --patch ./x.yml   # 临时叠加一层 patch
dsh --profile workbench --dump-config    # 查看组合树(10 个 bundle 应全在)
```

## Key 占位清单(启动前配好)

key 加载顺序:进程环境 > `~/.dsh/.env` > 当前目录 `.env`。推荐写进 `~/.dsh/.env`。

| 变量 | 必填 | 用途 |
|---|---|---|
| `DEEPSEEK_API_KEY` | **必填** | 核心模型(base 默认 `provider: deepseek-official` → deepseek-v4-flash) |
| `TAVILY_API_KEY` | 可选 | 提升 `web_search` 质量(不配则 keyless DuckDuckGo 兜底) |
| `BRAVE_API_KEY` | 可选 | 同上,第二个可用引擎 |
| ModLens 视觉模型 | 可选 | 见下方 ModLens 配置 |

未配 `DEEPSEEK_API_KEY` 时 UI 可正常打开,模型调用会报清晰的鉴权错误。

## Bundle 清单(按加载顺序)

| # | 包 | 版本 | 作用 |
|---|---|---|---|
| 1 | `@deepseek-ai/dsh-base` | 0.1.0-rc.7(随 CLI) | 核心(agent/session/llm,默认 deepseek-official) |
| 2 | `@deepseek-ai/dsh-web-app` | 0.1.0-rc.7 | Web 界面 |
| 3 | `dsh-better-sidebar` | 0.13.1 | VSCode 式右侧边栏(编辑器/终端/Git/浏览器) |
| 4 | `dsh-oh-my-theme` | 0.6.0 | 主题 + 懒加载文件树 + `@file` 引用 + Markdown 预览 |
| 5 | `@liustack/modlens` | 3.21.1 | 图片→结构化文本(`modlens_read_image`) |
| 6 | `dsh-web-search` | 0.1.2 | 多引擎联网搜索(自动降级)+ URL 提取(带兼容补丁,见下) |
| 7 | `dsh-rss` | 0.2.0 | RSS/Atom 订阅、OPML 导入导出 |
| 8 | `dsh-loom` | 1.1.0 | 第二验证人:静默复查模型产出(observe 模式) |
| 9 | `@nanmicoder/dsh-agent-teams` | 0.1.7 | 按需多 agent 团队(并发上限 4) |
| 10 | `dsh-crew` | 0.4.3 | 角色化 agent 小队 + Git 推送守卫 |

## 配置说明(已在本仓库 `cordis.patch.yml` 落地)

- **端口**:webserver 默认 3081,`--port` 仍可覆盖。
- **dsh-loom**:复查模型显式固定为 `deepseek-v4-flash`(便宜档),`mode: observe` 只观察不自动改。
- **dsh-agent-teams**:`maxMembers: 4`(子 agent 并发上限)。
- **dsh-rss**:抓取超时 15s。订阅列表经 dsh settings 服务持久化(`~/.dsh/storages`);0.2.0 无数据目录配置键。
- **dsh-oh-my-theme**:皮肤/字号在 UI 里配:**设置 → 通用设置 → Oh My Theme**;文件树跟随当前会话工作区。
- **dsh-web-search**:三个引擎 key 走 credentials 服务(设置页卡片管理)或 `TAVILY_API_KEY`/`BRAVE_API_KEY` 环境变量;一个 key 不填也有 DuckDuckGo 兜底。
- **ModLens**:自带配置系统,不用 patch:

  ```bash
  modlens config init
  modlens config set openai.baseUrl https://dashscope.aliyuncs.com/compatible-mode/v1  # qwen-vl 示例
  modlens config set openai.apiKey  <key>
  modlens config set openai.model   qwen3-vl-plus
  ```

  配置文件在 `~/.modlens/config.json`(0600)。零配置时走 antigravity-cli 免费通道。

## dsh-web-search 兼容补丁(本仓库新增内容)

`patches/dsh-web-search@0.1.2.patch` 通过 pnpm `patchedDependencies` 自动应用,解决 dsh-web-search 0.1.2 与 rc.7 的 API 漂移:rc.7 把设置槽 `settings.plugin.item` 改为 keyed slot(必须传 `options.key`),而 0.1.2 只传了 `id`,导致浏览器半加载失败(`keyed slot "settings.plugin.item" requires options.key`)。补丁在注册选项里补上 `key: 'dsh-web-search'`。`pnpm install` 会自动重放;上游修复后可删除 `pnpm-workspace.yaml` 中的 `patchedDependencies` 条目与 `patches/` 目录。

## 插件管理

```bash
dsh plugin --profile workbench add <pkg>      # pnpm 安装 + 自动加入 bundles
dsh plugin --profile workbench remove <pkg>   # 移除
# 手动调整加载顺序或新增 bundle:编辑 package.json 的 dsh.profile.bundles
```

## 日常用法

侧边栏写代码/看 Git → `@file` 注入文件 → ModLens 贴图 → `web_search` 联网 → RSS 订阅 → loom 复查关键产出 → agent-teams / crew 复杂任务。

## License

MIT。`patches/dsh-web-search@0.1.2.patch` 是对 [dsh-web-search](https://www.npmjs.com/package/dsh-web-search)(© 2026 haibinwang9,MIT)的派生修改,随原包 MIT 条款再分发。
