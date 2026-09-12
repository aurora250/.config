#!/usr/bin/env bash
# ============================================================
#  用法:  bash uninstall.sh [--purge-extension] [--purge-tmux-plugins]
# ============================================================
set -euo pipefail

PURGE_EXT=0
PURGE_TMUX=0
for a in "$@"; do
  case "$a" in
    --purge-extension)     PURGE_EXT=1 ;;
    --purge-tmux-plugins)  PURGE_TMUX=1 ;;
    -h|--help)
      cat <<'USAGE'
usage: bash uninstall.sh [options]

  --purge-extension      remove Blur my Shell extension
  --purge-tmux-plugins   remove ~/.tmux/plugins
  -h, --help             show help
USAGE
      exit 0 ;;
  esac
done

SCHEMA_PROFILE=org.gnome.Terminal.Legacy.Profile
SCHEMA_LIST=org.gnome.Terminal.ProfilesList
EXT_UUID=blur-my-shell@aunetx
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"

info() { printf '  %s\n' "$*"; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

step "recover .zshrc"
latest_bak="$(ls -1t "$HOME"/.zshrc.bak.* 2>/dev/null | head -1 || true)"
if [[ -n "$latest_bak" ]]; then
  cp -p "$latest_bak" "$HOME/.zshrc"
  info "recovered from $latest_bak"
else
  warn ".zshrc.bak.* missed, please check ~/.zshrc manually"
fi

step "remove fontconfig"
target="$HOME/.config/fontconfig/conf.d/99-powerline-pua.conf"
if [[ -f "$target" ]]; then
  rm -f "$target"
  fc-cache -f >/dev/null 2>&1 || true
  info "removed $target and rebuild cache"
fi

step "recover terminal profile"
if command -v gsettings >/dev/null 2>&1; then
  uuid="$(gsettings get "$SCHEMA_LIST" default 2>/dev/null | tr -d "'")"
  if [[ -n "$uuid" ]]; then
    path="$SCHEMA_PROFILE:/org/gnome/terminal/legacy/profiles:/:${uuid}/"
    for k in use-system-font font use-transparent-background background-transparency-percent; do
      gsettings reset "$path" "$k" 2>/dev/null && info "reset $k" || warn "cannot reset $k"
    done
  else
    warn "cannot identify profile UUID, skip"
  fi
else
  info "no gsettings, skip"
fi

step "rollback Blur my Shell"
if command -v gsettings >/dev/null 2>&1; then
  current="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || echo '[]')"
  new_list="$(python3 - "$current" "$EXT_UUID" <<'PY' 2>/dev/null || echo ""
import ast, sys
cur, uuid = sys.argv[1], sys.argv[2]
try:
    lst = ast.literal_eval(cur)
except Exception:
    lst = []
lst = [x for x in lst if x != uuid]
print("[" + ", ".join("'%s'" % x for x in lst) + "]")
PY
)"
  if [[ -n "$new_list" ]]; then
    gsettings set org.gnome.shell enabled-extensions "$new_list"
    info "removed from enabled-extensions"
  fi

  if [[ -d "$EXT_DIR/schemas" ]]; then
    GSETTINGS_SCHEMA_DIR="$EXT_DIR/schemas" \
      gsettings reset org.gnome.shell.extensions.blur-my-shell hacks-level 2>/dev/null \
      && info "hacks-level reset" || true
  fi
fi

if (( PURGE_EXT )); then
  if [[ -d "$EXT_DIR" ]]; then
    rm -rf "$EXT_DIR"
    info "removed extension dir $EXT_DIR"
  fi
else
  info "keep extension dir"
fi

step "rollback tmux"
if [[ -f "$HOME/.tmux.conf" ]]; then
  latest_tmux_bak="$(ls -1t "$HOME"/.tmux.conf.bak.* 2>/dev/null | head -1 || true)"
  if [[ -n "$latest_tmux_bak" ]]; then
    cp -p "$latest_tmux_bak" "$HOME/.tmux.conf"
    info "rollback from $latest_tmux_bak"
  else
    rm -f "$HOME/.tmux.conf"
    info "remove ~/.tmux.conf"
  fi
fi

if (( PURGE_TMUX )); then
  if [[ -d "$HOME/.tmux/plugins" ]]; then
    rm -rf "$HOME/.tmux/plugins"
    info "removed ~/.tmux/plugins"
  fi
else
  info "keep ~/.tmux/plugins"
fi
