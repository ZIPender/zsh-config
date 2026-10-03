#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# ZIPender Terminal Setup
#
# Repository:
# https://github.com/ZIPender/zsh-config
#
# Supported:
#   - Arch Linux
#   - Ubuntu
#   - Debian
#
# Remote install:
#
#   bash <(curl -fsSL \
#     https://raw.githubusercontent.com/ZIPender/zsh-config/main/install.sh)
#
# Local install:
#
#   ./install.sh
# ============================================================

REPO="ZIPender/zsh-config"
BRANCH="main"

BIN_DIR="$HOME/.local/bin"

mkdir -p "$BIN_DIR"

export PATH="$BIN_DIR:$PATH"


# ============================================================
# Helpers
# ============================================================

info() {
    printf '\n==> %s\n' "$*"
}

note() {
    printf '    %s\n' "$*"
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}


# ------------------------------------------------------------
# Root command helper
# ------------------------------------------------------------

if (( EUID == 0 )); then
    SUDO=()
elif command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
else
    SUDO=()
fi

need_root() {
    if (( EUID != 0 )) && ! command -v sudo >/dev/null 2>&1; then
        die "This system needs sudo (or a root shell) to install system packages."
    fi
}


# ------------------------------------------------------------
# GitHub latest-release asset URL
# ------------------------------------------------------------

github_asset_url() {
    local repo="$1"
    local regex="$2"

    curl -fsSL \
        "https://api.github.com/repos/${repo}/releases/latest" |
        sed -n \
            's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p' |
        grep -E "$regex" |
        head -n 1
}


# ------------------------------------------------------------
# Install binaries from a GitHub release archive
# ------------------------------------------------------------

install_github_binaries() {
    local repo="$1"
    local regex="$2"

    shift 2

    local binaries=("$@")
    local url
    local tmp
    local archive
    local binary
    local found

    url="$(github_asset_url "$repo" "$regex")"

    if [[ -z "$url" ]]; then
        die "Could not find a matching release asset for $repo"
    fi

    tmp="$(mktemp -d)"
    archive="$tmp/archive"

    note "Downloading $repo"

    curl -fsSL "$url" -o "$archive"

    case "$url" in
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$tmp"
            ;;

        *.tar.xz)
            tar -xJf "$archive" -C "$tmp"
            ;;

        *.zip)
            unzip -q "$archive" -d "$tmp"
            ;;

        *)
            rm -rf "$tmp"
            die "Unsupported archive format from $repo: $url"
            ;;
    esac

    for binary in "${binaries[@]}"; do
        found="$(
            find "$tmp" \
                -type f \
                -name "$binary" \
                -not -path "$archive" \
                -print \
                -quit
        )"

        if [[ -z "$found" ]]; then
            rm -rf "$tmp"
            die "Could not find '$binary' inside the $repo release."
        fi

        install -m 0755 "$found" "$BIN_DIR/$binary"
    done

    rm -rf "$tmp"
}


# ============================================================
# Remote bootstrap
# ============================================================

SELF_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null &&
    pwd ||
    true
)"

if [[ "${1:-}" != "--local" && ! -d "${SELF_DIR:-}/config" ]]; then
    echo "==> Downloading terminal configuration"

    command -v curl >/dev/null 2>&1 ||
        die "curl is required."

    command -v tar >/dev/null 2>&1 ||
        die "tar is required."

    TMP="$(mktemp -d)"

    trap 'rm -rf "$TMP"' EXIT

    ARCHIVE="$TMP/repo.tar.gz"

    curl -fsSL \
        "https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz" \
        -o "$ARCHIVE"

    tar -xzf "$ARCHIVE" -C "$TMP"

    REPO_NAME="${REPO##*/}"
    EXTRACTED="$TMP/${REPO_NAME}-${BRANCH}"

    [[ -f "$EXTRACTED/install.sh" ]] ||
        die "Downloaded repository is missing install.sh."

    bash "$EXTRACTED/install.sh" --local
    exit $?
fi


# ============================================================
# Repository paths
# ============================================================

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$ROOT/config"
PACKAGES="$ROOT/packages.txt"

[[ -d "$CONFIG" ]] ||
    die "Missing config directory: $CONFIG"


# ============================================================
# Detect distribution
# ============================================================

DISTRO=""
DISTRO_ID=""
DISTRO_LIKE=""

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release

    DISTRO_ID="${ID:-}"
    DISTRO_LIKE="${ID_LIKE:-}"
fi

