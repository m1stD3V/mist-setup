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

ASSUME_YES=0
DRY_RUN=0
NO_DOTFILES=0
INSTALL_APPS=0
INSTALL_AUR=0
INSTALL_NVIM=1
INSTALL_OPENCODE=0
INSTALL_NVIDIA=0
INSTALL_DISCORD_BRIDGE=0

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

C_RESET=$'\033[0m'
C_BLUE=$'\033[34m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'

log() { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok() { printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s warn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die() {
  printf '%s fail%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
  exit 1
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
  -y, --yes          Accept defaults without prompting
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
      --full         Install optional apps, AUR packages, and OpenCode
      --apps         Install the optional applications group
      --aur          Install AUR packages (implies --apps)
      --opencode     Install the OpenCode CLI into ~/.opencode
      --nvidia       Install the NVIDIA open driver if NVIDIA is detected
      --discord-bridge
                     Patch the Discord desktop app with the Quickshell
                     DiscordBridge plugin (client mod; see CREDITS.md)
      --no-apps      Skip optional applications
      --no-aur       Skip AUR packages
      --no-nvim      Skip Neovim plugin bootstrap
      --no-dotfiles  Only install packages and services
  -h, --help         Show this help

The script is intended to run as a normal user with sudo access, after a fresh
Arch Linux install. It does not partition disks or install a bootloader.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      -y|--yes) ASSUME_YES=1 ;;
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
      --discord-bridge) INSTALL_DISCORD_BRIDGE=1 ;;
      --no-apps) INSTALL_APPS=0 ;;
      --no-aur) INSTALL_AUR=0 ;;
      --no-nvim) INSTALL_NVIM=0 ;;
      --no-dotfiles) NO_DOTFILES=1 ;;
      -h|--help)
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
  read -r -p "$1 [Y/n] " answer || return 1
  [[ -z "$answer" || "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

run() {
  if ((DRY_RUN)); then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

run_sudo() {
  if ((DRY_RUN)); then
    printf '[dry-run] sudo'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  sudo "$@"
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
  command -v sudo >/dev/null || die "sudo is required"
  if ((EUID == 0)); then
    # sudo keeps SUDO_USER, so a plain `sudo ./install.sh` still targets the
    # invoking account. A root login has no such hint and must name a target.
    if [[ -z "${SUDO_USER:-}" ]] && ((!ALL_USERS)) && [[ -z "$USER_OPT" ]]; then
      die "Running as root: pass --user NAME or --all-users"
    fi
    command -v runuser >/dev/null || die "runuser (util-linux) is required for --user/--all-users"
    return 0
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
    printf '[dry-run]'
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
    printf '[dry-run]'
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
    warn "Detected NVIDIA graphics"
    if ((INSTALL_NVIDIA)) || confirm "Install the NVIDIA open driver?"; then
      pkgs+=(nvidia-open nvidia-utils nvidia-settings linux-headers)
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
    run_build makepkg -si --noconfirm
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
    log "[dry-run] download and run the pacseek installer"
    return 0
  fi
  local pacseek_installer
  pacseek_installer="$(mktemp)"
  # Download first so the remote script is visible on disk and the transfer is
  # forced over HTTPS. It is still third-party code.
  if ! curl --proto '=https' --tlsv1.2 -fsSL -o "$pacseek_installer" \
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
  run_build yay -S --needed --noconfirm "${pkgs[@]}"
}

install_omz() {
  if [[ -d "$TARGET_HOME/.oh-my-zsh" ]]; then
    ok "Oh My Zsh already installed"
    return 0
  fi
  log "Installing Oh My Zsh"
  if ((DRY_RUN)); then
    log "[dry-run] install Oh My Zsh"
    return 0
  fi
  local omz_installer
  omz_installer="$(mktemp)"
  # Download first so the remote script is visible on disk and the transfer is
  # forced over HTTPS. It is still third-party code; review it if you care.
  if ! curl --proto '=https' --tlsv1.2 -fsSL -o "$omz_installer" \
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
    log "[dry-run] download MesloLGS NF fonts into $font_dir"
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
    log "[dry-run] fc-cache -f"
    return 0
  fi
  # Target the deployed user's cache even if the script ran with a different
  # HOME; includes both MesloLGS NF and the bundled icons-in-terminal font.
  as_user fc-cache -f >/dev/null
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
      */__pycache__/*|*.pyc|*.pyo|*.swp|*.swo|*~|.DS_Store) continue ;;
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
  total=$((${#PLAN_ADD[@]} + ${#PLAN_UPDATE[@]} + ${#PLAN_LEGACY[@]} +
    ${#PLAN_CONFLICT[@]} + ${#PLAN_LOCAL[@]} + ${#PLAN_REMOVE[@]} +
    ${#PLAN_KEEP_REMOVED[@]}))
  if ((total == 0)); then
    ok "Dotfiles already up to date"
    return 0
  fi

  log "Dotfile changes for $TARGET_HOME"
  for rel in "${PLAN_ADD[@]}"; do
    printf '  %sadd%s      ~/%s\n' "$C_GREEN" "$C_RESET" "$rel"
  done
  for rel in "${PLAN_UPDATE[@]}"; do
    printf '  %supdate%s   ~/%s\n' "$C_BLUE" "$C_RESET" "$rel"
    show_diff "$rel"
  done
  for rel in "${PLAN_REMOVE[@]}"; do
    printf '  %sremove%s   ~/%s\n' "$C_YELLOW" "$C_RESET" "$rel"
  done
  for rel in "${PLAN_LEGACY[@]}"; do
    if ((KEEP_LOCAL)); then
      printf '  %sconflict%s ~/%s (kept; repo copy saved as ~/%s.mist-new)\n' \
        "$C_YELLOW" "$C_RESET" "$rel" "$rel"
    else
      printf '  %supdate%s   ~/%s (no deploy record; previous copy backed up)\n' \
        "$C_BLUE" "$C_RESET" "$rel"
    fi
    show_diff "$rel"
  done
  for rel in "${PLAN_CONFLICT[@]}"; do
    if ((FORCE_DOTFILES)); then
      printf '  %sreplace%s  ~/%s (locally modified)\n' "$C_YELLOW" "$C_RESET" "$rel"
    else
      printf '  %sconflict%s ~/%s (kept; repo copy saved as ~/%s.mist-new)\n' \
        "$C_YELLOW" "$C_RESET" "$rel" "$rel"
    fi
    show_diff "$rel"
  done
  for rel in "${PLAN_LOCAL[@]}"; do
    printf '  %slocal%s    ~/%s (kept; unchanged upstream)\n' \
      "$C_GREEN" "$C_RESET" "$rel"
  done
  for rel in "${PLAN_KEEP_REMOVED[@]}"; do
    printf '  %slocal%s    ~/%s (kept; removed upstream but modified here)\n' \
      "$C_GREEN" "$C_RESET" "$rel"
  done
  for rel in "${PLAN_GENERATED[@]}"; do
    [[ -e "$TARGET_HOME/$rel" ]] && continue
    printf '  %sseed%s     ~/%s (generated from the wallpaper)\n' \
      "$C_BLUE" "$C_RESET" "$rel"
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
    printf '  backup %s\n' "$backup"
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
      printf '  backup %s\n' "$backup"
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
      printf '  backup %s\n' "$backup"
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
    printf '  backup %s\n' "$backup"
  done

  # Seed a missing generated file so the app that reads it works even before
  # the theme scripts run. It is not recorded in the manifest.
  for rel in "${PLAN_GENERATED[@]}"; do
    dest="$TARGET_HOME/$rel"
    [[ -e "$dest" ]] && continue
    deploy_copy "$DOTFILES_DIR/$rel" "$dest"
    printf '  seed     ~/%s\n' "$rel"
  done

  ok "Dotfiles: $added added, $updated updated, $replaced forced, $removed removed"
  if ((kept_legacy > 0)); then
    warn "$kept_legacy file(s) with no deploy record kept (--keep-local); rerun without it to replace them"
  fi
  if ((kept_conflicts > 0 && !FORCE_DOTFILES)); then
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
  local total=$((${#PLAN_ADD[@]} + ${#PLAN_UPDATE[@]} + ${#PLAN_LEGACY[@]} +
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
  run_sudo systemctl enable --now NetworkManager
  run_sudo systemctl enable --now bluetooth
  run_sudo systemctl enable --now fstrim.timer
  # the bar's power widget reads and switches profiles through this daemon
  run_sudo systemctl enable --now power-profiles-daemon.service
}

enable_app_services() {
  ((INSTALL_APPS)) || return 0
  log "Enabling optional application services"
  # Printing stack from packages/apps.txt
  run_sudo systemctl enable --now cups.socket
  run_sudo systemctl enable --now cups.path
  run_sudo systemctl enable --now firewalld
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
    log "[dry-run] initialize wallpaper state and per-app themes"
    return 0
  fi

  make_parent "$state_dir/."
  wallpaper="$(find "$TARGET_HOME/.config/wallpaper" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' \) \
    | sort | head -n1 || true)"

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
    log "[dry-run] install OpenCode into $TARGET_HOME/.opencode"
    return 0
  fi
  local oc_installer
  oc_installer="$(mktemp)"
  # Download first so the remote script is visible on disk and the transfer is
  # forced over HTTPS. It is still third-party code.
  if curl --proto '=https' --tlsv1.2 -fsSL -o "$oc_installer" https://opencode.ai/install; then
    chmod 644 "$oc_installer"
    as_user bash "$oc_installer" || warn "OpenCode install failed"
  else
    warn "OpenCode download failed"
  fi
  rm -f "$oc_installer"
}

install_discord_bridge() {
  ((INSTALL_DISCORD_BRIDGE)) || return 0
  local bridge_script="$TARGET_HOME/.config/quickshell/discord-bridge/install.sh"
  if [[ ! -f "$bridge_script" ]]; then
    warn "DiscordBridge installer missing; rerun without --no-dotfiles"
    return 0
  fi
  if ! command -v node >/dev/null; then
    warn "node is required to build the DiscordBridge plugin; skipping"
    return 0
  fi
  if [[ ! -d "$TARGET_HOME/.config/discord" ]]; then
    warn "Discord is not installed for $TARGET_USER; skipping DiscordBridge"
    return 0
  fi
  if ((DRY_RUN)); then
    log "[dry-run] build and inject the DiscordBridge plugin with $bridge_script"
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
  log "Bootstrapping Neovim plugins"
  if ((DRY_RUN)); then
    log "[dry-run] nvim --headless '+Lazy! sync' +qa"
    log "[dry-run] install Mason LSP servers and tools"
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
    printf '  %smissing%s  %s\n' "$C_YELLOW" "$C_RESET" "$p"
  done
  for p in "${MISSING_AUR[@]}"; do
    printf '  %smissing%s  %s (AUR)\n' "$C_YELLOW" "$C_RESET" "$p"
  done
}

install_missing_packages() {
  ((${#MISSING_REPO[@]} + ${#MISSING_AUR[@]})) || return 0
  if ((NO_PACKAGES)); then
    warn "Skipping missing packages (--no-packages)"
    return 0
  fi
  if ((DRY_RUN)); then
    log "[dry-run] install the missing packages listed above"
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
    yay -S --needed --noconfirm "${MISSING_AUR[@]}" ||
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
    log "[dry-run] git pull --ff-only (would apply $behind commit(s))"
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
  printf '\nMist update finished.\n\n'
  if ((CHECK_ONLY)); then
    printf 'Nothing was changed (--check). Run ./install.sh --update to apply.\n'
    return 0
  fi
  if ((DRY_RUN)); then
    printf 'Dry run: nothing was changed.\n'
    return 0
  fi
  if ((DOTFILES_CHANGED)); then
    cat <<'EOF'
Reload the desktop to pick up the new configuration:
  - Hyprland:  hyprctl reload
  - Quickshell: log out and back in (or restart Hyprland)
  - Ghostty:   open a new window
EOF
    if ((KEEP_LOCAL)); then
      printf 'Files with no deploy record were kept; repo versions are in *.mist-new.\n'
    else
      printf 'Files replaced without a deploy record have a .pre-mist-<timestamp> backup.\n'
    fi
    printf 'Files edited both locally and upstream are kept in place with *.mist-new;\n'
    printf 'rerun with --force to replace them.\n'
  else
    printf 'No dotfile changes were needed.\n'
  fi
  if ((SYSTEM_CONFIGS_CHANGED)); then
    printf 'zram configuration changed; reboot for it to take effect.\n'
  fi
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
  log "Dotfiles and user tools for $TARGET_USER ($TARGET_HOME)"

  deploy_dotfiles
  if plan_touched ".config/quickshell/"; then
    check_quickshell
  fi
  if ((!NO_PACKAGES)); then
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

  install_opencode
  install_discord_bridge
  if ((!INSTALL_DISCORD_BRIDGE)) && plan_touched ".config/quickshell/discord-bridge/"; then
    warn "DiscordBridge files changed; rerun with --discord-bridge to rebuild the plugin"
  fi
}

run_update() {
  log "Mist update for ${#TARGET_USERS[@]} user(s)"
  if ((CHECK_ONLY)); then
    log "Check mode: reporting changes only"
  elif ((DRY_RUN)); then
    warn "Dry run enabled; no changes will be made"
  elif ! confirm "Update Mist packages and dotfiles?"; then
    die "Aborted"
  fi

  sync_remote

  collect_package_drift
  report_package_drift
  install_missing_packages
  if ((!NO_PACKAGES)); then
    install_yay
  fi
  # System-wide, once.
  install_system_configs

  local user
  for user in "${TARGET_USERS[@]}"; do
    update_user "$user"
  done

  summary_update
}

summary() {
  cat <<EOF

Mist setup complete.

Next steps:
  1. Reboot or log out and back in.
  2. Start Hyprland from a TTY with: Hyprland
  3. Open Ghostty and run: source ~/.zshrc
  4. If prompted, run: p10k configure
  5. Open nvim and let any remaining LSP tools finish installing.

Optional applications: run ./install.sh --full
Update later: run ./install.sh --update
Discord bar widget: run ./install.sh --discord-bridge (client mod)
Firefox theme: enabled by the generated profile user.js; restart Firefox.
EOF
}

# Per-user half of a fresh install.
setup_user() {
  set_target_user "$1"
  log "Setting up user $TARGET_USER ($TARGET_HOME)"

  install_pacseek
  install_omz
  install_p10k
  install_fonts
  deploy_dotfiles
  check_quickshell
  refresh_font_cache
  set_shell
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

  if ((UPDATE_MODE)); then
    run_update
    return 0
  fi

  local user_list
  user_list="$(IFS=,; printf '%s' "${TARGET_USERS[*]}")"
  log "Mist setup for ${#TARGET_USERS[@]} user(s): $user_list"
  if ((DRY_RUN)); then
    warn "Dry run enabled; no changes will be made"
  elif ! confirm "Install Mist packages and deploy dotfiles?"; then
    die "Aborted"
  fi

  log "Updating package databases and system"
  run_sudo pacman -Syu --noconfirm

  install_packages "$PACKAGES_DIR/core.txt"
  install_packages "$PACKAGES_DIR/desktop.txt"
  install_packages "$PACKAGES_DIR/dev.txt"
  install_microcode
  install_gpu_packages

  # yay backs pacseek's AUR search and the optional AUR package group.
  install_yay

  if ((INSTALL_APPS)); then
    install_packages "$PACKAGES_DIR/apps.txt"
  elif ((!ASSUME_YES)) && confirm "Install the optional applications group?"; then
    install_packages "$PACKAGES_DIR/apps.txt"
    INSTALL_APPS=1
  fi

  if ((INSTALL_AUR)); then
    install_aur_packages
  fi

  # System-wide, once for all targets.
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
