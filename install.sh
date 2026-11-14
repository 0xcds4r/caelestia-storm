#!/usr/bin/env bash
# Caelestia Storm — quick installer
#   curl -fsSL https://raw.githubusercontent.com/0xcds4r/caelestia-storm/main/install.sh | bash
# or from a checkout:  ./install.sh
set -euo pipefail

REPO="${CAELESTIA_STORM_REPO:-https://github.com/0xcds4r/caelestia-storm.git}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELL_DIR="$CONFIG_HOME/quickshell/caelestia"
SHELL_JSON_DIR="$CONFIG_HOME/caelestia"
BACKUP_DIR="$HOME/.local/state/caelestia-storm/backups"
SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"

c_red=$'\e[31m'; c_grn=$'\e[32m'; c_ylw=$'\e[33m'; c_rst=$'\e[0m'
info() { printf '%s==>%s %s\n' "$c_grn" "$c_rst" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_ylw" "$c_rst" "$*"; }
die()  { printf '%s[x]%s %s\n' "$c_red" "$c_rst" "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Caelestia Storm installer

Usage: install.sh [options]

  -y, --yes         do not ask before installing missing packages
      --no-deps     skip dependency installation
  -f, --force       overwrite ~/.config/caelestia/shell.json (a backup is kept)
  -n, --no-restart  do not restart the shell at the end
  -h, --help        show this help

Dependencies (quickshell-git, caelestia-shell, caelestia-cli) are installed through paru/yay when
they are missing. On non-Arch systems pass --no-deps and install them yourself.

Run it from a git checkout (./install.sh) or pipe it from GitHub:
  curl -fsSL https://raw.githubusercontent.com/0xcds4r/caelestia-storm/main/install.sh | bash
EOF
}

FORCE=0
NO_RESTART=0
ASSUME_YES=0
NO_DEPS=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        --no-deps) NO_DEPS=1 ;;
        -f|--force) FORCE=1 ;;
        -n|--no-restart) NO_RESTART=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown argument: $arg" ;;
    esac
done

confirm() {
    ((ASSUME_YES)) && return 0
    if [[ -r /dev/tty ]]; then
        local reply
        read -r -p "$1 [Y/n] " reply < /dev/tty || true
        [[ -z "${reply:-}" || "$reply" =~ ^[Yy] ]]
    else
        warn "no terminal to ask on — pass -y to install dependencies automatically"
        return 1
    fi
}

# --- dependencies -----------------------------------------------------------
# Everything the shell needs comes from three packages; pacman pulls their own dependencies.
DEPS=(quickshell-git caelestia-cli caelestia-shell)

