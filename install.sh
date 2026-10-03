#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# ZIPender Terminal Setup
#
# Repository:
# https://github.com/ZIPender/zsh-config
#
# Remote install:
# bash <(curl -fsSL \
#   https://raw.githubusercontent.com/ZIPender/zsh-config/main/install.sh)
#
# Local install:
# ./install.sh
# ============================================================

REPO="ZIPender/zsh-config"
BRANCH="main"

# ============================================================
# Remote bootstrap
# ============================================================

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

if [[ "${1:-}" != "--local" && ! -d "${SELF_DIR:-}/config" ]]; then
    echo "==> Downloading terminal configuration"

    if ! command -v curl >/dev/null 2>&1; then
        echo "Error: curl is required." >&2
        exit 1
    fi

    if ! command -v tar >/dev/null 2>&1; then
        echo "Error: tar is required." >&2
        exit 1
    fi

    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    ARCHIVE="$TMP/repo.tar.gz"

    curl -fsSL \
        "https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz" \
        -o "$ARCHIVE"

    tar -xzf "$ARCHIVE" -C "$TMP"

    REPO_NAME="${REPO##*/}"
    EXTRACTED="$TMP/${REPO_NAME}-${BRANCH}"

    if [[ ! -f "$EXTRACTED/install.sh" ]]; then
        echo "Error: downloaded repository is missing install.sh." >&2
        exit 1
    fi

    bash "$EXTRACTED/install.sh" --local
    exit $?
fi


# ============================================================
# Paths
# ============================================================

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$ROOT/config"
PACKAGES="$ROOT/packages.txt"


# ============================================================
# Validation
# ============================================================

if [[ ! -d "$CONFIG" ]]; then
    echo "Error: missing config directory:" >&2
    echo "  $CONFIG" >&2
    exit 1
fi

if [[ ! -f "$PACKAGES" ]]; then
    echo "Error: missing packages.txt:" >&2
    echo "  $PACKAGES" >&2
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "Error: this installer is intended for Arch Linux." >&2
    exit 1
fi


# ============================================================
# Packages
# ============================================================

echo
echo "==> Installing packages"

mapfile -t pkgs < <(
    grep -Ev '^[[:space:]]*(#|$)' "$PACKAGES"
)

if (( ${#pkgs[@]} > 0 )); then
    sudo pacman -S --needed "${pkgs[@]}"
fi


# ============================================================
# Backup existing configuration
# ============================================================

BACKUP_ROOT="$HOME/.local/share/zsh-config-backups"
BACKUP="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP"

echo
echo "==> Backing up existing configuration"
echo "    $BACKUP"

while IFS= read -r -d '' src; do
    rel="${src#$CONFIG/}"
    target="$HOME/$rel"

    if [[ -e "$target" || -L "$target" ]]; then
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a "$target" "$BACKUP/$rel"
    fi
done < <(find "$CONFIG" -type f -print0)


# ============================================================
# Install configuration
# ============================================================

echo
echo "==> Installing configuration"

while IFS= read -r -d '' src; do
    rel="${src#$CONFIG/}"
    target="$HOME/$rel"

    mkdir -p "$(dirname "$target")"
    cp -a "$src" "$target"

    echo "    $rel"
done < <(find "$CONFIG" -type f -print0)


# ============================================================
# Konsole
# ============================================================

KONSOLE_PROFILE="$HOME/.local/share/konsole/Zsh Purple.profile"

if [[ -f "$KONSOLE_PROFILE" ]]; then
    echo
    echo "==> Setting Konsole profile"

    if command -v kwriteconfig6 >/dev/null 2>&1; then
        kwriteconfig6 \
            --file konsolerc \
            --group "Desktop Entry" \
            --key DefaultProfile \
            "Zsh Purple.profile"

    elif command -v kwriteconfig5 >/dev/null 2>&1; then
        kwriteconfig5 \
            --file konsolerc \
            --group "Desktop Entry" \
            --key DefaultProfile \
            "Zsh Purple.profile"

    else
        echo "    Could not set the default Konsole profile automatically."
        echo "    Set 'Zsh Purple' as default manually in Konsole."
    fi
fi


# ============================================================
# Login shell
# ============================================================

if [[ -x /usr/bin/zsh ]]; then
    current_shell="$(
        getent passwd "$USER" 2>/dev/null |
        cut -d: -f7
    )"

    if [[ "$current_shell" != "/usr/bin/zsh" ]]; then
        echo
        echo "==> Setting Zsh as login shell"

        if [[ -t 0 ]]; then
            chsh -s /usr/bin/zsh "$USER" || {
                echo
                echo "Could not change the login shell automatically."
                echo "Run manually:"
                echo
                echo "  chsh -s /usr/bin/zsh"
            }
        else
            echo
            echo "Run this after installation:"
            echo
            echo "  chsh -s /usr/bin/zsh"
        fi
    fi
fi


# ============================================================
# Done
# ============================================================

echo
echo "============================================================"
echo " Terminal setup installed"
echo "============================================================"
echo
echo "Previous configuration backup:"
echo
echo "  $BACKUP"
echo
echo "Close all Konsole windows and open a new one."
echo
echo "If Zsh was set as your login shell for the first time,"
echo "log out of Plasma and log back in once."
echo