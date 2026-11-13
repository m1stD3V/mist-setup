#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$ROOT_DIR/dotfiles"
PACKAGES_DIR="$ROOT_DIR/packages"
SYSTEM_DIR="$ROOT_DIR/system"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SUDO="sudo"

ASSUME_YES=0
DRY_RUN=0
NO_DOTFILES=0
INSTALL_APPS=0
INSTALL_AUR=0
INSTALL_NVIM=1
INSTALL_OPENCODE=0
INSTALL_NVIDIA=0

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

Options:
  -y, --yes          Accept defaults without prompting
      --dry-run      Print actions without changing the system
      --full         Install optional apps, AUR packages, and OpenCode
      --apps         Install the optional applications group
      --aur          Install AUR packages (implies --apps)
      --opencode     Install the OpenCode CLI into ~/.opencode
      --nvidia       Install the NVIDIA open driver if NVIDIA is detected
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
  [[ $EUID -ne 0 ]] || die "Run this script as a normal user, not as root"
  command -v sudo >/dev/null || die "sudo is required"
  [[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || die "Cannot determine home directory for $TARGET_USER"
  [[ "$TARGET_HOME" != "/" ]] || die "Refusing to deploy dotfiles to /"
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
  command -v yay >/dev/null && return 0
  log "Installing yay-bin from the AUR"
  local tmp
  tmp="$(mktemp -d)"
  run git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  if ((DRY_RUN)); then
    rm -rf "$tmp"
    return 0
  fi
  (
    cd "$tmp/yay-bin"
    makepkg -si --noconfirm
  )
  rm -rf "$tmp"
}

install_aur_packages() {
  ((INSTALL_AUR)) || return 0
  install_yay
  local -a pkgs=()
  mapfile -t pkgs < <(read_packages "$PACKAGES_DIR/aur.txt")
  ((${#pkgs[@]})) || return 0
  local IFS=' '
  log "Installing AUR packages: ${pkgs[*]}"
  if ((DRY_RUN)); then
    run yay -S --needed --noconfirm "${pkgs[@]}"
  else
    yay -S --needed --noconfirm "${pkgs[@]}"
  fi
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
  HOME="$TARGET_HOME" RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_p10k() {
  local theme_dir="$TARGET_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [[ -d "$theme_dir" ]]; then
    ok "Powerlevel10k already installed"
    return 0
  fi
  log "Installing Powerlevel10k"
  run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
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
  mkdir -p "$font_dir"
  local i
  for i in "${!url_names[@]}"; do
    curl -fL --retry 3 -o "$font_dir/MesloLGS NF ${file_names[$i]}.ttf" \
      "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20${url_names[$i]}.ttf"
  done
  fc-cache -f >/dev/null
}

deploy_dotfiles() {
  ((NO_DOTFILES)) && {
    warn "Skipping dotfiles"
    return 0
  }
  log "Deploying dotfiles to $TARGET_HOME"
  if ((DRY_RUN)); then
    log "[dry-run] copy $DOTFILES_DIR into $TARGET_HOME"
    return 0
  fi

  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local src rel dest
  while IFS= read -r -d '' src; do
    rel="${src#"$DOTFILES_DIR"/}"
    dest="$TARGET_HOME/$rel"
    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
      continue
    fi
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" ]]; then
      cp -a "$dest" "$dest.pre-mist-$stamp"
    fi
    cp -a "$src" "$dest"
  done < <(find "$DOTFILES_DIR" -type f -print0)
  ok "Dotfiles deployed"
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
  if [[ -f "$SYSTEM_DIR/zram-generator.conf" ]]; then
    log "Installing zram-generator configuration"
    run_sudo install -Dm644 "$SYSTEM_DIR/zram-generator.conf" /etc/systemd/zram-generator.conf
  fi
}

enable_services() {
  log "Enabling core services"
  run_sudo systemctl enable --now NetworkManager
  run_sudo systemctl enable --now bluetooth
  run_sudo systemctl enable --now fstrim.timer
}

setup_theme() {
  local state_dir="$TARGET_HOME/.local/state/mist"
  local wallpaper=""
  local theme_script="$TARGET_HOME/.config/ghostty/sync-theme.py"

  if ((DRY_RUN)); then
    log "[dry-run] initialize wallpaper state and Ghostty theme"
    return 0
  fi

  mkdir -p "$state_dir"
  wallpaper="$(find "$TARGET_HOME/.config/wallpaper" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' \) \
    | sort | head -n1 || true)"

  if [[ -n "$wallpaper" ]]; then
    printf '%s\n' "$wallpaper" >"$state_dir/wallpaper"
  fi

  if [[ -x "$theme_script" || -f "$theme_script" ]]; then
    HOME="$TARGET_HOME" python3 "$theme_script" || warn "Failed to generate Ghostty theme"
  fi
}

install_opencode() {
  ((INSTALL_OPENCODE)) || return 0
  if command -v opencode >/dev/null; then
    ok "OpenCode already installed"
    return 0
  fi
  log "Installing OpenCode CLI"
  if ((DRY_RUN)); then
    log "[dry-run] install OpenCode into $TARGET_HOME/.opencode"
    return 0
  fi
  HOME="$TARGET_HOME" bash -c 'curl -fsSL https://opencode.ai/install | bash' || warn "OpenCode install failed"
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

  local env_args=(
    "HOME=$TARGET_HOME"
    "XDG_CONFIG_HOME=$TARGET_HOME/.config"
    "XDG_DATA_HOME=$TARGET_HOME/.local/share"
    "XDG_STATE_HOME=$TARGET_HOME/.local/state"
  )

  env "${env_args[@]}" nvim --headless "+Lazy! sync" +qa || warn "Neovim plugin sync failed"
  env "${env_args[@]}" nvim --headless \
    -c "luafile $ROOT_DIR/scripts/nvim-mason.lua" -c qa || warn "Mason bootstrap failed"
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
EOF
}

main() {
  parse_args "$@"
  require_arch
  check_user

  log "Mist setup for $TARGET_USER ($TARGET_HOME)"
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

  if ((INSTALL_APPS)); then
    install_packages "$PACKAGES_DIR/apps.txt"
  elif ((!ASSUME_YES)) && confirm "Install the optional applications group?"; then
    install_packages "$PACKAGES_DIR/apps.txt"
    INSTALL_APPS=1
  fi

  if ((INSTALL_AUR)); then
    install_aur_packages
  fi

  install_omz
  install_p10k
  install_fonts
  deploy_dotfiles
  install_system_configs
  enable_services
  set_shell
  setup_theme
  install_opencode
  bootstrap_nvim

  summary
}

main "$@"
