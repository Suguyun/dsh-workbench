# dsh-workbench

dsh（DeepSeek Harness）整机迁移包。导出时间 2026-09-23，实测 dsh CLI `0.1.5-rc.1`、Node `v24.14.0`、pnpm `11.22.0`。

## 迁移

```bash
gh repo clone Suguyun/dsh-workbench ~/dsh-workbench
cd ~/dsh-workbench

./bootstrap.sh              # ① 预演：只打印计划，不写任何文件
./bootstrap.sh --apply      # ② 确认后执行
```

脚本做两件事：`profiles/*` → `~/.dsh/profiles/`，各自 `pnpm install`，最后 `dsh-insight install`。

已存在的 profile 默认**跳过**，要覆盖加 `--force`（覆盖前先备份到
`~/.dsh/backups/migrate-<时间戳>/`）。常用开关：`--settings`（连全局设置一起装，默认不碰）、
`--no-install`、`--no-extension`。

### 之后必须手工做

1. **凭据** —— 脚本刻意不碰。按 `credentials.example.env` 把需要的行拷进 `~/.dsh/.env` 填真值。
2. **改 `settings.yaml`** —— provider 名、端点、环境变量名都是**占位符**，照抄连不上任何模型。
3. **浏览器扩展** —— `chrome://extensions` 开发者模式，「加载已解压的扩展程序」指向
   `~/Library/Application Support/dsh-insight/extension`。
4. 启动：`dsh --profile web`

## 内容

```
bootstrap.sh              迁移脚本（默认预演）
settings.yaml             全局设置，已脱敏          → ~/.dsh/settings.yaml
credentials.example.env   凭据字段清单，无真值      → ~/.dsh/.env
profiles/web/             主 profile（11 个 bundle）
profiles/dsh-tui/         纯终端 profile
```

- **dsh CLI 本体不在仓库里**：先 `npm i -g @deepseek-ai/dsh@0.1.5-rc.1`。
- `dsh-insight` 是唯一不在 npm 上的依赖（`github:Suguyun/dsh-insight`，
  [dsh-chrome](https://github.com/stuarthu/dsh-chrome) 的 fork，MIT，© 2026 Stuart Hu）。
- **不含**：凭据真值、`sessions/`、`storages/`、`attachments/`、`node_modules/`、lockfile。
- 页面自动注入默认关闭，要打开见 `profiles/web/cordis.patch.yml` 的注释。

## ⚠️

`settings.yaml` 里 `permission.defaultPreset` 是 `danger-full-access` —— 工具调用默认不再逐次询问。
不想要就改成 `ask`。

## 许可

MIT，见 `LICENSE`。
