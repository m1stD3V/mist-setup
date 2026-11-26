# Mist Setup

Opinionated Arch Linux setup for the Mist Hyprland + Quickshell desktop.

This is an **install script**, not an ISO. It assumes you already have a fresh
Arch Linux installation with a bootloader and can log in.

## What it installs

- Hyprland, Quickshell, Ghostty, Qt Wayland, portals
- PipeWire, WirePlumber, NetworkManager, Bluetooth
- power-profiles-daemon for the bar's battery and power profile popup
- zsh, Oh My Zsh, Powerlevel10k, MesloLGS NF fonts
- yay (AUR helper) and pacseek, the package browser the launcher opens
  (pacseek is built from source into `~/.local/bin`)
- eza with Nerd Font file icons (`ls`, `l`, `ll`, `la`, `lt`, `tree`)
- The icons-in-terminal glyph font plus its fontconfig fallback rule
- Neovim with Lazy.nvim plugins, LSP servers, formatters, and Treesitter
- AMD/Intel graphics drivers (NVIDIA open driver when detected), CPU microcode,
  zram configuration
- OpenCode CLI, the textfox Firefox chrome, and the DiscordBridge plugin by
  default; optional apps and AUR packages with `--full`

A plain run is unattended: it installs every package the desktop needs, enables
the services, generates the themes and deploys the dotfiles without asking a
question. `--interactive` restores the confirmation prompts.

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

A plain run does not stop for input. It installs the core, desktop and dev
package groups, the NVIDIA driver when NVIDIA is detected, OpenCode, Firefox
with textfox, Discord and the DiscordBridge plugin, then deploys the dotfiles.
One sudo password prompt at the start is the only interaction; the installer
keeps that sudo session alive for the rest of the run.

Common options:

```sh
./install.sh --dry-run          # show what would happen
./install.sh --interactive      # ask before installing/updating (old behavior)
./install.sh --full             # also install optional apps and AUR packages
./install.sh --no-apps          # skip the optional applications group
./install.sh --no-aur           # skip AUR packages
./install.sh --no-opencode      # skip the OpenCode CLI
./install.sh --no-nvidia        # do not install the NVIDIA driver
./install.sh --no-textfox       # skip the Firefox chrome theme
./install.sh --no-discord-bridge  # skip the client mod
./install.sh --no-nvim          # skip Neovim plugin bootstrap
./install.sh --no-dotfiles      # packages only
```

The installer also handles its own prerequisites: it installs `git` and `curl`
when missing, waits for the network, and refreshes the pacman keyring if the
first system update fails on signatures. A run started as root works too
(`sudo ./install.sh` keeps targeting the invoking account).

The output follows the desktop theme: a pink and violet block wordmark, numbered
sections and bracketed status tags (`[ ok ]`, `[warn]`, `[fail]`). It falls back
to plain text when the output is piped, or when `NO_COLOR=1` / `MIST_PLAIN=1` is
set, so logs from `--check` stay readable.

## Updating an existing install

`--update` brings a machine that already runs Mist up to the current revision:

```sh
./install.sh --check            # report remote commits, package and dotfile drift
./install.sh --update           # fetch, pull, install missing packages, deploy changes
./install.sh --update --diff    # also show unified diffs for changed dotfiles
./install.sh --update --force   # replace files edited both locally and upstream
./install.sh --update --keep-local  # keep files with no deploy record
```

It works in three steps:

1. **Remote** — fetches `origin`, lists the new commits and changed files, and
   fast-forwards the checkout. A dirty tree or a diverged branch is left alone
   with a warning. If `install.sh` itself changed, the update restarts with the
   new script.
2. **Packages** — upgrades the system, then compares `packages/*.txt` with
   `pacman -T` and installs anything added upstream. Pass `--no-packages` to
   leave packages alone, or `--full` / `--apps` / `--aur` to include the
   optional groups. Like a fresh install, `--update` runs without prompting;
   pass `--interactive` to review each step.
3. **Dotfiles** — compares each bundled file with the deployed copy and the
   hash recorded in `~/.local/state/mist/deployed.tsv`:
   - new files are added
   - upstream changes are applied, with the old file saved as
     `*.pre-mist-<timestamp>`
   - files removed upstream are moved to a `.pre-mist-<timestamp>` backup
   - local edits are kept; if upstream also changed the file, the repo version
     is written next to it as `*.mist-new` for review
   - locally modified files removed upstream are kept
   - files deployed before the manifest existed have no deploy record, so the
     repo version wins with a `.pre-mist-<timestamp>` backup of the old file;
     pass `--keep-local` to keep them and review the `.mist-new` copies
     instead

   `--force` replaces files edited both locally and upstream (still backing
   them up), and `--check` (or `--dry-run`) only reports what would happen.
   Files generated from the wallpaper, such as `~/.config/ghostty/theme`,
   belong to the theme scripts: they are seeded when missing and never
   overwritten by an update.

`--no-pull` skips the remote step and updates from the current checkout, which
is useful when the repository is the source of truth for local changes. After a
dotfile update, reload the desktop (`hyprctl reload`, or log out and back in).

## Multiple users

The per-user half of the setup (dotfiles, shell, fonts, themes, Neovim,
OpenCode) can be applied to more than one account on the same machine. The
system half — packages, services, `/etc` files — still runs exactly once.

```sh
./install.sh                        # the invoking user (or SUDO_USER under sudo)
sudo ./install.sh --user alice      # one other account
sudo ./install.sh --all-users       # every human account (UID 1000-59999, shell)
```

