# ============================================================
# Environment / Toolchains
# ============================================================

# Keep PATH clean and remove duplicates.
typeset -U path PATH

export VOLTA_HOME="$HOME/.volta"

path=(
  "$HOME/.local/bin"
  "$HOME/.rokit/bin"
  "$VOLTA_HOME/bin"
  $path
)

# Android Studio used by Capacitor
export CAPACITOR_ANDROID_STUDIO_PATH="$HOME/.local/share/JetBrains/Toolbox/apps/android-studio/bin/studio.sh"

# Rokit
if [[ -f "$HOME/.rokit/env" ]]; then
  source "$HOME/.rokit/env"
fi

# Mise
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi


# ============================================================
# History
# ============================================================

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt AUTO_CD


# ============================================================
# Completion
# ============================================================

# User-installed zsh-completions path used by Debian/Ubuntu setup.
if [[ -d "$HOME/.local/share/zsh/plugins/zsh-completions/src" ]]; then
  fpath=(
    "$HOME/.local/share/zsh/plugins/zsh-completions/src"
    $fpath
  )
fi

autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' group-name ''


# ============================================================
# FZF
# ============================================================

export FZF_DEFAULT_OPTS="
  --height=40%
  --layout=reverse
  --border=rounded
  --info=inline
  --ansi
  --prompt='❯ '
  --pointer='▶'
  --marker='✓'
  --color=bg+:#1b1720,bg:#111014,spinner:#bd63ff,hl:#d89aff
  --color=fg:#d9d4de,header:#bd63ff,info:#918799,pointer:#bd63ff
  --color=marker:#bd63ff,fg+:#ffffff,prompt:#bd63ff,hl+:#e879f9
  --color=border:#5d4770
"


# ------------------------------------------------------------
# Ctrl+T — fuzzy file finder
# ------------------------------------------------------------

export FZF_CTRL_T_COMMAND="
  fd \
    --type f \
    --hidden \
    --follow \
    --exclude .git \
    --exclude node_modules \
    --exclude .venv \
    --exclude __pycache__
"

export FZF_CTRL_T_OPTS="
  --prompt='File ❯ '
  --header='Ctrl+T · select file'
  --preview='bat --color=always --style=numbers --line-range=:300 {}'
  --preview-window='right:55%:wrap'
"


# ------------------------------------------------------------
# Alt+C — fuzzy directory finder
# ------------------------------------------------------------

export FZF_ALT_C_COMMAND="
  fd \
    --type d \
    --hidden \
    --follow \
    --exclude .git \
    --exclude node_modules \
    --exclude .venv \
    --exclude __pycache__
"

export FZF_ALT_C_OPTS="
  --prompt='Dir ❯ '
  --header='Alt+C · jump to directory'
  --preview='eza --tree --level=2 --icons=always --color=always {}'
  --preview-window='right:55%:wrap'
"


# ------------------------------------------------------------
# Ctrl+R — fuzzy command history
# ------------------------------------------------------------

export FZF_CTRL_R_OPTS="
  --prompt='History ❯ '
  --header='Ctrl+R · command history'
"

eval "$(fzf --zsh)"


# ============================================================
# Zoxide
# ============================================================

eval "$(zoxide init zsh)"


# ============================================================
# Yazi
#
# Use `y` instead of `yazi`.
# When Yazi closes, Zsh follows its current directory.
# ============================================================

y() {
  local tmp
  local cwd

  tmp="$(mktemp -t 'yazi-cwd.XXXXXX')" || return

  yazi "$@" --cwd-file="$tmp"

  if [[ -s "$tmp" ]]; then
    cwd="$(<"$tmp")"

    if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
      builtin cd -- "$cwd"
    fi
  fi

  rm -f -- "$tmp"
}


# ============================================================
# Interactive project content search
#
# rgf
#   Live-search inside files.
#   Enter opens the exact result in VS Code.
# ============================================================

rgf() {
  local selected
  local file
  local line

  selected=$(
    printf '' | fzf \
      --disabled \
      --delimiter=: \
      --prompt='Search ❯ ' \
      --header='Live project search · Enter opens in VS Code' \
      --bind "change:reload:rg \
        --column \
        --line-number \
        --no-heading \
        --smart-case \
        --hidden \
        --glob '!.git/*' \
        --glob '!node_modules/*' \
        --glob '!.venv/*' \
        --glob '!__pycache__/*' \
        {q} || true" \
      --preview='bat \
        --color=always \
        --style=numbers \
        --highlight-line {2} \
        --line-range {2}:+35 \
        {1}' \
      --preview-window='right:60%:+{2}-5'
  ) || return

  file="${selected%%:*}"
  line="${selected#*:}"
  line="${line%%:*}"

  if [[ -n "$file" && -n "$line" ]]; then
    code -g "$file:$line"
  fi
}


# ============================================================
# ComfyUI
# ============================================================

# Runs ComfyUI inside a subshell:
# - activates the venv
# - starts ComfyUI
# - returns to your original directory when it exits
comfy() (
  cd "$HOME/ai/ComfyUI" || return

  source .venv/bin/activate

  python main.py --enable-manager
)

alias comfyui='comfy'


# ============================================================
# System update
# ============================================================

sysup() {
  sudo pacman -Syu || return

  if command -v yay >/dev/null 2>&1; then
    yay -Sua || return
  fi

  if command -v flatpak >/dev/null 2>&1; then
    flatpak update -y || return
  fi

  local orphans
  orphans="$(pacman -Qdtq 2>/dev/null || true)"

  if [[ -n "$orphans" ]]; then
    sudo pacman -Rns -- ${(f)orphans}
  fi
}


# ============================================================
# Aliases
# ============================================================

alias ls='eza --icons=auto --group-directories-first'
alias ll='eza -lah --icons=auto --git --group-directories-first'
alias la='eza -a --icons=auto --group-directories-first'
alias tree='eza --tree --icons=auto'

alias cat='bat --paging=never'
alias grep='grep --color=auto'

alias lg='lazygit'
alias ff='fastfetch'

# fastfetch with a random logo from ~/.config/fastfetch/logos
fastfetch() {
  local logos=(~/.config/fastfetch/logos/*.png(N))
  if (( $#logos )); then
    command fastfetch --logo "${logos[RANDOM % $#logos + 1]}" "$@"
  else
    command fastfetch "$@"
  fi
}

# ngrok → Ollama HTTPS forwarding
alias ngrok-ollama='ngrok http --host-header=rewrite 11434'


# ============================================================
# Zsh Autosuggestions
# ============================================================

if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

elif [[ -f "$HOME/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOME/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi


# ============================================================
# Starship Prompt
# ============================================================

eval "$(starship init zsh)"


# ============================================================
# Fastfetch on fresh terminal
#
# Shows once when a new terminal tab/window starts.
# Does not repeat after `exec zsh`.
# ============================================================

if [[ -o interactive && -z "${FASTFETCH_SHOWN:-}" ]]; then
  export FASTFETCH_SHOWN=1

  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
  fi
fi


# ============================================================
# Syntax Highlighting
#
# IMPORTANT:
# Keep this at the very end of .zshrc
# ============================================================

if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

elif [[ -f "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi