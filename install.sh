#!/usr/bin/env bash
# ============================================================
#  zsh + tmux 终端配置安装脚本
#
#  幂等：可以重复执行，不会重复备份或破坏已有配置。
#  分层：任何一层都可以单独跳过。
#
#  用法:
#      bash install.sh                 # 全量安装
#      bash install.sh --no-blur       # 不做 blur
#      bash install.sh --no-tmux       # 不做 tmux
#      bash install.sh --transparency=50
#      bash install.sh --help
# ============================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FONT_SIZE=12
TRANSPARENCY=100          # 0=不透明, 100=完全透明
HACKS_LEVEL=2             # 0|1|2, 见 gnome/blur.sh 里的说明
SIGMA=15
BRIGHTNESS=0.6
DO_BLUR=1
DO_TMUX=1
DO_APT=1
DO_CHSH=0

info() { printf '  %s\n' "$*"; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  awk 'NR == 1 { next }
       /^#/    { sub(/^# ?/, ""); print; next }
       { exit }' "${BASH_SOURCE[0]}"
  cat <<'EOF'

options:
  --transparency=N    terminal background transparency 0-100 (default 100)
  --font-size=N       terminal font size                      (default 12)
  --hacks=N           Blur my Shell hacks-level                (default 2)
  --sigma=N           sigma argument                          (default 15)
  --brightness=F      brightness argument                    (default 0.6)
  --no-blur           skip GNOME blur
  --no-tmux           skip tmux
  --no-apt            not install apt packages
  --chsh              change shell to zsh
  -h, --help          show help
EOF
}

while (( $# )); do
  case "$1" in
    --transparency=*) TRANSPARENCY="${1#*=}" ;;
    --font-size=*)    FONT_SIZE="${1#*=}" ;;
    --hacks=*)        HACKS_LEVEL="${1#*=}" ;;
    --sigma=*)        SIGMA="${1#*=}" ;;
    --brightness=*)   BRIGHTNESS="${1#*=}" ;;
    --no-blur)        DO_BLUR=0 ;;
    --no-tmux)        DO_TMUX=0 ;;
    --no-apt)         DO_APT=0 ;;
    --chsh)           DO_CHSH=1 ;;
    -h|--help)        usage; exit 0 ;;
    *) die "unknown argument: $1(use --help to check option usage)" ;;
  esac
  shift
done

step "environment check"
[[ -r /etc/os-release ]] && . /etc/os-release
info "system: ${PRETTY_NAME:-unknown}"
info "desktop: ${XDG_CURRENT_DESKTOP:-unknown}   session: ${XDG_SESSION_TYPE:-unknown}"

IS_GNOME=0
if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && command -v gsettings >/dev/null 2>&1; then
  IS_GNOME=1
fi
if (( DO_BLUR )) && (( ! IS_GNOME )); then
  warn "can not detect GNOME, skip Blur my Shell"
  DO_BLUR=0
fi

mkdir -p "$HOME/.local/bin"

step "system package"
need=()
command -v zsh     >/dev/null 2>&1 || need+=(zsh)
command -v tmux    >/dev/null 2>&1 || need+=(tmux)
command -v fzf     >/dev/null 2>&1 || need+=(fzf)
command -v rg      >/dev/null 2>&1 || need+=(ripgrep)
command -v zoxide  >/dev/null 2>&1 || need+=(zoxide)
command -v fdfind  >/dev/null 2>&1 || command -v fd >/dev/null 2>&1 || need+=(fd-find)
command -v batcat  >/dev/null 2>&1 || command -v bat >/dev/null 2>&1 || need+=(bat)
fc-list -f '%{family}\n' 2>/dev/null | grep -qi 'for Powerline' || need+=(fonts-powerline)

