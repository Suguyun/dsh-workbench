#!/usr/bin/env bash
#
# dsh-workbench — 整机迁移脚本
#
# 把本仓库的内容铺到一台新机器的 dsh 上：
#
#   profiles/<name>/      →  $DSH_HOME/profiles/<name>/        然后 pnpm install
#   settings.yaml         →  $DSH_HOME/settings.yaml           （默认不动，见 --settings）
#
# 默认是**预演**：只打印将要做什么，不写任何文件。确认无误后加 --apply。
#
# 用法:
#   ./bootstrap.sh                          预演，看一遍计划
#   ./bootstrap.sh --apply                  执行（已存在的 profile 自动跳过）
#   ./bootstrap.sh --apply --force          已存在的也覆盖（先备份到 backups/migrate-*）
#   ./bootstrap.sh --apply --settings       连带安装 settings.yaml（先备份旧的）
#
# 开关:
#   --no-cli          不做 dsh CLI 的存在性检查
#   --no-install      不跑 pnpm install，只铺文件
#   --no-extension    不跑 dsh-insight install
#
# 环境变量:
#   DSH_HOME          默认 ~/.dsh
#   DSH_CLI_VERSION   默认 0.1.5-rc.1（本包导出时用的版本）
#
# 安全约束（脚本自身保证）:
#   * 绝不写入 .credentials.yaml —— 凭据只能你自己填，见 credentials.example.env
#   * 覆盖任何已存在的东西之前，先移到 $DSH_HOME/backups/migrate-<时间戳>/
#   * 不碰 sessions/ storages/ attachments/ 等运行数据
#
# 兼容 macOS 自带的 bash 3.2。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
DSH_CLI_VERSION="${DSH_CLI_VERSION:-0.1.5-rc.1}"
BACKUP_DIR_SAFE="$DSH_HOME/backups/migrate-$(date +%Y%m%d-%H%M%S)"

APPLY=false
FORCE=false
DO_SETTINGS=false
DO_CLI=true
DO_INSTALL=true
DO_EXTENSION=true

for arg in "$@"; do
  case "$arg" in
    --apply)        APPLY=true ;;
    --force)        FORCE=true ;;
    --settings)     DO_SETTINGS=true ;;
    --no-cli)       DO_CLI=false ;;
    --no-install)   DO_INSTALL=false ;;
    --no-extension) DO_EXTENSION=false ;;
    -h|--help)      sed -n '2,38p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf '未知参数: %s（用 --help 看用法）\n' "$arg" >&2; exit 2 ;;
  esac
done

# ── 输出 helpers ─────────────────────────────────────────────────────────────
if [ -t 1 ]; then BOLD=$'\033[1m'; DIM=$'\033[2m'; YEL=$'\033[33m'; GRN=$'\033[32m'; OFF=$'\033[0m'
else BOLD=; DIM=; YEL=; GRN=; OFF=; fi

step() { printf '\n%s== %s%s\n' "$BOLD" "$*" "$OFF"; }
say()  { printf '%s\n' "$*"; }
warn() { printf '%s  ! %s%s\n' "$YEL" "$*" "$OFF"; }
ok()   { printf '%s  ✓ %s%s\n' "$GRN" "$*" "$OFF"; }
skip() { printf '%s  - %s%s\n' "$DIM" "$*" "$OFF"; }

run() {
  if $APPLY; then "$@"
  else printf '%s   [预演] %s%s\n' "$DIM" "$*" "$OFF"; fi
}

# ── 预演横幅 ─────────────────────────────────────────────────────────────────
if ! $APPLY; then
  printf '%s' "$YEL"
  say "╭──────────────────────────────────────────────────────────────╮"
  say "│ 预演模式：不会写任何文件。确认后加 --apply 真正执行。        │"
  say "╰──────────────────────────────────────────────────────────────╯"
  printf '%s' "$OFF"
fi

say "${DIM}仓库目录 : $REPO_DIR"
say "DSH_HOME : $DSH_HOME"
if $APPLY; then say "备份目录 : $BACKUP_DIR_SAFE"; fi
printf '%s' "$OFF"