`--all-users` and `--user` with a name other than your own need root, because
they write into other homes; a plain `sudo ./install.sh` keeps targeting
`SUDO_USER` rather than root. When it runs as root, the installer drops to the
target account for everything that generates files (Oh My Zsh, Powerlevel10k,
fonts, Neovim data, OpenCode, theme scripts) and `chown`s every deployed file,
so nothing in a home directory ends up root-owned. AUR packages are still
built as the invoking user, since `makepkg` refuses root.

Each account keeps its own deploy record at
`~/.local/state/mist/deployed.tsv` and its own theme/wallpaper state in
`~/.local/state/mist/`. Two users therefore never overwrite each other's local
edits or see each other's drift, and `--update --all-users` reports and applies
changes per account.

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
scripts/check-quickshell.sh  QML syntax check for the bundled Quickshell config
scripts/firefox-profile.py   Finds (or creates) the default Firefox profile
```

`scripts/check-quickshell.sh [path] [--run]` parses every `.qml` file with the
Qt6 `qmllint` and only fails on real syntax errors, which matters because the
`qs.*` imports have no `qmldir` and produce noise otherwise. `--run` also
starts the shell for a few seconds and fails on runtime QML errors. The
installer runs the parse check automatically after it deploys a changed
Quickshell tree (a warning, never a hard failure) so a broken config is caught
before it leaves someone without a bar.


Inside the deployed tree, `~/.config/quickshell/` carries the bar, panels and
services, `scripts/` (wallpaper analysis for Firefox and OpenChamber) and
`discord-bridge/` (optional plugin, its installer and the update auto-repair
units).

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
replaced. The hash of every deployed file is recorded in
`~/.local/state/mist/deployed.tsv`, which is what lets `--update` tell an
upstream change apart from a local edit.

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
- Wired and Wi-Fi devices come from NetworkManager at runtime, so the network
  panel reflects whatever hardware exists; it reports "no network backend" when
  Quickshell cannot reach NetworkManager.
- Power profiles come from `power-profiles-daemon`; machines or kernels without
  it show "power profiles unavailable" instead of a broken list.
- The Discord widget polls for the `Discord` process and starts
  `/usr/bin/discord`, so it works whether or not the bridge plugin is injected.

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
6. Start Firefox once; textfox is already installed, so the generated
   `chrome/config.css` applies at startup. Start Discord once; the bridge is
   patched automatically in the background. OpenChamber picks up the generated
   theme on its next start.

## Notes

- `quickshell` renders the wallpaper itself; `awww` is not installed.
- Themes are generated from the current wallpaper. `Wallpapers.qml` runs three
  scripts whenever the wallpaper changes, and `install.sh` runs the same ones
  after deploying dotfiles:
  - `~/.config/ghostty/sync-theme.py` writes the Ghostty palette
  - `~/.config/quickshell/scripts/sync-firefox-theme.py` writes the textfox
    `chrome/config.css` and a managed block in `user.js` of the default Firefox
    profile (visible on the next Firefox start)
  - `~/.config/quickshell/scripts/sync-openchamber-theme.py` writes
    `~/.config/openchamber/themes/openchamber-dark.json` (reloaded live)
- [textfox](https://github.com/adriankarlen/textfox) is cloned into
  `~/.local/share/textfox` and its chrome is copied into the default Firefox
  profile (a profile is created when Firefox has never run). The generated
  `chrome/config.css` supplies the palette and options. Use `--no-textfox` to
  skip it.
- The shell palette carries a fixed highlight (`#f72585`) for hover, selection
  and active states; everything else follows the wallpaper.
- The overflow menu's **Network** entry lists Wi-Fi networks and wired devices
  through NetworkManager: click to connect or disconnect, right-click a saved
  network to forget it, and type the password for a new secured network inline.
- The battery widget opens a power profile picker backed by
  `power-profiles-daemon`; it reports "unavailable" on hardware without it.
- The Discord widget can start, focus and kill the Discord app, and the bridge
  state is shown next to it. `--full` installs optional apps from
  `packages/apps.txt` and AUR packages from `packages/aur.txt`, then enables
  the cups printing stack and firewalld.
- OpenCode is installed by default; use `--no-opencode` to skip it.
- yay and pacseek are installed on every run; `--aur` only controls the optional
  AUR applications listed in `packages/aur.txt`.
- Firefox and Discord are installed even without `--apps` because the textfox
  theme and the DiscordBridge plugin are enabled by default. Their entries in
  `packages/apps.txt` remain part of the optional group.

### Discord bridge (client mod)

The Discord bar widget shows voice-call state through a small plugin that is
injected into the Discord desktop app. That is a client mod and may conflict
with Discord's Terms of Service. It is installed by default; skip it with:

```sh
./install.sh --no-discord-bridge
```

The Arch `discord` package only downloads the real app on first launch, so the
installer arms the `quickshell-discord-bridge.path` unit (`PathExistsGlob` on
`~/.config/discord/app-*`) and patches the app automatically when Discord first
starts. If Discord is already installed, the bridge is built and injected
immediately.

`dotfiles/.config/quickshell/discord-bridge/install.sh` clones and builds
Equicord, copies `plugin/` into it and injects the result into
`~/.config/discord`. It then installs the `quickshell-discord-bridge.path` and
`.service` user units, whose `auto-repair.sh` re-patches the app after every
Discord update and restarts it when no call is active. Logs go to
`~/.local/state/mist/discord-bridge.log`; re-run
`setup-auto-repair.sh` if the units are lost. Without the bridge, the widget
still starts and stops Discord and shows no call information.

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
