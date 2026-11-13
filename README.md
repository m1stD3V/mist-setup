# Mist Setup

Opinionated Arch Linux setup for the Mist Hyprland + Quickshell desktop.

This is an **install script**, not an ISO. It assumes you already have a fresh
Arch Linux installation with a bootloader and can log in.

## What it installs

- Hyprland, Quickshell, Ghostty, Qt Wayland, portals
- PipeWire, WirePlumber, NetworkManager, Bluetooth
- zsh, Oh My Zsh, Powerlevel10k, MesloLGS NF fonts
- eza with Nerd Font file icons (`ls`, `l`, `ll`, `la`, `lt`, `tree`)
- The icons-in-terminal glyph font plus its fontconfig fallback rule
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
git clone https://github.com/m1stD3V/mist-setup.git ~/Projects/Personal/mist-setup
cd ~/Projects/Personal/mist-setup
./install.sh --dry-run
./install.sh
```

Make sure your user can use sudo before running the installer.

## Usage

```sh
git clone https://github.com/m1stD3V/mist-setup.git ~/Projects/Personal/mist-setup
cd ~/Projects/Personal/mist-setup
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
LICENSE                    MIT license for the installer and configuration
CREDITS.md                 Third-party asset attribution
LICENSES/                  Font and plugin license texts
packages/core.txt          Base system, audio, networking, shell
packages/desktop.txt       Hyprland, Quickshell, Ghostty, fonts
packages/dev.txt           Neovim, compilers, search tools
packages/apps.txt          Optional applications
packages/aur.txt           Optional AUR applications
dotfiles/                  User configuration (bundled assets credited in CREDITS.md)
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
- `~/.config/fontconfig` (icons-in-terminal fallback)
- `~/.local/share/fonts/icons-in-terminal.ttf`
- `~/.zshrc`
- `~/.p10k.zsh`

Personal data such as SSH keys, browser profiles, tokens, shell history, and
project directories is intentionally excluded. The bundled wallpapers and
fonts are third-party assets; their authors and licenses are listed in
[`CREDITS.md`](CREDITS.md).

Existing files are backed up with a `.pre-mist-<timestamp>` suffix before being
replaced.

## Portability

The deployed config avoids machine-specific values:

- Hyprland applies `preferred` mode, automatic position and `auto` scale to
  every output, so laptops (`eDP`), desktops (`DP`/`HDMI`) and external
  monitors work without editing the config.
- Quickshell panels scale down proportionally on screens smaller than the
  1920x1080 design baseline, and the launcher sizes pacseek's terminal and
  font to fit the focused monitor.
- Shell icon aliases are conditional: if `eza` is missing, the normal
  oh-my-zsh `ls` alias is kept.
- GPU/CPU packages are detected during install (`install.sh`), and the battery
  widget hides itself on machines without a battery.

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
- The bundled `icons-in-terminal.ttf` comes from
  [sebastiencs/icons-in-terminal](https://github.com/sebastiencs/icons-in-terminal)
  and is MIT licensed; see [`CREDITS.md`](CREDITS.md) for the notice.

## License and credits

The installer and configuration are released under the [MIT License](LICENSE),
except for the Discord bridge plugin, which is GPL-3.0-or-later.

Bundled assets keep their own licenses: `Tiny5.ttf` is SIL OFL 1.1,
`icons-in-terminal.ttf` is MIT, the Discord bridge plugin is
GPL-3.0-or-later, and the wallpapers remain the property of their original
authors. See [`CREDITS.md`](CREDITS.md) and [`LICENSES/`](LICENSES/) for the
full attribution and license texts.