# ── 防呆：别把仓库直接当成 profile 用 ────────────────────────────────────────
case "$REPO_DIR/" in
  "$DSH_HOME"/profiles/*)
    warn "本仓库位于 $DSH_HOME/profiles/ 下面。"
    warn "仓库根目录现在已经不是单个 profile（新布局是 profiles/<name>/），"
    warn "请把它放到 $DSH_HOME 之外再运行本脚本。"
    ;;
esac

# ── 1. 环境检查 ──────────────────────────────────────────────────────────────
step "1/5 环境检查"

need() { command -v "$1" >/dev/null 2>&1; }

if need node; then
  NODE_V="$(node --version)"
  NODE_MAJOR="$(printf '%s' "${NODE_V#v}" | cut -d. -f1)"
  if [ "$NODE_MAJOR" -ge 22 ] 2>/dev/null; then ok "node $NODE_V"
  else warn "node $NODE_V 偏旧（本包实测 v24.14.0，要求 ≥ 22）"; fi
else
  warn "未找到 node —— 先装 Node ≥ 22"
fi

if need pnpm; then
  PNPM_V="$(pnpm --version)"
  PNPM_MAJOR="$(printf '%s' "$PNPM_V" | cut -d. -f1)"
  if [ "$PNPM_MAJOR" -ge 11 ] 2>/dev/null; then ok "pnpm $PNPM_V"
  else warn "pnpm $PNPM_V 偏旧（本包实测 11.22.0，要求 ≥ 11）"; fi
else
  warn "未找到 pnpm —— dsh CLI 需要它，或改用 corepack"
fi

if need git; then ok "git 可用（dsh-insight 依赖要从 GitHub 拉）"
else warn "未找到 git —— github: 形式的依赖装不了"; fi

if $DO_CLI; then
  if need dsh; then
    ok "已装 dsh CLI：$(dsh --version 2>/dev/null || echo '版本未知')"
  else
    warn "未找到 dsh CLI，需要先装："
    say "     npm i -g @deepseek-ai/dsh@$DSH_CLI_VERSION"
  fi
fi

# ── 2. Profile ───────────────────────────────────────────────────────────────
step "2/5 安装 profile"
say "${DIM}目标：$DSH_HOME/profiles/<name>/${OFF}"

INSTALLED=""
WEB_INSTALLED=false

for src in "$REPO_DIR"/profiles/*/; do
  [ -d "$src" ] || continue
  name="$(basename "$src")"
  dest="$DSH_HOME/profiles/$name"

  if [ -e "$dest" ] && ! $FORCE; then
    skip "$name —— 已存在，跳过（要覆盖用 --force）"
    INSTALLED="$INSTALLED $name"
    [ "$name" = "web" ] && WEB_INSTALLED=true
    continue
  fi

  if [ -e "$dest" ]; then
    warn "  覆盖前备份 $dest → $BACKUP_DIR_SAFE/profiles-$name/"
    run mkdir -p "$BACKUP_DIR_SAFE/profiles-$name"
    run cp -R "$dest/." "$BACKUP_DIR_SAFE/profiles-$name/"
    run rm -rf "$dest"
  fi

  run mkdir -p "$dest"
  run cp -R "$src." "$dest/"
  ok "$name → $dest"
  INSTALLED="$INSTALLED $name"
  [ "$name" = "web" ] && WEB_INSTALLED=true
done

# ── 3. 全局 settings.yaml ────────────────────────────────────────────────────
step "3/5 全局设置"

if $DO_SETTINGS; then
  dest="$DSH_HOME/settings.yaml"
  if [ -e "$dest" ]; then
    warn "  覆盖前备份 $dest → $BACKUP_DIR_SAFE/settings.yaml.bak"
    run mkdir -p "$BACKUP_DIR_SAFE"
    run cp -p "$dest" "$BACKUP_DIR_SAFE/settings.yaml.bak"
  fi
  run cp "$REPO_DIR/settings.yaml" "$dest"
  ok "settings.yaml 已安装（里面是占位符！必须改成你自己的 provider）"
  warn "注意 permission.defaultPreset = danger-full-access（默认全权限放行），"
  warn "不想要就把 defaultPreset 改成 ask。"
else
  skip "未安装 —— 默认不碰你的全局设置。要安装加 --settings"
fi

# ── 4. 依赖 ──────────────────────────────────────────────────────────────────
step "4/5 依赖安装（pnpm install）"

if $DO_INSTALL; then
  if need pnpm; then
    for name in $INSTALLED; do
      dir="$DSH_HOME/profiles/$name"
      say "   → $name"
      if $APPLY; then
        ( cd "$dir" && pnpm install )
      else
        printf '%s     [预演] (cd %s && pnpm install)%s\n' "$DIM" "$dir" "$OFF"
      fi
    done
  else
    warn "没有 pnpm，跳过。装好后自己进各 profile 目录跑 pnpm install"
  fi
else
  skip "已按 --no-install 跳过"
fi

# ── 5. 浏览器扩展 ────────────────────────────────────────────────────────────
step "5/5 浏览器扩展"

if $DO_EXTENSION && $DO_INSTALL && $WEB_INSTALLED; then
  bin="$DSH_HOME/profiles/web/node_modules/.bin/dsh-insight"
  if $APPLY; then
    if [ -x "$bin" ]; then "$bin" install
    else warn "没找到 $bin —— 先确认 web profile 的 pnpm install 成功了"; fi
  else
    printf '%s     [预演] %s install%s\n' "$DIM" "$bin" "$OFF"
  fi
else
  skip "已跳过（没有 web profile，或用了 --no-install / --no-extension）"
fi

# ── 收尾清单 ─────────────────────────────────────────────────────────────────
step "接下来要你手工做的（脚本刻意不代劳）"

cat <<EOF
  1. 凭据 —— 脚本不碰。把 credentials.example.env 里需要的行拷进
     $DSH_HOME/.env 并填真值（或从旧机器手工拷 .credentials.yaml 过来）：
        CUSTOM_API_KEY      必填（settings.yaml 里那个自定义 provider）
        DEEPSEEK_API_KEY    用官方模型时必填
        TAVILY_API_KEY      可选，搜索质量
        EXA_API_KEY         可选，搜索质量

  2. 改 settings.yaml —— provider 名/端点/环境变量名都是**占位符**，
     照抄连不上模型。

  3. 浏览器扩展 —— 若上面跑了 dsh-insight install，去 chrome://extensions
     打开开发者模式，「加载已解压的扩展程序」指向：
        ~/Library/Application Support/dsh-insight/extension

  4. 启动：
        dsh --profile web
EOF

if ! $APPLY; then
  printf '\n%s以上只是预演。真正执行：  ./bootstrap.sh --apply%s\n' "$BOLD" "$OFF"
fi