if (( ${#need[@]} == 0 )); then
  info "system package ready"
elif (( DO_APT )); then
  if command -v apt-get >/dev/null 2>&1; then
    info "${need[*]} will be install"
    SUDO=""
    [[ $EUID -ne 0 ]] && SUDO="sudo"
    $SUDO apt-get update -qq
    for p in "${need[@]}"; do
      $SUDO apt-get install -y "$p" >/dev/null 2>&1 && info "✓ $p" || warn "✗ $p install failed"
    done
  else
    warn "no apt system, please install manually: ${need[*]}"
  fi
else
  warn "--no-apt is set, please install manually: ${need[*]}"
fi

step "oh-my-zsh"
ZSH_DIR="$HOME/.oh-my-zsh"
if [[ -d "$ZSH_DIR" ]]; then
  info "oh-my-zsh existed, skip clone"
else
  command -v git >/dev/null 2>&1 || die "need git to clone oh-my-zsh"
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR"
  info "cloned oh-my-zsh"
fi

clone_plugin() {
  local dst="$ZSH_DIR/custom/plugins/$1"
  if [[ -d "$dst" ]]; then
    info "plugin $1 existed"
  else
    git clone --depth=1 -q "$2" "$dst" && info "$1 install completed"
  fi
}
clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
clone_plugin fzf-tab                 https://github.com/Aloxaf/fzf-tab
clone_plugin zsh-autopair            https://github.com/hlissner/zsh-autopair

step ".zshrc"
src="$HERE/files/zshrc"
dst="$HOME/.zshrc"
if [[ ! -f "$src" ]]; then
  warn "can not find $src, skip"
else
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
    bak="$dst.bak.$(date +%Y%m%d-%H%M%S)"
    cp -p "$dst" "$bak"
    info "backup to → $bak"
  fi
  install -m 644 "$src" "$dst"
  info "write to $dst"
fi

step "fontconfig rollback"
fc_dir="$HOME/.config/fontconfig/conf.d"
mkdir -p "$fc_dir"
install -m 644 "$HERE/files/99-powerline-pua.conf" "$fc_dir/99-powerline-pua.conf"
fc-cache -f >/dev/null 2>&1 || true
info "write to $fc_dir/99-powerline-pua.conf and rebuild cache"

if (( IS_GNOME )); then
  step "gnome-terminal profile"
  FONT_SIZE="$FONT_SIZE" TRANSPARENCY="$TRANSPARENCY" \
    bash "$HERE/gnome/terminal.sh"
fi

if (( DO_BLUR )); then
  step "Blur my Shell"
  HACKS_LEVEL="$HACKS_LEVEL" SIGMA="$SIGMA" BRIGHTNESS="$BRIGHTNESS" \
    bash "$HERE/gnome/blur.sh"
fi

if (( DO_TMUX )); then
  step "tmux"

  ts="$HERE/files/tmux.conf"
  td="$HOME/.tmux.conf"
  if [[ -f "$ts" ]]; then
    if [[ -f "$td" ]] && ! cmp -s "$ts" "$td"; then
      cp -p "$td" "$td.bak.$(date +%Y%m%d-%H%M%S)"
      info ".tmux.conf backup"
    fi
    install -m 644 "$ts" "$td"
    info "write to $td"
  else
    warn "can not find $ts, skip tmux config"
  fi

  # TPM 及其插件
  if command -v git >/dev/null 2>&1; then
    tpm_dir="$HOME/.tmux/plugins"
    mkdir -p "$tpm_dir"
    clone_tpm() {
      local d="$tpm_dir/$1"
      if [[ -d "$d" ]]; then
        info "tmux plugin $1 existed"
      else
        git clone --depth=1 -q "$2" "$d" && info "已安装 tmux 插件 $1"
      fi
    }
    clone_tpm tpm             https://github.com/tmux-plugins/tpm
    clone_tpm tmux-resurrect  https://github.com/tmux-plugins/tmux-resurrect
    clone_tpm tmux-continuum  https://github.com/tmux-plugins/tmux-continuum
  fi

  if command -v tmux >/dev/null 2>&1; then
    sock="dsh_install_check_$$"
    err="$(tmux -L "$sock" -f /dev/null start-server \; source-file "$td" 2>&1 || true)"
    tmux -L "$sock" kill-server 2>/dev/null || true
    if [[ -z "$err" ]]; then
      info "tmux config check passed"
    else
      warn "tmux config error:"
      printf '%s\n' "$err" | sed 's/^/      /' >&2
    fi
  fi
fi

step "complete"
if [[ "${SHELL:-}" != *zsh ]]; then
  if (( DO_CHSH )); then
    info "change shell to zsh…"
    chsh -s "$(command -v zsh)" || warn "chsh failed, please run manually: chsh -s $(command -v zsh)"
  else
    info "default shell is still ${SHELL}, change command:"
    printf '      chsh -s %s\n' "$(command -v zsh)"
  fi
fi
