#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# When run through sudo for --all-users, git would reject a checkout owned by
# the invoking user. Mark this repo safe for this process only.
if ((EUID == 0)) && [[ -n "${SUDO_USER:-}" ]]; then
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0="safe.directory"
  export GIT_CONFIG_VALUE_0="$ROOT_DIR"
fi
DOTFILES_DIR="$ROOT_DIR/dotfiles"
PACKAGES_DIR="$ROOT_DIR/packages"
SYSTEM_DIR="$ROOT_DIR/system"

# Which accounts receive the per-user half of the setup (dotfiles, shell,
# fonts, themes, Neovim, OpenCode). The system half (packages, services,
# /etc files) always runs once, whoever the targets are.
#   default      the invoking user (or SUDO_USER under sudo)
#   --user NAME  that one account
#   --all-users  every human account on the machine (needs root)
USER_OPT=""
ALL_USERS=0
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || printf '0')"
TARGET_GID="$(id -g "$TARGET_USER" 2>/dev/null || printf '0')"
TARGET_USERS=()
# Unprivileged account used to build AUR packages; makepkg refuses root.
BUILD_USER="${SUDO_USER:-$USER}"

# Unattended by default: a plain ./install.sh never waits for input. Use
# --interactive to restore the confirmation prompts.
ASSUME_YES=1
DRY_RUN=0
NO_DOTFILES=0
INSTALL_APPS=0
INSTALL_AUR=0
INSTALL_NVIM=1
INSTALL_OPENCODE=1
INSTALL_NVIDIA=1
INSTALL_DISCORD_BRIDGE=1
INSTALL_TEXTFOX=1

# Keep sudo authenticated for the whole run so a long install cannot stop at a
# password prompt halfway through.
SUDO_KEEPALIVE_PID=""

UPDATE_MODE=0
CHECK_ONLY=0
NO_PULL=0
NO_PACKAGES=0
FORCE_DOTFILES=0
KEEP_LOCAL=0
SHOW_DIFF=0
ORIGINAL_ARGS=()

# Recomputed by set_target_user() for every account in TARGET_USERS, so each
# user keeps an independent deploy record.
MIST_STATE_DIR="$TARGET_HOME/.local/state/mist"
DEPLOY_MANIFEST="$MIST_STATE_DIR/deployed.tsv"

# Files generated at runtime from the wallpaper (see setup_theme). They are
# shipped as a starting point but are never treated as drift or overwritten as
# dotfiles; the theme scripts rewrite them after an update.
GENERATED_DOTFILES=(".config/ghostty/theme")

DOTFILES_CHANGED=0
SYSTEM_CONFIGS_CHANGED=0
GENERATED_MISSING=0
COLLECTED=()
PLAN_ADD=()
PLAN_UPDATE=()
PLAN_ADOPT=()
PLAN_LEGACY=()
PLAN_CONFLICT=()
PLAN_LOCAL=()
PLAN_REMOVE=()
PLAN_KEEP_REMOVED=()
PLAN_GENERATED=()
MISSING_REPO=()
MISSING_AUR=()
declare -A MANIFEST=()

# ---- ui ---------------------------------------------------------------
# Retro terminal look: neon pink and violet, block rules, bracketed status
# tags and double-line panels. A piped run drops the colour and the block
# wordmark so logs stay readable; NO_COLOR=1 or MIST_PLAIN=1 forces plain
# output even on a terminal.
UI_TTY=0
[[ -t 1 ]] && UI_TTY=1
UI_COLOR=0
if ((UI_TTY)) && [[ -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb && ${MIST_PLAIN:-0} != 1 ]]; then
  UI_COLOR=1
fi
UI_FANCY=0
if ((UI_TTY)) && [[ ${TERM:-dumb} != dumb && ${MIST_PLAIN:-0} != 1 ]]; then
  case "$(locale charmap 2>/dev/null || true)" in
    UTF-8|utf8|UTF8) UI_FANCY=1 ;;
  esac
fi

C_RESET=""
C_BOLD=""
C_PINK=""
C_PINK_HOT=""
C_MAGENTA=""
C_PURPLE=""
C_VIOLET=""
C_LAVENDER=""
C_DIM=""
C_GREEN=""
C_YELLOW=""
C_RED=""
C_CHIP=""
if ((UI_COLOR)); then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  if [[ ${COLORTERM:-} == *truecolor* || ${COLORTERM:-} == *24bit* ]]; then
    # mist palette: #f72585 highlight, violet and deep purple around it
    C_PINK=$'\033[38;2;247;37;133m'
    C_PINK_HOT=$'\033[38;2;255;77;157m'
    C_MAGENTA=$'\033[38;2;181;23;158m'
    C_PURPLE=$'\033[38;2;114;9;183m'
    C_VIOLET=$'\033[38;2;157;78;221m'
    C_LAVENDER=$'\033[38;2;224;170;255m'
    C_DIM=$'\033[38;2;141;123;168m'
    C_GREEN=$'\033[38;2;122;224;160m'
    C_YELLOW=$'\033[38;2;250;204;110m'
    C_RED=$'\033[38;2;255;92;138m'
    C_CHIP=$'\033[48;2;247;37;133m\033[38;2;12;10;20m'
  else
    C_PINK=$'\033[38;5;198m'
    C_PINK_HOT=$'\033[38;5;205m'
    C_MAGENTA=$'\033[38;5;162m'
    C_PURPLE=$'\033[38;5;92m'
    C_VIOLET=$'\033[38;5;135m'
    C_LAVENDER=$'\033[38;5;183m'
    C_DIM=$'\033[38;5;103m'
    C_GREEN=$'\033[38;5;114m'
    C_YELLOW=$'\033[38;5;221m'
    C_RED=$'\033[38;5;197m'
    C_CHIP=$'\033[48;5;198m\033[38;5;232m'
  fi
fi

