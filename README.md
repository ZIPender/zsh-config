# Zsh Terminal Setup

My Arch Linux terminal configuration.

Dark, minimal, purple-themed, and focused on useful CLI tooling without a large shell framework.

## Preview

The setup uses:

- Zsh
- Starship
- Konsole
- JetBrains Mono Nerd Font
- fzf
- zoxide
- eza
- bat
- fd
- ripgrep
- git-delta
- lazygit
- yazi
- btop
- fastfetch
- zsh-autosuggestions
- zsh-syntax-highlighting
- zsh-completions

## Install

Designed for **Arch Linux**.

Run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ZIPender/zsh-config/main/install.sh)
```

## Fastfetch logos

Every new terminal runs fastfetch with a random image from `~/.config/fastfetch/logos/`.

- Add or remove `.png` files there to change the rotation (512x512 works best).
- Images are drawn with the kitty graphics protocol, which needs Konsole and `imagemagick`.