#!/usr/bin/env bash
# ============================================================
#  安装并配置 Blur my Shell
#
#  可用环境变量覆盖:
#    SIGMA=15  BRIGHTNESS=0.6  HACKS_LEVEL=2  WHITELIST_PATTERN='*terminal*'
# ============================================================
set -euo pipefail

EXT_UUID=blur-my-shell@aunetx
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"

SIGMA="${SIGMA:-15}"
BRIGHTNESS="${BRIGHTNESS:-0.6}"
HACKS_LEVEL="${HACKS_LEVEL:-2}"
WHITELIST_PATTERN="${WHITELIST_PATTERN:-*terminal*}"

info() { printf '  %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

for c in gnome-extensions curl python3 glib-compile-schemas; do
  command -v "$c" >/dev/null 2>&1 || die "missing dependency command: $c"
done

gnome_major="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)"
[[ -n "$gnome_major" ]] || die "无法确定 GNOME Shell 版本"
info "GNOME Shell $gnome_major"

api="https://extensions.gnome.org/extension-info/?uuid=${EXT_UUID}&shell_version=${gnome_major}"
json="$(curl -fsSL "$api")" || die "cannot access extensions.gnome.org"

download_url="$(python3 -c '
import json, sys
try:
    print(json.loads(sys.argv[1]).get("download_url") or "")
except Exception:
    print("")
' "$json")"

[[ -n "$download_url" ]] || die "There is no version of Blur my Shell on EGO for GNOME $gnome_major"
info "download URL: $download_url"

tmp_zip="$(mktemp --suffix=.zip)"
trap 'rm -f "$tmp_zip"' EXIT

curl -fsSL "https://extensions.gnome.org${download_url}" -o "$tmp_zip" \
  || die "extension package download failed"

gnome-extensions install --force "$tmp_zip" \
  || die "gnome-extensions install failed"

[[ -d "$EXT_DIR" ]] || die "install dir did not exists: $EXT_DIR"
info "installed to $EXT_DIR"

glib-compile-schemas "$EXT_DIR/schemas/" 2>/dev/null || warn "schema conpile faiiled"
export GSETTINGS_SCHEMA_DIR="$EXT_DIR/schemas"

GS=org.gnome.shell.extensions.blur-my-shell
GA="$GS.applications"

gsettings set "$GA" blur true
gsettings set "$GA" enable-all false
gsettings set "$GA" whitelist "['${WHITELIST_PATTERN}']"
info "whitelist: ['${WHITELIST_PATTERN}']"

gsettings set "$GA" dynamic-opacity false
info "dynamic-opacity=false"

gsettings set "$GA" sigma "$SIGMA"
gsettings set "$GA" brightness "$BRIGHTNESS"
info "sigma=$SIGMA  brightness=$BRIGHTNESS"

gsettings set "$GS" hacks-level "$HACKS_LEVEL"
info "hacks-level=$HACKS_LEVEL"
(( HACKS_LEVEL == 2 )) && warn "hacks-level=2 will turn off clip redraw"

current="$(gsettings get org.gnome.shell enabled-extensions)"
new_list="$(python3 - "$current" "$EXT_UUID" <<'PY'
import ast, sys
cur, uuid = sys.argv[1], sys.argv[2]
try:
    lst = ast.literal_eval(cur)
except Exception:
    lst = []
if uuid not in lst:
    lst.append(uuid)
print("[" + ", ".join("'%s'" % x for x in lst) + "]")
PY
)"
gsettings set org.gnome.shell enabled-extensions "$new_list"
info "log to enabled-extensions"

