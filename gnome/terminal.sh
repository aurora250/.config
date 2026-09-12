#!/usr/bin/env bash
# ============================================================
#  应用 gnome-terminal 配置
#
#  可用环境变量覆盖:
#    FONT_SIZE=12  TRANSPARENCY=100  TERMINAL_FONT="Meslo LG S DZ for Powerline"
# ============================================================
set -euo pipefail

SCHEMA_PROFILE=org.gnome.Terminal.Legacy.Profile
SCHEMA_LIST=org.gnome.Terminal.ProfilesList

FONT_SIZE="${FONT_SIZE:-12}"
TRANSPARENCY="${TRANSPARENCY:-100}"
TERMINAL_FONT="${TERMINAL_FONT:-}"

CANDIDATE_FONTS=(
  "Meslo LG S DZ for Powerline"
  "Meslo LG M DZ for Powerline"
  "Meslo LG L DZ for Powerline"
  "DejaVu Sans Mono for Powerline"
  "Hack"
)

info() { printf '  %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v gsettings >/dev/null 2>&1 || die "cannot find gsetting"

uuid="$(gsettings get "$SCHEMA_LIST" default 2>/dev/null | tr -d "'")"
if [[ -z "$uuid" ]]; then
  uuid="$(gsettings get "$SCHEMA_LIST" list 2>/dev/null | tr -d "[]'" | cut -d, -f1 | tr -d ' ')"
fi
[[ -n "$uuid" ]] || die "cannot make sure profile UUID of gnome-terminal. please open terminal manually and retry"

path="/org/gnome/terminal/legacy/profiles:/:${uuid}/"
info "profile UUID: $uuid"

if [[ -z "$TERMINAL_FONT" ]]; then
  families="$(fc-list -f '%{family}\n' 2>/dev/null | tr ',' '\n' | sed 's/^ *//; s/ *$//' | sort -u)"
  for c in "${CANDIDATE_FONTS[@]}"; do
    if grep -qxF "$c" <<<"$families"; then
      TERMINAL_FONT="$c"
      break
    fi
  done
fi

if [[ -z "$TERMINAL_FONT" ]]; then
  warn "cannot find Powerline font. install command:"
  warn "  Ubuntu/Debian:  sudo apt install fonts-powerline"
else
  info "font: $TERMINAL_FONT $FONT_SIZE"
  gsettings set "$SCHEMA_PROFILE:$path" use-system-font false
  gsettings set "$SCHEMA_PROFILE:$path" font "${TERMINAL_FONT} ${FONT_SIZE}"
fi

[[ "$TRANSPARENCY" =~ ^[0-9]+$ ]] || die "TRANSPARENCY must be int but get: $TRANSPARENCY"
(( TRANSPARENCY >= 0 && TRANSPARENCY <= 100 )) || die "TRANSPARENCY must between 0 and 100 but get: $TRANSPARENCY"

gsettings set "$SCHEMA_PROFILE:$path" use-transparent-background true
gsettings set "$SCHEMA_PROFILE:$path" background-transparency-percent "$TRANSPARENCY"
info "background transparency: ${TRANSPARENCY}%"

if (( TRANSPARENCY == 100 )); then
  warn "when transparency is too high, the background will be entirely provided by the synthesizer."
fi

printf '\n  diff between profile and schema-default:\n'
dconf dump "/org/gnome/terminal/legacy/profiles:/:${uuid}/" 2>/dev/null | sed 's/^/    /'
