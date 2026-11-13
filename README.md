# Mist Setup

Opinionated Arch Linux setup for the Mist Hyprland + Quickshell desktop.

This is an **install script**, not an ISO. It assumes you already have a fresh
Arch Linux installation with a bootloader and can log in.

## What it installs

- Hyprland, Quickshell, Ghostty, Qt Wayland, portals
- PipeWire, WirePlumber, NetworkManager, Bluetooth
- zsh, Oh My Zsh, Powerlevel10k, MesloLGS NF fonts
- Neovim with Lazy.nvim plugins, LSP servers, formatters, and Treesitter
- AMD/Intel graphics drivers, CPU microcode, zram configuration
- Optional apps and AUR packages with `--full`

## Dependencies

- A fresh Arch Linux installation
- A normal user account with sudo access
- Network access
- Existing bootloader and kernel setup

The script does **not** partition disks, install a bootloader, or edit fstab.

## Fresh Arch bootstrap

On a minimal fresh Arch install, install the tools needed to clone and run the
installer:

```sh
sudo pacman -S --needed git sudo
sudo usermod -aG wheel "$USER"
git clone <this-repo> ~/mist-setup
cd ~/mist-setup
./install.sh --dry-run
./install.sh
```

Make sure your user can use sudo before running the installer.

## Usage

```sh
git clone <this-repo> ~/mist-setup
cd ~/mist-setup
chmod +x install.sh
./install.sh
```

Common options:

```sh
./install.sh --dry-run          # show what would happen
./install.sh --yes              # accept defaults
./install.sh --full             # include optional apps, AUR, OpenCode
./install.sh --no-nvim          # skip Neovim plugin bootstrap
./install.sh --no-dotfiles      # packages only
```

## Repository layout

```text
install.sh                 Main installer
packages/core.txt          Base system, audio, networking, shell
packages/desktop.txt       Hyprland, Quickshell, Ghostty, fonts
packages/dev.txt           Neovim, compilers, search tools
packages/apps.txt          Optional applications
packages/aur.txt           Optional AUR applications
dotfiles/                  Sanitized user configuration
system/                    System-level configuration (zram)
scripts/nvim-mason.lua     Neovim LSP/tool bootstrap
```

## Dotfiles included

- `~/.config/hypr`
- `~/.config/quickshell`
- `~/.config/ghostty`
- `~/.config/nvim`
- `~/.config/btop`
- `~/.config/pacseek`
- `~/.config/starship`
- `~/.config/wallpaper`
- `~/.zshrc`
- `~/.p10k.zsh`

Personal data such as SSH keys, browser profiles, tokens, shell history, and
project directories is intentionally excluded.

Existing files are backed up with a `.pre-mist-<timestamp>` suffix before being
replaced.

## After install

1. Reboot or log out and back in.
2. Start Hyprland from a TTY:
   ```sh
   Hyprland
   ```
3. In Ghostty:
   ```sh
   source ~/.zshrc
   ```
4. If Powerlevel10k asks, run:
   ```sh
   p10k configure
   ```
5. Open Neovim once to finish any remaining LSP/tool installs.

## Notes

- `quickshell` renders the wallpaper itself; `awww` is not installed.
- The Ghostty theme is generated from the current wallpaper by
  `~/.config/ghostty/sync-theme.py`.
- `--full` installs optional apps from `packages/apps.txt` and AUR packages from
  `packages/aur.txt`.
- OpenCode is installed only with `--full` or `--opencode`.