case "$DISTRO_ID" in
    arch|cachyos|endeavouros|manjaro)
        DISTRO="arch"
        ;;

    ubuntu|debian|linuxmint|pop)
        DISTRO="debian"
        ;;

    *)
        if [[ "$DISTRO_LIKE" == *arch* ]]; then
            DISTRO="arch"
        elif [[ "$DISTRO_LIKE" == *debian* || "$DISTRO_LIKE" == *ubuntu* ]]; then
            DISTRO="debian"
        elif command -v pacman >/dev/null 2>&1; then
            DISTRO="arch"
        elif command -v apt-get >/dev/null 2>&1; then
            DISTRO="debian"
        else
            die "Unsupported Linux distribution."
        fi
        ;;
esac

info "Detected distribution"

note "${PRETTY_NAME:-$DISTRO_ID}"


# ============================================================
# Architecture
# ============================================================

MACHINE_ARCH="$(uname -m)"

case "$MACHINE_ARCH" in
    x86_64|amd64)
        ARCH="x86_64"

        FZF_ASSET='fzf-[^/]+-linux_amd64\.tar\.gz$'
        EZA_ASSET='eza_x86_64-unknown-linux-gnu\.tar\.gz$'
        BAT_ASSET='bat-v[^/]+-x86_64-unknown-linux-gnu\.tar\.gz$'
        FD_ASSET='fd-v[^/]+-x86_64-unknown-linux-gnu\.tar\.gz$'
        RG_ASSET='ripgrep-[^/]+-x86_64-unknown-linux-(gnu|musl)\.tar\.gz$'
        DELTA_ASSET='delta-[^/]+-x86_64-unknown-linux-gnu\.tar\.gz$'
        LAZYGIT_ASSET='lazygit_[^/]+_[Ll]inux_x86_64\.tar\.gz$'
        YAZI_ASSET='yazi-x86_64-unknown-linux-gnu\.zip$'
        FASTFETCH_ASSET='fastfetch-linux-amd64\.tar\.gz$'
        ;;

    aarch64|arm64)
        ARCH="aarch64"

        FZF_ASSET='fzf-[^/]+-linux_arm64\.tar\.gz$'
        EZA_ASSET='eza_aarch64-unknown-linux-gnu\.tar\.gz$'
        BAT_ASSET='bat-v[^/]+-aarch64-unknown-linux-gnu\.tar\.gz$'
        FD_ASSET='fd-v[^/]+-aarch64-unknown-linux-gnu\.tar\.gz$'
        RG_ASSET='ripgrep-[^/]+-aarch64-unknown-linux-gnu\.tar\.gz$'
        DELTA_ASSET='delta-[^/]+-aarch64-unknown-linux-gnu\.tar\.gz$'
        LAZYGIT_ASSET='lazygit_[^/]+_[Ll]inux_arm64\.tar\.gz$'
        YAZI_ASSET='yazi-aarch64-unknown-linux-gnu\.zip$'
        FASTFETCH_ASSET='fastfetch-linux-aarch64\.tar\.gz$'
        ;;

    *)
        ARCH="other"
        ;;
esac


# ============================================================
# Arch package installation
# ============================================================