# A step inside the current section.
log() {
  if ((UI_FANCY)); then
    printf '  %s▸%s %s\n' "$C_PINK" "$C_RESET" "$*"
  else
    printf '  - %s\n' "$*"
  fi
}
ok() { printf '  %s[ ok ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '  %s[warn]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
dry() { printf '  %s[dry ]%s %s\n' "$C_MAGENTA" "$C_RESET" "$*"; }
die() {
  printf '\n  %s[fail]%s %s\n\n' "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}

# Prefix for a command that would have run under --dry-run.
ui_dry() { printf '  %s[dry ]%s' "$C_MAGENTA" "$C_RESET"; }

# A dim block rule under a section heading.
ui_rule() {
  ((UI_FANCY)) || return 0
  local width=${1:-62} line
  printf -v line '%*s' "$width" ''
  printf '  %s%s%s\n' "$C_PURPLE" "${line// /─}" "$C_RESET"
}

UI_SECTION=0

# Numbered section heading, e.g. a filled pink "02 PACKAGES" chip.
ui_section() {
  UI_SECTION=$((UI_SECTION + 1))
  local label=$1 num
  printf -v num '%02d' "$UI_SECTION"
  if ((UI_FANCY)); then
    printf '\n  %s%s%s %s%s%s\n' "$C_CHIP" " $num " "$C_RESET" \
      "$C_BOLD$C_LAVENDER" "$label" "$C_RESET"
    ui_rule
  else
    printf '\n== %s %s ==\n' "$num" "$label"
  fi
}

# Double-line panel for the closing summary. Long lines wrap at 58 columns so
# the border stays inside an 80-column terminal.
ui_panel() {
  local title=$1
  shift
  local line
  if ! ((UI_FANCY)); then
    printf '\n%s\n' "$title"
    for line in "$@"; do
      if [[ -n "$line" ]]; then printf '  %s\n' "$line"; else printf '\n'; fi
    done
    return 0
  fi

  local -a lines=() part
  for line in "$@"; do
    while IFS= read -r part; do
      lines+=("$part")
    done < <(printf '%s\n' "$line" | fold -s -w 58)
  done

  local bar width=62
  printf -v bar '%*s' "$width" ''
  bar=${bar// /═}
  printf '\n  %s╔%s╗%s\n' "$C_PINK" "$bar" "$C_RESET"
  printf '  %s║%s %s%s%s%*s %s║%s\n' "$C_PINK" "$C_RESET" \
    "$C_BOLD$C_PINK_HOT" "$title" "$C_RESET" "$((width - 2 - ${#title}))" "" \
    "$C_PINK" "$C_RESET"
  printf '  %s╠%s╣%s\n' "$C_PINK" "$bar" "$C_RESET"
  for line in "${lines[@]}"; do
    printf '  %s║%s %-60s %s║%s\n' "$C_PINK" "$C_RESET" "$line" "$C_PINK" "$C_RESET"
  done
  printf '  %s╚%s╝%s\n' "$C_PINK" "$bar" "$C_RESET"
}

# Wordmark and build details, printed once at the start of a run.
ui_banner() {
  local mode=$1 host build who
  host="$(uname -n 2>/dev/null || true)"
  [[ -n "$host" ]] || host="${HOSTNAME:-arch}"
  build="local"
  if command -v git >/dev/null 2>&1 &&
    git -C "$ROOT_DIR" rev-parse --short HEAD >/dev/null 2>&1; then
    build="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null)"
    git -C "$ROOT_DIR" diff --quiet 2>/dev/null || build="${build}+"
  fi
  who="user $TARGET_USER"
  ((${#TARGET_USERS[@]} > 1)) && who="${#TARGET_USERS[@]} users"

  if ! ((UI_FANCY)); then
    printf '\n  %sMIST%s · arch linux · %s · %s\n\n' \
      "$C_BOLD$C_PINK" "$C_RESET" "$mode" "$who"
    return 0
  fi

  local -a art=(
    '███╗   ███╗██╗███████╗████████╗'
    '████╗ ████║██║██╔════╝╚══██╔══╝'
    '██╔████╔██║██║███████╗   ██║   '
    '██║╚██╔╝██║██║╚════██║   ██║   '
    '██║ ╚═╝ ██║██║███████║   ██║   '
    '╚═╝     ╚═╝╚═╝╚══════╝   ╚═╝   '
  )
  local -a shades=("$C_PINK_HOT" "$C_PINK" "$C_PINK" "$C_MAGENTA" "$C_MAGENTA" "$C_PURPLE")
  local i
  printf '\n'
  for i in "${!art[@]}"; do
    printf '  %s%s%s\n' "${shades[$i]}" "${art[$i]}" "$C_RESET"
  done
  printf '\n  %s%s%s  %s·%s  %sarch linux%s\n' \
    "$C_BOLD$C_LAVENDER" "MIST DESKTOP SETUP" "$C_RESET" \
    "$C_PINK" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '  %s%s  ·  %s  ·  %s  ·  build %s%s\n' \
    "$C_DIM" "$who" "$host" "$mode" "$build" "$C_RESET"
  ui_rule
}

usage() {
  cat <<'EOF'
Mist setup installer for a fresh Arch Linux install.

Usage:
  ./install.sh [options]
  ./install.sh --update [options]

Target accounts:
      --user NAME    Apply the per-user setup (dotfiles, shell, fonts, themes,
                     Neovim, OpenCode) to NAME instead of the invoking user
      --all-users    Apply it to every human account on the machine. Needs
                     root: sudo ./install.sh --all-users ...
                     Packages, services and /etc files are still installed once.

Options:
  -y, --yes          Accept defaults without prompting (already the default)
      --interactive  Ask before installing, updating or pulling
      --dry-run      Print actions without changing the system
      --update       Update an existing install: pull the new repo revision,
                     install missing packages, then update changed dotfiles
                     (locally modified files are kept and saved as .mist-new)
      --check        Report remote commits, package drift and dotfile drift
                     without changing anything (implies --update --dry-run)
      --no-pull      Do not fetch or pull from the git remote
      --no-packages  Do not install packages missing from the package lists
      --force        Replace dotfiles that were edited both locally and
                     upstream (they are backed up)
      --keep-local   Keep files with no deploy record instead of taking the
                     repo version (default: replace, previous copy backed up)
      --diff         Show unified diffs for the dotfiles an update changes
      --full         Also install optional apps and AUR packages
      --apps         Install the optional applications group
      --aur          Install AUR packages (implies --apps)
      --opencode     Install the OpenCode CLI into ~/.opencode (default)
      --nvidia       Install the NVIDIA open driver if NVIDIA is detected
                     (default)
      --textfox      Install textfox into the Firefox profile (default)
      --discord-bridge
                     Patch the Discord desktop app with the Quickshell
                     DiscordBridge plugin (client mod; see CREDITS.md)
                     (default)
      --no-apps      Skip optional applications
      --no-aur       Skip AUR packages
      --no-opencode  Skip the OpenCode CLI
      --no-nvidia    Skip the NVIDIA open driver when NVIDIA is detected
      --no-textfox   Skip the textfox Firefox theme
      --no-discord-bridge
                     Skip the DiscordBridge client mod
      --no-nvim      Skip Neovim plugin bootstrap
      --no-dotfiles  Only install packages and services
  -h, --help         Show this help

A plain run installs the full desktop stack (core, desktop and dev package
groups), the NVIDIA driver when detected, OpenCode, the textfox Firefox theme
and the DiscordBridge plugin, enables the services, and deploys the dotfiles
without asking anything. Optional apps and AUR packages stay behind --full.

The script is intended to run as a normal user with sudo access, after a fresh
Arch Linux install. It does not partition disks or install a bootloader.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
    -y | --yes) ASSUME_YES=1 ;;
    --interactive | --ask) ASSUME_YES=0 ;;
    --dry-run) DRY_RUN=1 ;;
    --user)
      shift
      (($#)) || die "--user needs an account name"
      USER_OPT="$1"
      ;;
    --user=*) USER_OPT="${1#--user=}" ;;
    --all-users) ALL_USERS=1 ;;
    --update) UPDATE_MODE=1 ;;
    --check)
      UPDATE_MODE=1
      CHECK_ONLY=1
      DRY_RUN=1
      ;;
    --no-pull) NO_PULL=1 ;;
    --no-packages) NO_PACKAGES=1 ;;
    --force) FORCE_DOTFILES=1 ;;
    --keep-local) KEEP_LOCAL=1 ;;
    --diff) SHOW_DIFF=1 ;;
    --full)
      INSTALL_APPS=1
      INSTALL_AUR=1
      INSTALL_OPENCODE=1
      ;;
    --apps) INSTALL_APPS=1 ;;
    --aur)
      INSTALL_APPS=1
      INSTALL_AUR=1
      ;;
    --opencode) INSTALL_OPENCODE=1 ;;
    --nvidia) INSTALL_NVIDIA=1 ;;
    --textfox) INSTALL_TEXTFOX=1 ;;
    --discord-bridge) INSTALL_DISCORD_BRIDGE=1 ;;
    --no-apps) INSTALL_APPS=0 ;;
    --no-aur) INSTALL_AUR=0 ;;
    --no-opencode) INSTALL_OPENCODE=0 ;;
    --no-nvidia) INSTALL_NVIDIA=0 ;;
    --no-textfox) INSTALL_TEXTFOX=0 ;;
    --no-discord-bridge) INSTALL_DISCORD_BRIDGE=0 ;;
    --no-nvim) INSTALL_NVIM=0 ;;
    --no-dotfiles) NO_DOTFILES=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1 (use --help)"
      ;;
    esac
    shift
  done
}