if command -v pacman >/dev/null; then
    missing=()
    for p in "${DEPS[@]}"; do
        pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    command -v git >/dev/null || missing+=(git)

    if ((${#missing[@]} == 0)); then
        info "dependencies already installed"
    elif ((NO_DEPS)); then
        warn "missing packages: ${missing[*]} (--no-deps: not installing)"
    else
        warn "missing packages: ${missing[*]}"
        if confirm "Install them now?"; then
            helper=""
            for h in paru yay; do
                if command -v "$h" >/dev/null; then
                    helper="$h"
                    break
                fi
            done

            needs_aur=0
            for p in "${missing[@]}"; do
                case "$p" in
                    quickshell-git|caelestia-*) needs_aur=1 ;;
                esac
            done

            if [[ -n "$helper" ]]; then
                info "installing with $helper"
                "$helper" -S --needed --noconfirm "${missing[@]}" || die "package installation failed"
            elif ((needs_aur == 0)); then
                info "installing with pacman"
                sudo pacman -S --needed --noconfirm "${missing[@]}" || die "package installation failed"
            else
                die "no AUR helper found (paru or yay) — install ${missing[*]} manually, then re-run with --no-deps"
            fi
        else
            warn "skipping dependencies — the shell will not start without ${missing[*]}"
        fi
    fi
else
    warn "not an Arch system — install quickshell + caelestia-shell + caelestia-cli manually (see README)"
fi

if ! command -v quickshell >/dev/null && ! command -v qs >/dev/null; then
    warn "quickshell not found — the shell cannot start"
fi
if ! command -v caelestia >/dev/null; then
    warn "'caelestia' CLI not found (caelestia-cli) — some features (scheme, wallpaper) will not work"
fi

for bin in cliphist wl-copy; do
    command -v "$bin" >/dev/null || warn "'$bin' is missing — the clipboard panel (Super+V) won't work"
done

# --- backup -----------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y-%m-%d-%H%M%S)"
if [[ -d "$SHELL_DIR" ]]; then
    info "backing up current shell config"
    tar -czf "$BACKUP_DIR/shell-$STAMP.tar.gz" -C "$CONFIG_HOME/quickshell" caelestia 2>/dev/null || true
fi
if [[ -f "$SHELL_JSON_DIR/shell.json" ]]; then
    cp "$SHELL_JSON_DIR/shell.json" "$BACKUP_DIR/shell.json-$STAMP"
fi
info "backups: $BACKUP_DIR"

# --- shell config -----------------------------------------------------------
mkdir -p "$CONFIG_HOME/quickshell"
same_dir() { [[ "$(realpath -m "$1")" == "$(realpath -m "$2")" ]]; }

if same_dir "$SRC_DIR" "$SHELL_DIR"; then
    info "already running from the installed config — skipping copy"
elif [[ -f "$SRC_DIR/shell.qml" ]]; then
    for f in shell.qml components modules services utils assets; do
        [[ -e "$SRC_DIR/$f" ]] || die "incomplete checkout: $SRC_DIR/$f is missing"
    done

    info "installing from local checkout: $SRC_DIR"
    rm -rf "$SHELL_DIR"
    mkdir -p "$SHELL_DIR/extra"
    cp -a "$SRC_DIR"/{shell.qml,components,modules,services,utils,assets} "$SHELL_DIR"/
    [[ -f "$SRC_DIR/IdleState.qml" ]] && cp -a "$SRC_DIR/IdleState.qml" "$SHELL_DIR"/
    cp -a "$SRC_DIR/extra/caelestia-shell.json" "$SHELL_DIR/extra"/
    [[ -f "$SRC_DIR/LICENSE" ]] && cp -a "$SRC_DIR/LICENSE" "$SHELL_DIR"/
else
    if [[ -d "$SHELL_DIR/.git" ]]; then
        info "updating existing clone"
        git -C "$SHELL_DIR" fetch --quiet origin
        git -C "$SHELL_DIR" reset --hard --quiet origin/main
    else
        info "cloning $REPO"
        rm -rf "$SHELL_DIR"
        git clone --quiet --depth 1 "$REPO" "$SHELL_DIR"
    fi
fi

[[ -f "$SHELL_DIR/extra/caelestia-shell.json" ]] || die "shell.json template not found in $SHELL_DIR/extra"

# --- shell.json -------------------------------------------------------------
mkdir -p "$SHELL_JSON_DIR"
if [[ -f "$SHELL_JSON_DIR/shell.json" && $FORCE -eq 0 ]]; then
    warn "$SHELL_JSON_DIR/shell.json already exists — kept (use -f to replace)"
else
    info "installing shell.json"
    cp "$SHELL_DIR/extra/caelestia-shell.json" "$SHELL_JSON_DIR/shell.json"
fi

# --- start ------------------------------------------------------------------
if [[ $NO_RESTART -eq 1 ]]; then
    info "done — restart the shell manually: caelestia shell -r -d"
elif command -v caelestia >/dev/null; then
    info "restarting the shell"
    caelestia shell -r -d
else
    info "starting the shell"
    if command -v qs >/dev/null; then
        qs -c caelestia -n -d
    else
        quickshell -c caelestia -n -d
    fi
fi

info "Caelestia Storm installed"
warn "Super+V / Super-tap keybinds live in your Hyprland config — see README"
info "rollback: tar -xzf $BACKUP_DIR/shell-$STAMP.tar.gz -C $CONFIG_HOME/quickshell"