install_arch_packages() {
    command -v pacman >/dev/null 2>&1 ||
        die "pacman was not found."

    [[ -f "$PACKAGES" ]] ||
        die "Missing packages.txt: $PACKAGES"

    need_root

    info "Installing Arch packages"

    mapfile -t pkgs < <(
        grep -Ev '^[[:space:]]*(#|$)' "$PACKAGES"
    )

    if (( ${#pkgs[@]} > 0 )); then
        "${SUDO[@]}" pacman -S --needed "${pkgs[@]}"
    fi
}


# ============================================================
# Ubuntu / Debian installation
# ============================================================

install_debian_packages() {
    command -v apt-get >/dev/null 2>&1 ||
        die "apt-get was not found."

    need_root

    info "Installing Ubuntu / Debian base packages"

    "${SUDO[@]}" apt-get update

    local packages=(
        zsh
        git
        curl
        ca-certificates
        tar
        unzip
        fontconfig
    )

    "${SUDO[@]}" apt-get install -y "${packages[@]}"

    # btop is optional for the shell itself, but install it when
    # the distro repository provides it.
    if apt-cache show btop >/dev/null 2>&1; then
        "${SUDO[@]}" apt-get install -y btop
    else
        note "btop is not available in this distro repository; skipping it."
    fi
}


# ============================================================
# Ubuntu / Debian current CLI binaries
#
# Installed to ~/.local/bin so distro package versions do not
# limit features required by this configuration.
# ============================================================

install_debian_cli_tools() {
    info "Installing current CLI tools"

    if [[ "$ARCH" == "other" ]]; then
        die "Automatic binary installation currently supports x86_64 and arm64."
    fi

    mkdir -p "$BIN_DIR"

    # fzf
    install_github_binaries \
        "junegunn/fzf" \
        "$FZF_ASSET" \
        fzf

    # eza
    install_github_binaries \
        "eza-community/eza" \
        "$EZA_ASSET" \
        eza

    # bat
    install_github_binaries \
        "sharkdp/bat" \
        "$BAT_ASSET" \
        bat

    # fd
    install_github_binaries \
        "sharkdp/fd" \
        "$FD_ASSET" \
        fd

    # ripgrep
    install_github_binaries \
        "BurntSushi/ripgrep" \
        "$RG_ASSET" \
        rg

    # git-delta
    install_github_binaries \
        "dandavison/delta" \
        "$DELTA_ASSET" \
        delta

    # lazygit
    install_github_binaries \
        "jesseduffield/lazygit" \
        "$LAZYGIT_ASSET" \
        lazygit

    # yazi + ya
    install_github_binaries \
        "sxyazi/yazi" \
        "$YAZI_ASSET" \
        yazi \
        ya

    # fastfetch
    install_github_binaries \
        "fastfetch-cli/fastfetch" \
        "$FASTFETCH_ASSET" \
        fastfetch


    # --------------------------------------------------------
    # Starship
    # --------------------------------------------------------

    note "Installing Starship"

    curl -sS https://starship.rs/install.sh |
        sh -s -- \
            -y \
            -b "$BIN_DIR"


    # --------------------------------------------------------
    # Zoxide
    # --------------------------------------------------------

    note "Installing zoxide"

    curl -sSfL \
        https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh |
        sh

    if [[ ! -x "$BIN_DIR/zoxide" ]] &&
       command -v zoxide >/dev/null 2>&1; then
        note "zoxide installed at $(command -v zoxide)"
    fi
}


# ============================================================
# Nerd Font
# ============================================================

install_nerd_font() {
    info "Installing JetBrains Mono Nerd Font"

    local font_dir
    local tmp

    font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    tmp="$(mktemp -d)"

    mkdir -p "$font_dir"

    curl -fsSL \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
        -o "$tmp/JetBrainsMono.zip"

    unzip -oq \
        "$tmp/JetBrainsMono.zip" \
        -d "$font_dir"

    rm -rf "$tmp"

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$font_dir" >/dev/null 2>&1 || true
    fi
}


# ============================================================
# Zsh plugins for Debian / Ubuntu
# ============================================================

install_zsh_plugins() {
    local base

    base="$HOME/.local/share/zsh/plugins"

    mkdir -p "$base"

    info "Installing Zsh plugins"

    install_or_update_git_repo \
        "https://github.com/zsh-users/zsh-autosuggestions.git" \
        "$base/zsh-autosuggestions"

    install_or_update_git_repo \
        "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
        "$base/zsh-syntax-highlighting"

    install_or_update_git_repo \
        "https://github.com/zsh-users/zsh-completions.git" \
        "$base/zsh-completions"
}


install_or_update_git_repo() {
    local url="$1"
    local destination="$2"

    if [[ -d "$destination/.git" ]]; then
        git -C "$destination" pull --ff-only
    else
        rm -rf "$destination"

        git clone \
            --depth 1 \
            "$url" \
            "$destination"
    fi
}


# ============================================================
# Install packages
# ============================================================

case "$DISTRO" in
    arch)
        install_arch_packages
        ;;

    debian)
        install_debian_packages
        install_debian_cli_tools
        install_nerd_font
        install_zsh_plugins
        ;;
esac


# ============================================================
# Backup existing configuration
# ============================================================

BACKUP_ROOT="$HOME/.local/share/zsh-config-backups"
BACKUP="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP"

info "Backing up existing configuration"

note "$BACKUP"

while IFS= read -r -d '' src; do
    rel="${src#$CONFIG/}"
    target="$HOME/$rel"

    if [[ -e "$target" || -L "$target" ]]; then
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a "$target" "$BACKUP/$rel"
    fi
done < <(
    find "$CONFIG" -type f -print0
)

# git-delta changes ~/.gitconfig, so back it up too.
if [[ -f "$HOME/.gitconfig" ]]; then
    cp -a "$HOME/.gitconfig" "$BACKUP/.gitconfig"
fi


# ============================================================
# Install captured configuration
# ============================================================

info "Installing configuration"

while IFS= read -r -d '' src; do
    rel="${src#$CONFIG/}"
    target="$HOME/$rel"

    mkdir -p "$(dirname "$target")"

    cp -a "$src" "$target"

    note "$rel"
done < <(
    find "$CONFIG" -type f -print0
)


# ============================================================
# Cross-distro .zshrc compatibility
# ============================================================

ZSHRC="$HOME/.zshrc"

if [[ -f "$ZSHRC" ]]; then

    # --------------------------------------------------------
    # ~/.local/bin
    # --------------------------------------------------------

    if ! grep -Fq \
        'export PATH="$HOME/.local/bin:$PATH"' \
        "$ZSHRC"
    then
        tmp="$(mktemp)"

        {
            printf '%s\n\n' \
                'export PATH="$HOME/.local/bin:$PATH"'

            cat "$ZSHRC"
        } > "$tmp"

        mv "$tmp" "$ZSHRC"
    fi


    # --------------------------------------------------------
    # Ubuntu / Debian Zsh plugins
    # --------------------------------------------------------

    if [[ "$DISTRO" == "debian" ]]; then
        PLUGIN_BASE="$HOME/.local/share/zsh/plugins"

        sed -i \
            "s|^source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh$|source \"$PLUGIN_BASE/zsh-autosuggestions/zsh-autosuggestions.zsh\"|" \
            "$ZSHRC"

        sed -i \
            "s|^source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh$|source \"$PLUGIN_BASE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh\"|" \
            "$ZSHRC"


        # Add zsh-completions to fpath before compinit.
        if ! grep -Fq \
            '.local/share/zsh/plugins/zsh-completions/src' \
            "$ZSHRC"
        then
            tmp="$(mktemp)"

            awk '
                /^autoload -Uz compinit/ && !added {
                    print "fpath=(\"$HOME/.local/share/zsh/plugins/zsh-completions/src\" $fpath)"
                    print ""
                    added=1
                }

                {
                    print
                }
            ' "$ZSHRC" > "$tmp"

            mv "$tmp" "$ZSHRC"
        fi
    fi
fi


# ============================================================
# Git Delta
# ============================================================

if command -v delta >/dev/null 2>&1; then
    info "Configuring Git Delta"

    git config --global core.pager delta

    git config \
        --global \
        interactive.diffFilter \
        'delta --color-only'

    git config \
        --global \
        delta.navigate \
        true

    git config \
        --global \
        delta.side-by-side \
        false

    git config \
        --global \
        merge.conflictStyle \
        zdiff3
fi


# ============================================================
# Konsole
#
# The files are installed on every distro, but we only attempt
# to change Konsole's default profile when KDE tooling exists.
# ============================================================

KONSOLE_PROFILE="$HOME/.local/share/konsole/Zsh Purple.profile"

if [[ -f "$KONSOLE_PROFILE" ]]; then

    if command -v kwriteconfig6 >/dev/null 2>&1; then
        info "Setting Konsole profile"

        kwriteconfig6 \
            --file konsolerc \
            --group "Desktop Entry" \
            --key DefaultProfile \
            "Zsh Purple.profile"

    elif command -v kwriteconfig5 >/dev/null 2>&1; then
        info "Setting Konsole profile"

        kwriteconfig5 \
            --file konsolerc \
            --group "Desktop Entry" \
            --key DefaultProfile \
            "Zsh Purple.profile"

    elif command -v konsole >/dev/null 2>&1; then
        note "Konsole profile installed."
        note "Set 'Zsh Purple' as the default profile manually."
    fi
fi


# ============================================================
# Login shell
# ============================================================

ZSH_BIN="$(command -v zsh || true)"

if [[ -n "$ZSH_BIN" ]]; then
    current_shell=""

    if command -v getent >/dev/null 2>&1; then
        current_shell="$(
            getent passwd "$USER" 2>/dev/null |
            cut -d: -f7
        )"
    fi

    if [[ "$current_shell" != "$ZSH_BIN" ]]; then
        info "Setting Zsh as login shell"

        if command -v chsh >/dev/null 2>&1 && [[ -t 0 ]]; then
            chsh -s "$ZSH_BIN" "$USER" || {
                echo
                note "Could not change the login shell automatically."
                note "Run manually:"
                echo
                echo "  chsh -s $ZSH_BIN"
            }
        else
            echo
            note "Run this after installation:"
            echo
            echo "  chsh -s $ZSH_BIN"
        fi
    fi
fi


# ============================================================
# Verification
# ============================================================

info "Installed tools"

TOOLS=(
    zsh
    starship
    fzf
    zoxide
    eza
    bat
    fd
    rg
    delta
    lazygit
    yazi
    btop
    fastfetch
)

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf '    %-12s %s\n' \
            "$tool" \
            "$(command -v "$tool")"
    else
        printf '    %-12s %s\n' \
            "$tool" \
            "not installed"
    fi
done


# ============================================================
# Done
# ============================================================

echo
echo "============================================================"
echo " Terminal setup installed"
echo "============================================================"
echo
echo "Distribution:"
echo
echo "  ${PRETTY_NAME:-$DISTRO_ID}"
echo
echo "Previous configuration backup:"
echo
echo "  $BACKUP"
echo
echo "Start a fresh Zsh session with:"
echo
echo "  exec zsh"
echo

if [[ -n "${ZSH_BIN:-}" ]]; then
    echo "If the login shell changed for the first time,"
    echo "log out and back in once."
    echo
fi

if command -v konsole >/dev/null 2>&1; then
    echo "For Konsole profile changes, close every Konsole window"
    echo "and open a new one."
    echo
fi