confirm() {
  ((ASSUME_YES)) && return 0
  local answer
  printf '  %s?%s %s %s[Y/n]%s ' "$C_PINK" "$C_RESET" "$1" "$C_DIM" "$C_RESET"
  read -r answer || return 1
  [[ -z "$answer" || "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

run() {
  if ((DRY_RUN)); then
    ui_dry
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

run_sudo() {
  if ((DRY_RUN)); then
    ui_dry
    printf ' sudo'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  if ((EUID == 0)); then
    "$@"
  else
    sudo "$@"
  fi
}

# A long install (Neovim/Mason alone can run for minutes) outlives sudo's
# default five-minute timestamp. Refresh it in the background after the first
# successful authentication, so the run never stops to ask again.
stop_sudo_keepalive() {
  [[ -n "$SUDO_KEEPALIVE_PID" ]] || return 0
  kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  SUDO_KEEPALIVE_PID=""
}

start_sudo_keepalive() {
  ((DRY_RUN)) && return 0
  ((EUID == 0)) && return 0
  if ! sudo -v; then
    die "sudo authentication failed. Run this as root, or configure passwordless sudo for an unattended install."
  fi
  local parent=$$
  (
    while kill -0 "$parent" 2>/dev/null; do
      sleep 50
      sudo -n true 2>/dev/null || exit 0
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
  trap stop_sudo_keepalive EXIT
}

# Wait for DNS/network instead of failing on the first pacman call after a
# fresh boot.
wait_for_network() {
  ((DRY_RUN)) && return 0
  command -v getent >/dev/null || return 0
  local remaining=60
  while ((remaining > 0)); do
    getent ahosts archlinux.org >/dev/null 2>&1 && return 0
    ((remaining % 10 == 0)) && log "Waiting for network access..."
    sleep 2
    remaining=$((remaining - 2))
  done
  warn "No network access detected; package downloads may fail"
}

# Tools the installer itself uses before the package lists are installed.
ensure_base_tools() {
  local -a missing=()
  command -v git >/dev/null || missing+=(git)
  command -v curl >/dev/null || missing+=(curl)
  ((${#missing[@]})) || return 0
  log "Installing installer prerequisites: ${missing[*]}"
  run_sudo pacman -S --needed --noconfirm "${missing[@]}"
}

# A stale keyring on an older install makes the first -Syu fail with invalid
# signatures. Refresh it once and retry before giving up.
update_package_databases() {
  run_sudo pacman -Syu --noconfirm && return 0
  warn "Package database update failed; refreshing the keyring and retrying"
  run_sudo pacman-key --init || warn "pacman-key --init failed"
  run_sudo pacman-key --populate archlinux || warn "pacman-key --populate failed"
  run_sudo pacman -Sy --noconfirm archlinux-keyring || warn "Could not refresh archlinux-keyring"
  run_sudo pacman -Syu --noconfirm ||
    die "Package database update failed again; check the network and mirror list"
}

read_packages() {
  local file="$1"
  [[ -f "$file" ]] || die "Missing package list: $file"
  local line
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | xargs)"
    [[ -n "$line" ]] && printf '%s\n' "$line"
  done <"$file"
}

install_packages() {
  local file="$1"
  local -a pkgs=()
  mapfile -t pkgs < <(read_packages "$file")
  ((${#pkgs[@]})) || return 0
  log "Installing packages from $(basename "$file")"
  run_sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

require_arch() {
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release"
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "arch" ]] || die "This installer targets Arch Linux (found: ${PRETTY_NAME:-unknown})"
  command -v pacman >/dev/null || die "pacman not found"
}

check_user() {
  if ((EUID == 0)); then
    # A root login has no SUDO_USER; installing sudo now means the per-user
    # helpers and this script can keep the same code path.
    if ! command -v sudo >/dev/null; then
      log "Installing sudo (required by the installer)"
      pacman -S --needed --noconfirm sudo
    fi
    # sudo keeps SUDO_USER, so a plain `sudo ./install.sh` still targets the
    # invoking account. A root login has no such hint and must name a target.
    if [[ -z "${SUDO_USER:-}" ]] && ((! ALL_USERS)) && [[ -z "$USER_OPT" ]]; then
      die "Running as root: pass --user NAME or --all-users"
    fi
    command -v runuser >/dev/null || die "runuser (util-linux) is required for --user/--all-users"
    return 0
  fi
  if ! command -v sudo >/dev/null; then
    die "sudo is required. Install it first: su -c 'pacman -S sudo'"
  fi
  if ((ALL_USERS)); then
    die "--all-users changes other users' homes; run it with sudo"
  fi
  if [[ -n "$USER_OPT" && "$USER_OPT" != "$USER" ]]; then
    die "--user $USER_OPT needs root: sudo ./install.sh --user $USER_OPT"
  fi
  [[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || die "Cannot determine home directory for $TARGET_USER"
  [[ "$TARGET_HOME" != "/" ]] || die "Refusing to deploy dotfiles to /"
}

user_home() { getent passwd "$1" | cut -d: -f6; }

# Human accounts that can log in and own a home directory. System accounts
# (UID below 1000), the nobody range and nologin shells are excluded.
human_users() {
  local name _ uid _ _ home shell
  while IFS=: read -r name _ uid _ _ home shell; do
    [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]] || continue
    ((uid >= 1000 && uid < 60000)) || continue
    [[ -n "$home" && -d "$home" ]] || continue
    case "$shell" in
    */nologin | */false) continue ;;
    esac
    printf '%s\n' "$name"
  done </etc/passwd
}

# Point every per-user global at one account. The manifest and state directory
# follow the home, so two users never share a deploy record.
set_target_user() {
  TARGET_USER="$1"
  TARGET_HOME="$(user_home "$TARGET_USER")"
  TARGET_UID="$(id -u "$TARGET_USER")"
  TARGET_GID="$(id -g "$TARGET_USER")"
  MIST_STATE_DIR="$TARGET_HOME/.local/state/mist"
  DEPLOY_MANIFEST="$MIST_STATE_DIR/deployed.tsv"
  MANIFEST=()
  COLLECTED=()
}

resolve_targets() {
  if ((ALL_USERS)); then
    mapfile -t TARGET_USERS < <(human_users)
    ((${#TARGET_USERS[@]})) || die "No human user accounts found"
  elif [[ -n "$USER_OPT" ]]; then
    getent passwd "$USER_OPT" >/dev/null || die "No such user: $USER_OPT"
    TARGET_USERS=("$USER_OPT")
  else
    getent passwd "$TARGET_USER" >/dev/null || die "Cannot resolve user $TARGET_USER"
    TARGET_USERS=("$TARGET_USER")
  fi
  set_target_user "${TARGET_USERS[0]}"
  [[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || die "Cannot determine home directory for $TARGET_USER"
  [[ "$TARGET_HOME" != "/" ]] || die "Refusing to deploy dotfiles to /"
}

# Run a command in the target account's environment. When the installer runs
# as root (--user/--all-users), it drops to the account so generated files
# (Neovim data, OpenCode, Oh My Zsh, themes) are never root-owned.
as_user() {
  if ((DRY_RUN)); then
    ui_dry
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  local -a env_args=(
    "HOME=$TARGET_HOME"
    "XDG_CONFIG_HOME=$TARGET_HOME/.config"
    "XDG_DATA_HOME=$TARGET_HOME/.local/share"
    "XDG_STATE_HOME=$TARGET_HOME/.local/state"
    "XDG_CACHE_HOME=$TARGET_HOME/.cache"
    "XDG_RUNTIME_DIR=/run/user/$TARGET_UID"
  )
  if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
    runuser -u "$TARGET_USER" -- env "${env_args[@]}" "$@"
  else
    env "${env_args[@]}" "$@"
  fi
}

# Run a package build as the unprivileged account when the installer itself is
# root, because makepkg/yay refuse to run as root.
run_build() {
  if ((DRY_RUN)); then
    ui_dry
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  if ((EUID == 0)); then
    [[ "$BUILD_USER" != "root" ]] ||
      die "Cannot build packages as root; run with sudo from a normal account"
    runuser -u "$BUILD_USER" -- "$@"
  else
    "$@"
  fi
}

# Give a deployed path back to its account when the installer runs as root.
own_path() {
  ((EUID == 0)) || return 0
  [[ -e "$1" || -L "$1" ]] || return 0
  chown -h "$TARGET_UID:$TARGET_GID" "$1"
}

# mkdir -p that hands ownership of every directory it creates to the target
# user, so the next non-root run can write there.
make_parent() {
  local dest="$1" dir
  dir="$(dirname "$dest")"
  local -a created=()
  while [[ ! -d "$dir" ]]; do
    created=("$dir" "${created[@]}")
    dir="$(dirname "$dir")"
  done
  mkdir -p "$(dirname "$dest")"
  local d
  for d in "${created[@]}"; do own_path "$d"; done
}

detect_cpu_package() {
  local vendor
  vendor="$(awk -F': ' '/vendor_id/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
  case "$vendor" in
  GenuineIntel) printf 'intel-ucode\n' ;;
  AuthenticAMD) printf 'amd-ucode\n' ;;
  esac
}

detect_gpu() {
  command -v lspci >/dev/null || return 1
  lspci 2>/dev/null | grep -Ei 'vga|3d|display' || true
}

install_gpu_packages() {
  local gpu
  gpu="$(detect_gpu || true)"
  local -a pkgs=(mesa)

  if grep -qi 'amd' <<<"$gpu"; then
    pkgs+=(vulkan-radeon libva-mesa-driver mesa-vdpau)
    log "Detected AMD graphics"
  elif grep -qi 'intel' <<<"$gpu"; then
    pkgs+=(vulkan-intel intel-media-driver)
    log "Detected Intel graphics"
  elif grep -qi 'nvidia' <<<"$gpu"; then
    if ((INSTALL_NVIDIA)); then
      log "Detected NVIDIA graphics"
      pkgs+=(nvidia-open nvidia-utils nvidia-settings linux-headers)
    else
      warn "Detected NVIDIA graphics; skipping the driver (--no-nvidia)"
    fi
  else
    warn "Could not detect a GPU; installing mesa only"
  fi

  local IFS=' '
  log "Installing graphics packages: ${pkgs[*]}"
  run_sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

install_microcode() {
  local pkg
  pkg="$(detect_cpu_package)"
  if [[ -n "$pkg" ]]; then
    log "Installing CPU microcode: $pkg"
    run_sudo pacman -S --needed --noconfirm "$pkg"
  else
    warn "Unknown CPU vendor; install intel-ucode or amd-ucode manually"
  fi
}

install_yay() {
  if command -v yay >/dev/null; then
    ok "yay already installed"
    return 0
  fi
  log "Installing yay-bin from the AUR"
  local tmp
  tmp="$(mktemp -d)"
  # makepkg and yay refuse to run as root. When the installer runs as root for
  # --all-users, build as the invoking user instead.
  if ((EUID == 0)) && [[ "$BUILD_USER" != "root" ]]; then
    chown "$BUILD_USER" "$tmp"
  fi
  run_build git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  if ((DRY_RUN)); then
    rm -rf "$tmp"
    return 0
  fi
  (
    cd "$tmp/yay-bin"
    # Build as the unprivileged user, then install as root. makepkg -si would
    # call sudo as the build user and could stop for a password mid-run.
    run_build makepkg --noconfirm
    run_sudo pacman -U --needed --noconfirm "$tmp"/yay-bin/*.pkg.tar.zst
  )
  rm -rf "$tmp"
}

install_pacseek() {
  if [[ -x "$TARGET_HOME/.local/bin/pacseek" || -x /usr/local/bin/pacseek ]]; then
    ok "pacseek already installed"
    return 0
  fi
  log "Installing pacseek into $TARGET_HOME/.local/bin"
  if ((DRY_RUN)); then
    dry "download and run the pacseek installer"
    return 0
  fi
  local pacseek_installer
  pacseek_installer="$(mktemp)"
  # Download first so the remote script is visible on disk and the transfer is
  # forced over HTTPS. It is still third-party code.
  if ! curl --proto '=https' --tlsv1.2 -fsSL --retry 3 -o "$pacseek_installer" \
    https://codeberg.org/m1stD3V/pacseek/raw/branch/main/get.sh; then
    rm -f "$pacseek_installer"
    warn "Failed to download the pacseek installer; skipping"
    return 0
  fi
  chmod 644 "$pacseek_installer"
  # User install: the launcher and ~/.zshrc both add ~/.local/bin to PATH.
  as_user sh "$pacseek_installer" || warn "pacseek install failed"
  rm -f "$pacseek_installer"
}

install_aur_packages() {
  ((INSTALL_AUR)) || return 0
  install_yay
  local -a pkgs=()
  mapfile -t pkgs < <(read_packages "$PACKAGES_DIR/aur.txt")
  ((${#pkgs[@]})) || return 0
  local IFS=' '
  log "Installing AUR packages: ${pkgs[*]}"
  run_build yay -S --needed --noconfirm --sudoloop "${pkgs[@]}"
}

install_omz() {
  if [[ -d "$TARGET_HOME/.oh-my-zsh" ]]; then
    ok "Oh My Zsh already installed"
    return 0
  fi
  log "Installing Oh My Zsh"
  if ((DRY_RUN)); then
    dry "install Oh My Zsh"
    return 0
  fi
  local omz_installer
  omz_installer="$(mktemp)"
  # Download first so the remote script is visible on disk and the transfer is
  # forced over HTTPS. It is still third-party code; review it if you care.
  if ! curl --proto '=https' --tlsv1.2 -fsSL --retry 3 -o "$omz_installer" \
    https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh; then
    rm -f "$omz_installer"
    die "Failed to download the Oh My Zsh installer"
  fi
  chmod 644 "$omz_installer"
  as_user env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$omz_installer"
  rm -f "$omz_installer"
}

install_p10k() {
  local theme_dir="$TARGET_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [[ -d "$theme_dir" ]]; then
    ok "Powerlevel10k already installed"
    return 0
  fi
  log "Installing Powerlevel10k"
  as_user git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
}

install_fonts() {
  local font_dir="$TARGET_HOME/.local/share/fonts"
  local -a url_names=("Regular" "Bold" "Italic" "Bold%20Italic")
  local -a file_names=("Regular" "Bold" "Italic" "Bold Italic")
  log "Installing MesloLGS NF fonts"
  if ((DRY_RUN)); then
    dry "download MesloLGS NF fonts into $font_dir"
    return 0
  fi
  make_parent "$font_dir/."
  local i
  for i in "${!url_names[@]}"; do
    as_user curl --proto '=https' --tlsv1.2 -fL --retry 3 -o "$font_dir/MesloLGS NF ${file_names[$i]}.ttf" \
      "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20${url_names[$i]}.ttf"
  done
}

refresh_font_cache() {
  command -v fc-cache >/dev/null || return 0
  log "Refreshing font cache"
  if ((DRY_RUN)); then
    dry "fc-cache -f"
    return 0
  fi
  # Target the deployed user's cache even if the script ran with a different
  # HOME; includes both MesloLGS NF and the bundled icons-in-terminal font.
  as_user fc-cache -f >/dev/null
}

# textfox supplies the Firefox chrome (userChrome.css, tabs, urlbar). Its own
# chrome/ directory is copied into the profile, while the generated config.css
# stays and is (re)written by sync-firefox-theme.py.
install_textfox() {
  ((INSTALL_TEXTFOX)) || return 0
  local src="$TARGET_HOME/.local/share/textfox" profile
  if ! command -v python3 >/dev/null; then
    warn "python3 not found; skipping textfox"
    return 0
  fi
  if ! command -v firefox >/dev/null; then
    warn "Firefox is not installed; skipping textfox"
    return 0
  fi
  if ((DRY_RUN)); then
    dry "clone textfox into $src and install it into the default Firefox profile"
    return 0
  fi

  make_parent "$src/."
  if [[ -d "$src/.git" ]]; then
    as_user git -C "$src" pull --ff-only --quiet ||
      warn "Could not update textfox; using the existing checkout"
  elif ! as_user git clone --depth=1 --quiet \
    https://github.com/adriankarlen/textfox.git "$src"; then
    warn "Failed to clone textfox; skipping the Firefox chrome"
    return 0
  fi

  if [[ ! -d "$src/chrome" ]]; then
    warn "textfox checkout has no chrome directory; skipping"
    return 0
  fi

  profile="$(as_user python3 "$ROOT_DIR/scripts/firefox-profile.py" --create || true)"
  if [[ -z "$profile" ]]; then
    warn "Could not locate a Firefox profile; skipping textfox"
    return 0
  fi

  as_user mkdir -p "$profile/chrome"
  # Keep a custom chrome/userChrome.css the first time textfox takes over;
  # later runs only refresh textfox's own files.
  local marker="$profile/chrome/.textfox"
  if [[ -f "$profile/chrome/userChrome.css" && ! -f "$marker" ]]; then
    local backup
    backup="$(backup_file "$profile/chrome/userChrome.css" "$(date +%Y%m%d-%H%M%S)")"
    printf '  %s[bak ]%s %s\n' "$C_VIOLET" "$C_RESET" "$backup"
  fi
  as_user cp -a "$src/chrome/." "$profile/chrome/"
  as_user touch "$marker"
  ok "textfox installed into $profile/chrome"

  # On an existing install the dotfiles may not change, so setup_theme does not
  # run; seed the palette here if textfox is being added for the first time.
  local theme_script="$TARGET_HOME/.config/quickshell/scripts/sync-firefox-theme.py"
  if [[ ! -f "$profile/chrome/config.css" && -f "$theme_script" ]]; then
    as_user python3 "$theme_script" || warn "Could not generate the Firefox palette"
  fi
}

# Applications that the automatic extras need even when the optional app group
# is not selected. pacman --needed makes this a no-op for --full installs.
install_feature_packages() {
  local -a pkgs=()
  ((INSTALL_TEXTFOX)) && pkgs+=(firefox)
  ((INSTALL_DISCORD_BRIDGE)) && pkgs+=(discord)
  ((${#pkgs[@]})) || return 0
  local IFS=' '
  log "Installing packages required by the enabled features: ${pkgs[*]}"
  run_sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

hash_file() {
  sha256sum "$1" | cut -d' ' -f1
}

# The manifest records the hash of every file as it was deployed, so an update
# can tell an upstream change apart from a local edit made after the last run.
load_manifest() {
  MANIFEST=()
  if [[ ! -f "$DEPLOY_MANIFEST" ]]; then
    return 0
  fi
  local hash rel
  while IFS=$'\t' read -r hash rel; do
    [[ -n "$rel" && -n "$hash" ]] && MANIFEST["$rel"]="$hash"
  done <"$DEPLOY_MANIFEST"
}

save_manifest() {
  ((DRY_RUN)) && return 0
  make_parent "$MIST_STATE_DIR/."
  local rel
  {
    for rel in "${!MANIFEST[@]}"; do
      printf '%s\t%s\n' "${MANIFEST[$rel]}" "$rel"
    done | sort -k2
  } >"$DEPLOY_MANIFEST.tmp"
  mv "$DEPLOY_MANIFEST.tmp" "$DEPLOY_MANIFEST"
  own_path "$DEPLOY_MANIFEST"
}

# True when the deployed file matches a revision this repo shipped before, which
# means it is a stale deploy rather than a local edit. Used to bootstrap the
# manifest on machines installed before it existed.
deployed_matches_history() {
  local rel="$1" dep_hash="$2" commit blob_hash
  [[ -d "$ROOT_DIR/.git" ]] || return 1
  while IFS= read -r commit; do
    [[ -n "$commit" ]] || continue
    # The path may be absent at a commit that touched it (a deletion, or a
    # rename on another branch); skip those instead of failing.
    git -C "$ROOT_DIR" cat-file -e "$commit:dotfiles/$rel" 2>/dev/null || continue
    blob_hash="$(git -C "$ROOT_DIR" cat-file -p "$commit:dotfiles/$rel" |
      sha256sum | cut -d' ' -f1)"
    [[ "$blob_hash" == "$dep_hash" ]] && return 0
  done < <(git -C "$ROOT_DIR" log --all --pretty=format:%H -- "dotfiles/$rel" 2>/dev/null)
  return 1
}

is_generated_dotfile() {
  local rel="$1" generated
  for generated in "${GENERATED_DOTFILES[@]}"; do
    [[ "$rel" == "$generated" ]] && return 0
  done
  return 1
}

collect_dotfiles() {
  local src rel
  COLLECTED=()
  while IFS= read -r -d '' src; do
    rel="${src#"$DOTFILES_DIR"/}"
    case "$rel" in
    */__pycache__/* | *.pyc | *.pyo | *.swp | *.swo | *~ | .DS_Store) continue ;;
    esac
    COLLECTED+=("$rel")
  done < <(find "$DOTFILES_DIR" -type f -print0 | sort -z)
}

# Fill the PLAN_* arrays by comparing three states per file: the repo copy, the
# deployed copy and the hash recorded at the last deploy.
plan_dotfiles() {
  PLAN_ADD=()
  PLAN_UPDATE=()
  PLAN_ADOPT=()
  PLAN_LEGACY=()
  PLAN_CONFLICT=()
  PLAN_LOCAL=()
  PLAN_REMOVE=()
  PLAN_KEEP_REMOVED=()
  PLAN_GENERATED=()
  GENERATED_MISSING=0

  load_manifest
  local -A seen=()
  local rel dest repo_hash dep_hash base_hash
  for rel in "${COLLECTED[@]}"; do
    seen["$rel"]=1
    dest="$TARGET_HOME/$rel"
    if is_generated_dotfile "$rel"; then
      PLAN_GENERATED+=("$rel")
      [[ -e "$dest" ]] || GENERATED_MISSING=1
      continue
    fi
    repo_hash="$(hash_file "$DOTFILES_DIR/$rel")"
    if [[ ! -e "$dest" ]]; then
      PLAN_ADD+=("$rel")
      continue
    fi
    dep_hash="$(hash_file "$dest")"
    if [[ "$dep_hash" == "$repo_hash" ]]; then
      PLAN_ADOPT+=("$rel")
      MANIFEST["$rel"]="$repo_hash"
      continue
    fi
    base_hash="${MANIFEST[$rel]:-}"
    if [[ -z "$base_hash" ]]; then
      # No manifest entry: this is either a stale deploy from an older revision
      # or a local edit. History tells them apart; anything else converges to
      # the repo version with a backup (see PLAN_LEGACY).
      if deployed_matches_history "$rel" "$dep_hash"; then
        PLAN_UPDATE+=("$rel")
      else
        PLAN_LEGACY+=("$rel")
      fi
    elif [[ "$dep_hash" == "$base_hash" ]]; then
      PLAN_UPDATE+=("$rel")
    elif [[ "$repo_hash" == "$base_hash" ]]; then
      PLAN_LOCAL+=("$rel")
    else
      PLAN_CONFLICT+=("$rel")
    fi
  done

  for rel in "${!MANIFEST[@]}"; do
    [[ -n "${seen[$rel]:-}" ]] && continue
    dest="$TARGET_HOME/$rel"
    [[ -e "$dest" ]] || continue
    if [[ "$(hash_file "$dest")" == "${MANIFEST[$rel]}" ]]; then
      PLAN_REMOVE+=("$rel")
    else
      PLAN_KEEP_REMOVED+=("$rel")
    fi
  done
}

show_diff() {
  local rel="$1"
  local src="$DOTFILES_DIR/$rel" dest="$TARGET_HOME/$rel"
  ((SHOW_DIFF)) || return 0
  [[ -f "$dest" ]] || return 0
  if ! command -v diff >/dev/null; then
    warn "diff is not installed; cannot show changes for ~/$rel"
    return 0
  fi
  diff -u --label "deployed/$rel" --label "repo/$rel" "$dest" "$src" || true
}

report_dotfile_plan() {
  local rel total
  total=$((${#PLAN_ADD[@]} + ${#PLAN_UPDATE[@]} + ${#PLAN_LEGACY[@]} + \
    ${#PLAN_CONFLICT[@]} + ${#PLAN_LOCAL[@]} + ${#PLAN_REMOVE[@]} + \
    ${#PLAN_KEEP_REMOVED[@]}))
  if ((total == 0)); then
    ok "Dotfiles already up to date"
    return 0
  fi

  log "Dotfile changes for $TARGET_HOME"
  for rel in "${PLAN_ADD[@]}"; do
    printf '  %s[ add ]%s ~/%s\n' "$C_GREEN" "$C_RESET" "$rel"
  done
  for rel in "${PLAN_UPDATE[@]}"; do
    printf '  %s[ mod ]%s ~/%s\n' "$C_VIOLET" "$C_RESET" "$rel"
    show_diff "$rel"
  done
  for rel in "${PLAN_REMOVE[@]}"; do
    printf '  %s[ del ]%s ~/%s\n' "$C_YELLOW" "$C_RESET" "$rel"
  done
  for rel in "${PLAN_LEGACY[@]}"; do
    if ((KEEP_LOCAL)); then
      printf '  %s[keep ]%s ~/%s (kept; repo copy saved as ~/%s.mist-new)\n' \
        "$C_YELLOW" "$C_RESET" "$rel" "$rel"
    else
      printf '  %s[ mod ]%s ~/%s (no deploy record; previous copy backed up)\n' \
        "$C_VIOLET" "$C_RESET" "$rel"
    fi
    show_diff "$rel"
  done
  for rel in "${PLAN_CONFLICT[@]}"; do
    if ((FORCE_DOTFILES)); then
      printf '  %s[force]%s ~/%s (locally modified)\n' "$C_YELLOW" "$C_RESET" "$rel"
    else
      printf '  %s[conf ]%s ~/%s (kept; repo copy saved as ~/%s.mist-new)\n' \
        "$C_YELLOW" "$C_RESET" "$rel" "$rel"
    fi
    show_diff "$rel"
  done
  for rel in "${PLAN_LOCAL[@]}"; do
    printf '  %s[local]%s ~/%s (kept; unchanged upstream)\n' \
      "$C_GREEN" "$C_RESET" "$rel"
  done
  for rel in "${PLAN_KEEP_REMOVED[@]}"; do
    printf '  %s[local]%s ~/%s (kept; removed upstream but modified here)\n' \
      "$C_GREEN" "$C_RESET" "$rel"
  done
  for rel in "${PLAN_GENERATED[@]}"; do
    [[ -e "$TARGET_HOME/$rel" ]] && continue
    printf '  %s[seed ]%s ~/%s (generated from the wallpaper)\n' \
      "$C_VIOLET" "$C_RESET" "$rel"
  done
}

# Copy a repo file into a user's home and hand it to that user. Used for every
# dotfile write so --user/--all-users can run as root without leaving
# root-owned files behind.
deploy_copy() {
  local src="$1" dest="$2"
  make_parent "$dest"
  cp -a "$src" "$dest"
  own_path "$dest"
}

backup_file() {
  local dest="$1" stamp="$2" backup="$1.pre-mist-$2" n=1
  while [[ -e "$backup" ]]; do
    backup="$dest.pre-mist-$stamp.$n"
    n=$((n + 1))
  done
  cp -a "$dest" "$backup"
  own_path "$backup"
  printf '%s\n' "$backup"
}

apply_dotfile_plan() {
  local stamp rel src dest backup
  stamp="$(date +%Y%m%d-%H%M%S)"
  local added=0 updated=0 replaced=0 removed=0 kept_legacy=0 kept_conflicts=0

  for rel in "${PLAN_ADD[@]}"; do
    src="$DOTFILES_DIR/$rel"
    dest="$TARGET_HOME/$rel"
    deploy_copy "$src" "$dest"
    rm -f "$dest.mist-new"
    MANIFEST["$rel"]="$(hash_file "$src")"
    added=$((added + 1))
  done

  for rel in "${PLAN_UPDATE[@]}"; do
    src="$DOTFILES_DIR/$rel"
    dest="$TARGET_HOME/$rel"
    backup="$(backup_file "$dest" "$stamp")"
    deploy_copy "$src" "$dest"
    rm -f "$dest.mist-new"
    MANIFEST["$rel"]="$(hash_file "$src")"
    updated=$((updated + 1))
    printf '  %s[bak ]%s %s\n' "$C_VIOLET" "$C_RESET" "$backup"
  done

  for rel in "${PLAN_LEGACY[@]}"; do
    src="$DOTFILES_DIR/$rel"
    dest="$TARGET_HOME/$rel"
    if ((KEEP_LOCAL)); then
      deploy_copy "$src" "$dest.mist-new"
      kept_legacy=$((kept_legacy + 1))
    else
      backup="$(backup_file "$dest" "$stamp")"
      deploy_copy "$src" "$dest"
      rm -f "$dest.mist-new"
      MANIFEST["$rel"]="$(hash_file "$src")"
      updated=$((updated + 1))
      printf '  %s[bak ]%s %s\n' "$C_VIOLET" "$C_RESET" "$backup"
    fi
  done

  for rel in "${PLAN_CONFLICT[@]}"; do
    src="$DOTFILES_DIR/$rel"
    dest="$TARGET_HOME/$rel"
    if ((FORCE_DOTFILES)); then
      backup="$(backup_file "$dest" "$stamp")"
      deploy_copy "$src" "$dest"
      rm -f "$dest.mist-new"
      MANIFEST["$rel"]="$(hash_file "$src")"
      replaced=$((replaced + 1))
      printf '  %s[bak ]%s %s\n' "$C_VIOLET" "$C_RESET" "$backup"
    else
      deploy_copy "$src" "$dest.mist-new"
      kept_conflicts=$((kept_conflicts + 1))
    fi
  done

  for rel in "${PLAN_REMOVE[@]}"; do
    dest="$TARGET_HOME/$rel"
    backup="$(backup_file "$dest" "$stamp")"
    rm -f "$dest"
    unset 'MANIFEST[$rel]'
    removed=$((removed + 1))
    printf '  %s[bak ]%s %s\n' "$C_VIOLET" "$C_RESET" "$backup"
  done

  # Seed a missing generated file so the app that reads it works even before
  # the theme scripts run. It is not recorded in the manifest.
  for rel in "${PLAN_GENERATED[@]}"; do
    dest="$TARGET_HOME/$rel"
    [[ -e "$dest" ]] && continue
    deploy_copy "$DOTFILES_DIR/$rel" "$dest"
    printf '  %s[seed ]%s ~/%s\n' "$C_VIOLET" "$C_RESET" "$rel"
  done

  ok "Dotfiles: $added added, $updated updated, $replaced forced, $removed removed"
  if ((kept_legacy > 0)); then
    warn "$kept_legacy file(s) with no deploy record kept (--keep-local); rerun without it to replace them"
  fi
  if ((kept_conflicts > 0 && ! FORCE_DOTFILES)); then
    warn "$kept_conflicts file(s) edited both locally and upstream kept; review the .mist-new copies or rerun with --force"
  fi
}

deploy_dotfiles() {
  ((NO_DOTFILES)) && {
    warn "Skipping dotfiles"
    return 0
  }
  collect_dotfiles
  plan_dotfiles
  local total=$((${#PLAN_ADD[@]} + ${#PLAN_UPDATE[@]} + ${#PLAN_LEGACY[@]} + \
    ${#PLAN_CONFLICT[@]} + ${#PLAN_REMOVE[@]} + GENERATED_MISSING))
  if ((total > 0)); then
    DOTFILES_CHANGED=1
  fi
  if ((DRY_RUN)); then
    log "Checking dotfiles in $TARGET_HOME (dry run)"
    report_dotfile_plan
    return 0
  fi
  report_dotfile_plan
  if ((total > 0)); then
    apply_dotfile_plan
  fi
  # Also records files that already matched, so later local edits are visible to
  # the next update even when this run changed nothing.
  save_manifest
}

set_shell() {
  local current
  current="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
  if [[ "$current" == "/usr/bin/zsh" ]]; then
    ok "Login shell is already zsh"
    return 0
  fi
  log "Setting login shell to zsh"
  run_sudo chsh -s /usr/bin/zsh "$TARGET_USER"
}

install_system_configs() {
  local src="$SYSTEM_DIR/zram-generator.conf"
  local dest=/etc/systemd/zram-generator.conf
  [[ -f "$src" ]] || return 0
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    ok "zram-generator configuration is up to date"
    return 0
  fi
  log "Installing zram-generator configuration"
  run_sudo install -Dm644 "$src" "$dest"
  SYSTEM_CONFIGS_CHANGED=1
}

enable_services() {
  log "Enabling core services"
  run_sudo systemctl enable --now NetworkManager ||
    warn "NetworkManager could not be started; check it after reboot"
  run_sudo systemctl enable --now bluetooth ||
    warn "bluetooth could not be started; the widget will report it as unavailable"
  run_sudo systemctl enable --now fstrim.timer ||
    warn "fstrim.timer could not be enabled"
  # the bar's power widget reads and switches profiles through this daemon
  run_sudo systemctl enable --now power-profiles-daemon.service ||
    warn "power-profiles-daemon could not be started; the widget will report it as unavailable"
}

enable_app_services() {
  ((INSTALL_APPS)) || return 0
  log "Enabling optional application services"
  # Printing stack from packages/apps.txt
  run_sudo systemctl enable --now cups.socket || warn "cups.socket could not be started"
  run_sudo systemctl enable --now cups.path || warn "cups.path could not be started"
  run_sudo systemctl enable --now firewalld || warn "firewalld could not be started"
}

setup_theme() {
  local state_dir="$TARGET_HOME/.local/state/mist"
  local wallpaper=""
  local -a theme_scripts=(
    "$TARGET_HOME/.config/ghostty/sync-theme.py"
    "$TARGET_HOME/.config/quickshell/scripts/sync-firefox-theme.py"
    "$TARGET_HOME/.config/quickshell/scripts/sync-openchamber-theme.py"
  )

  if ((DRY_RUN)); then
    dry "initialize wallpaper state and per-app themes"
    return 0
  fi

  make_parent "$state_dir/."
  wallpaper="$(find "$TARGET_HOME/.config/wallpaper" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' \) |
    sort | head -n1 || true)"

  if [[ -n "$wallpaper" ]]; then
    printf '%s\n' "$wallpaper" >"$state_dir/wallpaper"
    own_path "$state_dir/wallpaper"
  fi

  if ! command -v python3 >/dev/null; then
    warn "python3 not found; skipping theme generation"
    return 0
  fi

  # Same wallpaper state feeds the Ghostty, Firefox and OpenChamber themes, so
  # the shell, terminal, browser and editor start on one palette.
  local script
  for script in "${theme_scripts[@]}"; do
    [[ -f "$script" ]] || continue
    as_user python3 "$script" || warn "Failed to generate $(basename "$script") output"
  done
}

install_opencode() {
  ((INSTALL_OPENCODE)) || return 0
  if [[ -x "$TARGET_HOME/.opencode/bin/opencode" ]] || command -v opencode >/dev/null; then
    ok "OpenCode already installed"
    return 0
  fi
  log "Installing OpenCode CLI"
  if ((DRY_RUN)); then
    dry "install OpenCode into $TARGET_HOME/.opencode"
    return 0
  fi
  local oc_installer
  oc_installer="$(mktemp)"
  # Download first so the remote script is visible on disk and the transfer is
  # forced over HTTPS. It is still third-party code.
  if curl --proto '=https' --tlsv1.2 -fsSL --retry 3 -o "$oc_installer" https://opencode.ai/install; then
    chmod 644 "$oc_installer"
    # ~/.zshrc already exports ~/.opencode/bin; letting the installer edit the
    # shell config would turn the deployed dotfile into local drift.
    as_user bash "$oc_installer" --no-modify-path || warn "OpenCode install failed"
  else
    warn "OpenCode download failed"
  fi
  rm -f "$oc_installer"
}

# True when at least one installed Discord version carries the bridge patch.
discord_bridge_patched() {
  local dir
  for dir in "$TARGET_HOME"/.config/discord/app-*; do
    [[ -f "$dir/resources/_app.asar" ]] && return 0
  done
  return 1
}

install_discord_bridge() {
  ((INSTALL_DISCORD_BRIDGE)) || return 0
  local bridge_dir="$TARGET_HOME/.config/quickshell/discord-bridge"
  local bridge_script="$bridge_dir/install.sh"
  if [[ ! -f "$bridge_script" ]]; then
    warn "DiscordBridge installer missing; rerun without --no-dotfiles"
    return 0
  fi
  if ! command -v node >/dev/null; then
    warn "node is required to build the DiscordBridge plugin; skipping"
    return 0
  fi
  if ! command -v discord >/dev/null && [[ ! -d "$TARGET_HOME/.config/discord" ]]; then
    warn "Discord is not installed; skipping the DiscordBridge"
    return 0
  fi
  if ((DRY_RUN)); then
    dry "build and inject the DiscordBridge plugin with $bridge_script"
    return 0
  fi

  # The Arch discord package is only a bootstrap: it downloads the real app
  # into ~/.config/discord on first launch. Until that happens there is nothing
  # to patch, so arm the path unit now and let it patch the app automatically
  # when the first app-* directory appears.
  if [[ ! -d "$TARGET_HOME/.config/discord" ]] ||
    ! compgen -G "$TARGET_HOME/.config/discord/app-*" >/dev/null; then
    log "Discord is not initialized yet; arming the DiscordBridge auto-repair"
    as_user bash "$bridge_dir/setup-auto-repair.sh" ||
      warn "Could not enable the DiscordBridge auto-repair units"
    warn "Start Discord once; the bridge is patched automatically on first launch"
    return 0
  fi

  log "Patching Discord with the Quickshell DiscordBridge plugin (client mod)"
  as_user bash "$bridge_script" || warn "DiscordBridge install failed; see its output above"
}

bootstrap_nvim() {
  ((INSTALL_NVIM)) || {
    warn "Skipping Neovim bootstrap"
    return 0
  }
  command -v nvim >/dev/null || {
    warn "Neovim is not installed; skipping bootstrap"
    return 0
  }
  command -v tree-sitter >/dev/null || {
    warn "tree-sitter CLI is missing; Neovim cannot build Treesitter parsers"
  }
  log "Bootstrapping Neovim plugins"
  if ((DRY_RUN)); then
    dry "nvim --headless '+Lazy! sync' +qa"
    dry "install Mason LSP servers and tools"
    return 0
  fi

  as_user nvim --headless "+Lazy! sync" +qa || warn "Neovim plugin sync failed"
  as_user nvim --headless \
    -c "luafile $ROOT_DIR/scripts/nvim-mason.lua" -c qa || warn "Mason bootstrap failed"
}

missing_packages_from() {
  local file="$1"
  local -a pkgs=()
  mapfile -t pkgs < <(read_packages "$file")
  ((${#pkgs[@]})) || return 0
  # -T reports packages that do not satisfy an installed dependency, so it
  # honours provides such as linux-cachyos for linux.
  pacman -T "${pkgs[@]}" 2>/dev/null || true
}

collect_package_drift() {
  MISSING_REPO=()
  MISSING_AUR=()
  local file p
  for file in core desktop dev; do
    mapfile -t -O "${#MISSING_REPO[@]}" MISSING_REPO \
      < <(missing_packages_from "$PACKAGES_DIR/$file.txt")
  done
  if ((INSTALL_APPS)); then
    mapfile -t -O "${#MISSING_REPO[@]}" MISSING_REPO \
      < <(missing_packages_from "$PACKAGES_DIR/apps.txt")
  fi
  if ((INSTALL_AUR)); then
    mapfile -t MISSING_AUR < <(missing_packages_from "$PACKAGES_DIR/aur.txt")
  fi

  local -A seen=()
  local -a repo=() aur=()
  for p in "${MISSING_REPO[@]}"; do
    [[ -n "$p" && -z "${seen[$p]:-}" ]] || continue
    seen["$p"]=1
    repo+=("$p")
  done
  seen=()
  for p in "${MISSING_AUR[@]}"; do
    [[ -n "$p" && -z "${seen[$p]:-}" ]] || continue
    seen["$p"]=1
    aur+=("$p")
  done
  MISSING_REPO=("${repo[@]}")
  MISSING_AUR=("${aur[@]}")
}

report_package_drift() {
  if ((${#MISSING_REPO[@]} + ${#MISSING_AUR[@]} == 0)); then
    ok "All packages from the lists are installed"
    return 0
  fi
  log "Packages in the lists that are missing here"
  local p
  for p in "${MISSING_REPO[@]}"; do
    printf '  %s[miss ]%s %s\n' "$C_YELLOW" "$C_RESET" "$p"
  done
  for p in "${MISSING_AUR[@]}"; do
    printf '  %s[miss ]%s %s (AUR)\n' "$C_YELLOW" "$C_RESET" "$p"
  done
}

install_missing_packages() {
  ((${#MISSING_REPO[@]} + ${#MISSING_AUR[@]})) || return 0
  if ((NO_PACKAGES)); then
    warn "Skipping missing packages (--no-packages)"
    return 0
  fi
  if ((DRY_RUN)); then
    dry "install the missing packages listed above"
    return 0
  fi
  if ! confirm "Install these packages now?"; then
    warn "Skipping packages"
    return 0
  fi
  if ((${#MISSING_REPO[@]})); then
    log "Installing missing packages"
    run_sudo pacman -S --needed --noconfirm "${MISSING_REPO[@]}" ||
      warn "Some packages failed; run pacman -Syu and retry the update"
  fi
  if ((${#MISSING_AUR[@]})); then
    install_yay
    log "Installing missing AUR packages: ${MISSING_AUR[*]}"
    run_build yay -S --needed --noconfirm --sudoloop "${MISSING_AUR[@]}" ||
      warn "Some AUR packages failed to install"
  fi
}

sync_remote() {
  if ((NO_PULL)); then
    warn "Skipping remote check (--no-pull)"
    return 0
  fi
  if [[ ! -d "$ROOT_DIR/.git" ]]; then
    warn "Not a git checkout; skipping remote check"
    return 0
  fi
  if ! command -v git >/dev/null; then
    warn "git not found; skipping remote check"
    return 0
  fi
  if ! git -C "$ROOT_DIR" remote get-url origin >/dev/null 2>&1; then
    warn "No origin remote; skipping remote check"
    return 0
  fi

  local branch upstream behind ahead head_before
  branch="$(git -C "$ROOT_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    warn "Detached HEAD; skipping remote check"
    return 0
  fi

  log "Fetching origin/$branch"
  if ! git -C "$ROOT_DIR" fetch --quiet --prune origin; then
    warn "git fetch failed (offline?); updating from the local checkout"
    return 0
  fi

  upstream="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  [[ -n "$upstream" ]] || upstream="origin/$branch"
  if ! git -C "$ROOT_DIR" rev-parse --verify --quiet "$upstream" >/dev/null; then
    warn "No remote branch $upstream; skipping remote check"
    return 0
  fi

  behind="$(git -C "$ROOT_DIR" rev-list --count "HEAD..$upstream")"
  ahead="$(git -C "$ROOT_DIR" rev-list --count "$upstream..HEAD")"
  if ((behind == 0)); then
    ok "Already up to date with $upstream"
    ((ahead > 0)) && warn "$ahead local commit(s) not pushed to $upstream"
    return 0
  fi

  log "$behind new commit(s) on $upstream:"
  git -C "$ROOT_DIR" --no-pager log --oneline --no-decorate "HEAD..$upstream" || true
  git -C "$ROOT_DIR" --no-pager diff --stat "HEAD..$upstream" || true

  if [[ -n "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=no)" ]]; then
    warn "The checkout has uncommitted changes; commit or stash them before updating"
    return 0
  fi
  if ((DRY_RUN)); then
    dry "git pull --ff-only (would apply $behind commit(s))"
    return 0
  fi
  if ! confirm "Pull these changes from $upstream?"; then
    warn "Skipping pull; updating from the local checkout"
    return 0
  fi

  head_before="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  if ! git -C "$ROOT_DIR" pull --ff-only --quiet origin "$branch"; then
    warn "Could not fast-forward to $upstream; resolve the branch manually and rerun"
    return 0
  fi
  ok "Updated to $(git -C "$ROOT_DIR" rev-parse --short HEAD)"

  if git -C "$ROOT_DIR" diff --name-only "$head_before" HEAD | grep -qx 'install.sh' &&
    [[ "${MIST_UPDATE_REEXEC:-0}" != "1" ]]; then
    log "The installer itself changed; restarting with the new version"
    export MIST_UPDATE_REEXEC=1
    exec bash "$ROOT_DIR/install.sh" "${ORIGINAL_ARGS[@]}"
  fi
}

plan_touched() {
  local prefix="$1" rel
  for rel in "${PLAN_ADD[@]}" "${PLAN_UPDATE[@]}" "${PLAN_LEGACY[@]}" \
    "${PLAN_CONFLICT[@]}" "${PLAN_REMOVE[@]}"; do
    [[ "$rel" == "$prefix"* ]] && return 0
  done
  return 1
}

summary_update() {
  local -a lines=()
  if ((CHECK_ONLY)); then
    ui_panel "CHECK COMPLETE" \
      "Nothing was changed." \
      "Run ./install.sh --update to apply."
    printf '\n'
    return 0
  fi
  if ((DRY_RUN)); then
    ui_panel "DRY RUN COMPLETE" \
      "Nothing was changed." \
      "Run ./install.sh --update to apply."
    printf '\n'
    return 0
  fi
  if ((DOTFILES_CHANGED)); then
    lines+=(
      "Reload the desktop to pick up the new configuration:"
      "  - Hyprland: hyprctl reload"
      "  - Quickshell: log out and back in"
      "  - Ghostty: open a new window"
      ""
    )
    if ((KEEP_LOCAL)); then
      lines+=("Files with no deploy record were kept; repo versions are in *.mist-new.")
    else
      lines+=("Files replaced without a deploy record have a .pre-mist-<timestamp> backup.")
    fi
    lines+=("Files edited both locally and upstream keep a *.mist-new copy; rerun with --force to replace them.")
  else
    lines+=("No dotfile changes were needed.")
  fi
  if ((SYSTEM_CONFIGS_CHANGED)); then
    lines+=("zram configuration changed; reboot for it to take effect.")
  fi
  if ((! NO_PACKAGES)); then
    lines+=("The system was upgraded; reboot if the kernel or graphics driver changed.")
  fi
  ui_panel "UPDATE COMPLETE" "${lines[@]}"
  printf '\n'
}

# Parse-check the deployed Quickshell config. A broken QML file leaves the user
# with no bar and no obvious reason, so say so loudly instead of installing it
# silently. A warning, not a failure: one bad file must not abort an otherwise
# successful update halfway through.
check_quickshell() {
  local script="$ROOT_DIR/scripts/check-quickshell.sh"
  local target="$TARGET_HOME/.config/quickshell"
  ((DRY_RUN)) && return 0
  [[ -f "$script" && -d "$target" ]] || return 0
  local output
  if output="$(bash "$script" "$target" 2>&1)"; then
    ok "Quickshell configuration parses"
  elif grep -q 'no Qt6 qmllint found' <<<"$output"; then
    warn "Qt6 qmllint not installed; skipping the Quickshell syntax check"
  else
    warn "Quickshell configuration has QML syntax errors:"
    printf '%s\n' "$output" >&2
    warn "The bar will start empty until these are fixed."
  fi
}

# Per-user half of an update: dotfile drift, then the steps that depend on
# what actually changed for that account.
update_user() {
  set_target_user "$1"
  ui_section "USER · $TARGET_USER"
  log "Home: $TARGET_HOME"

  deploy_dotfiles
  if plan_touched ".config/quickshell/"; then
    check_quickshell
  fi
  if ((! NO_PACKAGES)); then
    install_pacseek
  fi

  if plan_touched ".local/share/fonts/" || plan_touched ".config/fontconfig/"; then
    refresh_font_cache
  fi
  if plan_touched ".config/ghostty/" || plan_touched ".config/quickshell/scripts/"; then
    setup_theme
  fi
  if ((INSTALL_NVIM)) && plan_touched ".config/nvim/"; then
    bootstrap_nvim
  fi

  install_textfox
  install_opencode
  # Rebuilding Equicord on every update is wasteful; the auto-repair unit
  # handles Discord's own updates. Rebuild only when no version is patched or
  # the bridge sources changed.
  if ((INSTALL_DISCORD_BRIDGE)); then
    if plan_touched ".config/quickshell/discord-bridge/" || ! discord_bridge_patched; then
      install_discord_bridge
    else
      ok "DiscordBridge is already patched"
    fi
  fi
  if ((! INSTALL_DISCORD_BRIDGE)) && plan_touched ".config/quickshell/discord-bridge/"; then
    warn "DiscordBridge files changed; rerun with --discord-bridge to rebuild the plugin"
  fi
}

run_update() {
  if ((CHECK_ONLY)); then
    log "Check mode: reporting changes only"
  elif ((DRY_RUN)); then
    warn "Dry run enabled; no changes will be made"
  elif ! confirm "Update Mist packages and dotfiles?"; then
    die "Aborted"
  fi

  ui_section "SYNC"
  sync_remote

  if ((! NO_PACKAGES)); then
    ui_section "UPGRADE"
    log "Synchronizing package databases and upgrading"
    update_package_databases
  fi

  ui_section "PACKAGES"
  collect_package_drift
  report_package_drift
  install_missing_packages
  if ((! NO_PACKAGES)); then
    install_feature_packages
    install_yay
  fi
  # System-wide, once.
  ui_section "SYSTEM"
  install_system_configs

  local user
  for user in "${TARGET_USERS[@]}"; do
    update_user "$user"
  done

  summary_update
}

summary() {
  local -a lines=(
    "1. Reboot or log out and back in."
    "2. Start Hyprland from a TTY with: Hyprland"
    "3. Open Ghostty and run: source ~/.zshrc"
    "4. If prompted, run: p10k configure"
    "5. Open nvim to finish any remaining LSP installs."
    ""
    "Optional applications: ./install.sh --full"
    "Update later: ./install.sh --update"
  )
  if ((INSTALL_DISCORD_BRIDGE)); then
    lines+=("" "Discord: start it once; the bridge patches on launch.")
  fi
  if ((INSTALL_TEXTFOX)); then
    lines+=("Firefox: restart it to load the textfox theme.")
  fi
  ui_panel "SYSTEM READY" "${lines[@]}"
  printf '\n'
}

# Per-user half of a fresh install.
setup_user() {
  set_target_user "$1"
  ui_section "USER · $TARGET_USER"
  log "Home: $TARGET_HOME"

  install_pacseek
  install_omz
  install_p10k
  install_fonts
  deploy_dotfiles
  check_quickshell
  refresh_font_cache
  set_shell
  install_textfox
  setup_theme
  install_opencode
  install_discord_bridge
  bootstrap_nvim
}

main() {
  ORIGINAL_ARGS=("$@")
  parse_args "$@"
  require_arch
  check_user
  resolve_targets

  local mode="install"
  ((UPDATE_MODE)) && mode="update"
  ((CHECK_ONLY)) && mode="check"
  ((DRY_RUN)) && ((!CHECK_ONLY)) && mode="$mode · dry run"
  ui_banner "$mode"

  start_sudo_keepalive
  wait_for_network
  ensure_base_tools

  if ((UPDATE_MODE)); then
    run_update
    return 0
  fi

  if ((DRY_RUN)); then
    warn "Dry run enabled; no changes will be made"
  elif ! confirm "Install Mist packages and deploy dotfiles?"; then
    die "Aborted"
  fi

  ui_section "UPGRADE"
  log "Synchronizing package databases and upgrading"
  update_package_databases

  ui_section "PACKAGES"
  install_packages "$PACKAGES_DIR/core.txt"
  install_packages "$PACKAGES_DIR/desktop.txt"
  install_packages "$PACKAGES_DIR/dev.txt"

  ui_section "HARDWARE"
  install_microcode
  install_gpu_packages

  ui_section "EXTRAS"
  # yay backs pacseek's AUR search and the optional AUR package group.
  install_yay

  if ((INSTALL_APPS)); then
    install_packages "$PACKAGES_DIR/apps.txt"
  elif ((!ASSUME_YES)) && confirm "Install the optional applications group?"; then
    install_packages "$PACKAGES_DIR/apps.txt"
    INSTALL_APPS=1
  fi

  # Firefox and Discord are installed even without --apps because the textfox
  # theme and the DiscordBridge plugin are enabled by default.
  install_feature_packages

  if ((INSTALL_AUR)); then
    install_aur_packages
  fi

  # System-wide, once for all targets.
  ui_section "SYSTEM"
  enable_app_services
  install_system_configs
  enable_services

  local user
  for user in "${TARGET_USERS[@]}"; do
    setup_user "$user"
  done

  summary
}

main "$@"
