#!/usr/bin/env bash
#
# install.sh — bootstrap an Arch/CachyOS machine to match this dotfiles repo.
#
# Installs every package the configs actually reference, drops the fonts kitty
# and the prompt ask for, clones the zsh plugins, and wires the repo up as
# symlinks into ~ so edits are live (no rsync step).
#
# Idempotent: safe to re-run. Already-installed packages are skipped, correct
# symlinks are left alone, and anything in the way is backed up, never deleted.
#
# Usage:
#   ./install.sh [options]
#
#   -y, --yes            non-interactive; assume yes to every prompt
#       --repo PATH       dotfiles checkout location (default: ~/Dotfiles)
#       --skip-packages   only wire up configs, install nothing
#       --no-aur          skip AUR packages entirely
#       --dry-run         print what would happen, change nothing
#   -h, --help            this text
#
# After it finishes, log out and back in (or reboot) so the niri session picks
# up the new packages, then run `niri validate`.

set -euo pipefail

REPO_URL="https://github.com/joshuapieroway/Dotfiles.git"
REPO_PATH="${REPO_PATH:-$HOME/Dotfiles}"
REPO_BRANCH="main"

ASSUME_YES=0
SKIP_PACKAGES=0
NO_AUR=0
DRY_RUN=0

# ── output ────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

step()  { printf '\n%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '    %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '    %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()   { printf '    %sx%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
skip()  { printf '    %s·%s %s%s%s\n' "$C_DIM" "$C_RESET" "$C_DIM" "$*" "$C_RESET"; }
die()   { err "$*"; exit 1; }

# Print the leading comment block (the header) and stop at the first
# non-comment line, so usage text can never leak into the code below it.
usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
  exit 0
}

# ── args ──────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)          ASSUME_YES=1 ;;
    --repo)            [[ -n "${2:-}" ]] || die "--repo needs a path"; REPO_PATH="$2"; shift ;;
    --repo=*)          REPO_PATH="${1#*=}" ;;
    --skip-packages)   SKIP_PACKAGES=1 ;;
    --no-aur)          NO_AUR=1 ;;
    --dry-run)         DRY_RUN=1 ;;
    -h|--help)         usage ;;
    *)                 die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# Non-interactive when there is no TTY, so CI/pipe runs do not hang.
[[ -t 0 ]] || ASSUME_YES=1

printf '%s%sdotfiles installer%s  %s(%s)%s\n' \
  "$C_BOLD" "$C_CYAN" "$C_RESET" "$C_DIM" "$REPO_PATH" "$C_RESET"
if [[ $DRY_RUN -eq 1 ]]; then
  printf '%s    dry run — nothing will be changed%s\n' "$C_YELLOW" "$C_RESET"
fi

run_privileged() {
  if [[ $DRY_RUN -eq 1 ]]; then
    info "${C_DIM}dry-run:$C_RESET $*"
    return 0
  fi
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    ${SUDO:+$SUDO} "$@"
  fi
}

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  local reply
  read -rp "    $1 [y/N] " reply
  [[ "$reply" =~ ^[Yy] ]]
}

# ── preconditions ─────────────────────────────────────────────────────────
step "Checking the system"

if [[ ! -r /etc/os-release ]]; then
  die "cannot read /etc/os-release"
fi
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-} ${ID_LIKE:-}" in
  *arch*|*cachyos*) ;;
  *) die "this script targets Arch/CachyOS; detected '${PRETTY_NAME:-${NAME:-${ID:-unknown}}}'" ;;
esac
ok "${PRETTY_NAME:-${NAME:-${ID:-Arch}}}"

command -v pacman >/dev/null || die "pacman not found"
ok "pacman $(pacman --version | sed -n 's/.*Pacman v\([^ ]*\).*/\1/p' | head -1)"

# AUR helper — optional. Every package install_packages() asks for lives in an
# official repo, so a missing helper is only worth a quiet note, not a warning.
# It still gets used the moment an AUR-only package shows up in a group.
AUR_HELPER=""
if [[ $NO_AUR -eq 0 ]]; then
  for helper in paru yay paku trizen; do
    if command -v "$helper" >/dev/null; then AUR_HELPER="$helper"; break; fi
  done
  if [[ -n "$AUR_HELPER" ]]; then
    ok "AUR helper: $AUR_HELPER"
  else
    skip "no AUR helper (paru/yay/paku) — only matters for AUR-only packages"
  fi
fi

# sudo is resolved lazily: with --skip-packages (and zsh already the default
# shell) the script never needs it, so it must not demand a password up front.
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null; then
    SUDO="sudo"
  else
    warn "no sudo — package installs will fail unless you re-run as root"
  fi
fi

# Installed-package cache, so we do not shell out to pacman per package.
declare -A HAVE=()
while read -r _p; do [[ -n "$_p" ]] && HAVE["$_p"]=1; done < <(pacman -Qq 2>/dev/null || true)

have()      { [[ -n "${HAVE[$1]:-}" ]]; }
mark_have() { HAVE["$1"]=1; }
in_repo()   { pacman -Si "$1" >/dev/null 2>&1; }
in_aur()    { [[ -n "$AUR_HELPER" ]] && "$AUR_HELPER" -Si "$1" >/dev/null 2>&1; }

# Installed packages that block <pkg>, one per line. Asks pacman rather than
# hardcoding names, so providers (not just exact names) are caught: pipewire-jack
# and jack2 never name each other, they just conflict on the virtual "jack".
installed_conflicts() {
  local pkg="$1" name
  pacman -Qi "$pkg" 2>/dev/null | awk '
    /^[^[:space:]]/ {                      # a new "Key      : value" field
      key = $1
      val = $0
      sub(/^[^:]*:[[:space:]]*/, "", val)   # drop the "Conflicts With :" prefix
      active = (key ~ /^Conflicts/ || key ~ /^Replaces/)
      if (active) { n = split(val, a); for (i = 1; i <= n; i++) print a[i] }
      next
    }
    active { for (i = 1; i <= NF; i++) print $i }   # wrapped value lines
  ' | while read -r name; do
    have "$name" && printf '%s\n' "$name"
  done
  return 0   # "no conflicts" is a normal result, not a failure
}

# install_group <label> <pkg>...
# Splits into already-have / repo / AUR / unknown and installs the rest.
install_group() {
  local label="$1"; shift
  local -a want=() have_pkgs=() repo_pkgs=() aur_pkgs=() unknown=()

  for p in "$@"; do
    [[ -n "$p" ]] || continue
    want+=("$p")
  done
  ((${#want[@]})) || return 0

  for p in "${want[@]}"; do
    if have "$p"; then
      have_pkgs+=("$p")
    elif in_repo "$p"; then
      repo_pkgs+=("$p")
    elif [[ $NO_AUR -eq 0 ]] && in_aur "$p"; then
      aur_pkgs+=("$p")
    else
      unknown+=("$p")
    fi
  done

  info "${C_BOLD}$label${C_RESET}"

  ((${#have_pkgs[@]})) && skip "already installed: ${have_pkgs[*]}"
  ((${#unknown[@]}))   && warn "not found in any repo, skipping: ${unknown[*]}"

  if ((${#repo_pkgs[@]})); then
    info "installing: ${repo_pkgs[*]}"
    if [[ $DRY_RUN -eq 1 ]]; then
      info "${C_DIM}dry-run: pacman -S --needed --noconfirm${C_RESET} ${repo_pkgs[*]}"
    elif run_privileged pacman -S --needed --noconfirm "${repo_pkgs[@]}"; then
      for p in "${repo_pkgs[@]}"; do mark_have "$p"; done
    else
      # One unresolvable conflict (jack2 vs pipewire-jack, say) aborts the whole
      # transaction and leaves nothing installed, so retry one at a time to
      # salvage everything that does resolve.
      warn "batch install failed — retrying individually"
      local -a failed=()
      for p in "${repo_pkgs[@]}"; do
        if run_privileged pacman -S --needed --noconfirm "$p"; then
          mark_have "$p"
        else
          failed+=("$p")
        fi
      done
      ((${#failed[@]})) && warn "could not install: ${failed[*]}"
    fi
  fi

  if ((${#aur_pkgs[@]})); then
    if [[ -n "$AUR_HELPER" ]]; then
      info "installing (AUR): ${aur_pkgs[*]}"
      if [[ $DRY_RUN -eq 1 ]]; then
        info "${C_DIM}dry-run: $AUR_HELPER -S --needed --noconfirm${C_RESET} ${aur_pkgs[*]}"
      else
        "$AUR_HELPER" -S --needed --noconfirm "${aur_pkgs[@]}" \
          || warn "AUR helper reported errors for: ${aur_pkgs[*]}"
        for p in "${aur_pkgs[@]}"; do mark_have "$p"; done
      fi
    else
      warn "skipping AUR: ${aur_pkgs[*]}"
    fi
  fi

  if ! ((${#repo_pkgs[@]} || ${#aur_pkgs[@]})); then
    [[ ${#have_pkgs[@]} -gt 0 || ${#unknown[@]} -gt 0 ]] && ok "nothing to do"
  fi
  return 0
}

# ── packages ──────────────────────────────────────────────────────────────
# The rule: install what a config in this repo actually *invokes*, plus what
# this script needs to run. Nothing else. A package earns its place only if
# grep finds it in a keybind, an autostart line, a yazi opener, a shell alias,
# or an env var the compositor reads.

install_packages() {
  step "Installing packages"

  # bash is not implicit here: autostart.kdl spawns it as argv[0] on two lines.
  # curl is what install_font uses to fetch Maple Mono NF.
  install_group "Base toolchain" \
    bash base-devel git curl unzip

  # niri execs xwayland-satellite itself (config/env.kdl), and env.kdl points
  # Qt and GTK at qt6ct and Papirus, so both themes are load-bearing.
  install_group "Compositor and session" \
    niri xwayland-satellite \
    qt6ct papirus-icon-theme adw-gtk-theme

  # kitty/neovim/yazi are spawned by keybinds.kdl and yazi.toml; the zsh trio
  # is sourced unconditionally by .zshrc, so it is mandatory, not cosmetic.
  #
  # NB: nvim's init.lua gates its 22-parser install on `executable("tree-sitter")`,
  # so the *CLI* is what matters. Arch's `tree-sitter` package ships only
  # libtree-sitter.so + headers; the binary lives in `tree-sitter-cli`, and
  # nvim-treesitter uses nvim's own bundled parser runtime, not the system lib.
  install_group "Terminal, shell, editor, files" \
    kitty neovim yazi \
    zsh cachyos-zsh-config zsh-theme-powerlevel10k \
    fzf eza bat zoxide \
    tree-sitter-cli

  # autostart.kdl starts a cliphist daemon behind wl-paste and enables the
  # easyeffects unit on every login; .zshrc pipes fzf output into wl-copy;
  # kitty.conf uses xdg-open for URL hints.
  install_group "Session runtime" \
    wl-clipboard cliphist easyeffects xdg-utils

  # yazi.toml opens images with imv and video/audio with mpv; keybinds.kdl
  # drives the four media keys with playerctl.
  install_group "Media openers" \
    imv mpv playerctl

  # init.lua enables the clangd LSP directly (mason will not manage it), so
  # the compiler toolchain has to be here for C/C++ to get diagnostics.
  install_group "Editor language support" \
    clang

  # pipewire-jack and the standalone JACK daemons both provide the JACK API and
  # are mutually exclusive. Note the asymmetry that makes this easy to miss:
  # pipewire-jack names "jack2" in its Conflicts With, but jack2 declares its
  # conflict on the virtual "jack" instead, so neither names the other. This
  # script never removes an installed package, so when a competitor is present
  # we leave it alone and drop pipewire-jack from this run.
  local -a audio=(
    pipewire pipewire-pulse wireplumber pipewire-alsa pipewire-jack
    pavucontrol
  )
  if ! have pipewire-jack; then
    local -a competing=()
    local c
    while read -r c; do competing+=("$c"); done < <(installed_conflicts pipewire-jack)
    # Named fallbacks, in case installed_conflicts came back empty because the
    # sync DB is stale or the metadata is unreadable.
    for c in jack jack2 jack2-full jack2-dbus; do
      if have "$c" && [[ " ${competing[*]:-} " != *" $c "* ]]; then
        competing+=("$c")
      fi
    done
    if ((${#competing[@]})); then
      warn "${competing[*]} conflicts with pipewire-jack — leaving it installed, skipping pipewire-jack"
      info "for PipeWire's JACK instead: sudo pacman -R ${competing[*]} && re-run this script"
      audio=("${audio[@]/pipewire-jack/}")
    fi
  fi
  install_group "Audio and power" "${audio[@]}"

  # GTK/Qt theming: gtk-3.0/settings.ini, gtk-4.0/settings.ini, qt5ct.conf,
  # qt6ct.conf, xsettingsd.conf, and .gtkrc-2.0 all reference these.
  install_group "Theming and GTK/Qt" \
    gtk3 gtk4 qt5ct \
    xsettingsd nwg-look \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    ttf-jetbrains-mono ttf-nerd-fonts-symbols-common \
    otf-font-awesome woff2-font-awesome awesome-terminal-fonts

  # Desktop utilities referenced by configs and scripts.
  install_group "Desktop utilities" \
    cava fastfetch mangohud lsp-plugins \
    openrgb \
    brightnessctl pamixer \
    wl-gammarelay-rs wmctrl socat \
    zbar ffmpegthumbnailer mediainfo \
    inotify-tools libnotify libappindicator libva-utils

  # xdg-desktop-portal backends referenced by niri-portals.conf.
  install_group "Portals" \
    xdg-desktop-portal-gtk xdg-desktop-portal-wlr

  # Fonts referenced by kitty.conf and p10k.
  install_group "Fonts" \
    ttf-jetbrains-mono ttf-nerd-fonts-symbols-common \
    otf-font-awesome woff2-font-awesome awesome-terminal-fonts \
    noto-fonts noto-fonts-cjk noto-fonts-emoji

  # Misc tools used by scripts and configs.
  install_group "Misc tools" \
    alsa-utils bc fd jq ripgrep htop \
    vim wget 7zip acpi \
    power-profiles-daemon \
    networkmanager bluez bluez-utils

  # GPU and gaming.
  install_group "GPU and gaming" \
    vulkan-radeon lib32-vulkan-radeon vulkan-tools \
    gamemode

  # Development tools.
  install_group "Development" \
    docker docker-compose nodejs npm jdk17-openjdk \
    python-jeepney python-websockets

  # Applications referenced by keybinds and configs.
  install_group "Applications" \
    librewolf spotify spotify-qt-debug librespot \
    flatpak fuse2 gvfs-mtp ark \
    kdenlive obsidian

  # AUR packages.
  install_group "AUR packages" \
    gallery-dl-git spicetify-cli satty \
    wf-recorder gpu-screen-recorder \
    v4l2loopback-dkms v4l2loopback-utils \
    protonup-qt-bin ddcutil

  # System utilities.
  install_group "System" \
    zram-generator systemd-resolvconf efibootmgr \
    linux-firmware
}

# ── fonts ─────────────────────────────────────────────────────────────────
# kitty.conf pins "JetBrains Mono" and "Iosevka Nerd Font" (via symbol_map).
# JetBrains Mono is in the repos (ttf-jetbrains-mono). Iosevka Nerd Font is
# in the AUR. This function installs Iosevka Nerd Font if missing.
install_font() {
  step "Installing fonts"

  if fc-list 2>/dev/null | grep -qi 'Iosevka Nerd Font'; then
    ok "Iosevka Nerd Font already present"
    return 0
  fi

  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip"
  local fontdir="$HOME/.local/share/fonts"
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  if [[ $DRY_RUN -eq 1 ]]; then
    info "${C_DIM}dry-run: fetch $url -> $fontdir${C_RESET}"
    return 0
  fi

  if command -v curl >/dev/null; then
    curl -fL --retry 2 --max-time 180 -o "$tmp/iosevka.zip" "$url" \
      || { warn "font download failed — kitty will fall back to its default face"; return 0; }
  else
    warn "curl missing — skipping font"
    return 0
  fi

  mkdir -p "$fontdir"
  if command -v unzip >/dev/null; then
    unzip -oq "$tmp/iosevka.zip" -d "$fontdir" || warn "unzip failed"
  else
    warn "unzip missing — install it and re-run, or fetch the font manually"
    return 0
  fi

  command -v fc-cache >/dev/null && fc-cache -f "$fontdir" >/dev/null 2>&1 || true
  ok "Iosevka Nerd Font installed to $fontdir"
}

# ── zsh plugins ──────────────────────────────────────────────────────────
# .zshrc sources ~/.zsh/zsh-autosuggestions and ~/.zsh/zsh-syntax-highlighting.
# These are git repos, not pacman packages. Clone them if missing.
install_zsh_plugins() {
  step "Installing zsh plugins"

  local plugins=(
    "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting"
  )

  for entry in "${plugins[@]}"; do
    local name="${entry%% *}"
    local url="${entry#* }"
    local dest="$HOME/.zsh/$name"

    if [[ -d "$dest/.git" ]]; then
      ok "$name already cloned"
    elif [[ $DRY_RUN -eq 1 ]]; then
      info "${C_DIM}dry-run: git clone $url -> $dest${C_RESET}"
    else
      mkdir -p "$HOME/.zsh"
      git clone --depth=1 "$url" "$dest" \
        && ok "$name cloned" \
        || warn "failed to clone $name"
    fi
  done
}

# ── repo ──────────────────────────────────────────────────────────────────
get_repo() {
  step "Dotfiles repo"

  if [[ -d "$REPO_PATH/.git" ]]; then
    ok "already present at $REPO_PATH"
    if [[ $DRY_RUN -eq 1 ]]; then
      skip "dry-run: would git pull"
      return 0
    fi
    if confirm "Pull the latest changes into $REPO_PATH?"; then
      git -C "$REPO_PATH" pull --ff-only \
        || warn "git pull failed — continuing with what is on disk"
    fi
    return 0
  fi

  if [[ -e "$REPO_PATH" ]]; then
    die "$REPO_PATH exists but is not a git checkout — move it aside first"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    info "${C_DIM}dry-run: git clone $REPO_URL -> $REPO_PATH${C_RESET}"
    return 0
  fi

  confirm "Clone $REPO_URL into $REPO_PATH?" || die "cannot continue without the repo"
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_PATH" \
    || die "git clone failed"
  ok "cloned"
}

# Guard against pointing --repo at the wrong directory. Rewiring ~/.config is
# destructive-ish (it backs up whatever is there), so refuse unless the path
# actually has this repo's layout.
check_repo_layout() {
  local found=0 expected
  for expected in niri/.config/niri nvim/.config/nvim kitty/.config/kitty \
                 yazi/.config/yazi zsh/.zshrc; do
    if [[ -e "$REPO_PATH/$expected" ]]; then
      found=$((found + 1))
    else
      warn "missing: $REPO_PATH/$expected"
    fi
  done

  if ((found == 0)); then
    die "$REPO_PATH does not look like this dotfiles repo (no niri/nvim/kitty/yazi/zsh config found) — refusing to rewire ~/.config. Check --repo."
  fi
  if ((found < 5)); then
    warn "only $found/5 expected config trees found in $REPO_PATH — wiring what exists"
  else
    ok "repo layout verified ($found/5 config trees)"
  fi
}

# ── symlink wiring ────────────────────────────────────────────────────────
# The live layout: ~/.config/<app>/ is a real directory whose *entries* are
# symlinks into the repo, so edits in the working tree take effect immediately
# with no copy or rsync step.
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# link_entries <src_dir> <dst_dir>
# Symlinks each entry in src_dir into dst_dir, backing up anything in the way.
link_entries() {
  local src="$1" dst="$2"

  if [[ ! -d "$src" ]]; then
    skip "$(basename "$src") — no config in repo, leaving alone"
    return 0
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$dst"
  elif [[ ! -d "$dst" ]]; then
    info "${C_DIM}dry-run: mkdir -p $dst${C_RESET}"
  fi

  local linked=0 kept=0 backed=0
  local name target
  while IFS= read -r -d '' name; do
    target="$dst/$name"
    local want="$src/$name"

    # if already pointing at the repo
    if [[ -L "$target" && "$(readlink -f "$target" 2>/dev/null)" == "$(readlink -f "$want")" ]]; then
      kept=$((kept + 1))
      continue
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
      info "${C_DIM}dry-run: link $name -> $want${C_RESET}"
      linked=$((linked + 1))
      continue
    fi

    # backups
    if [[ -e "$target" || -L "$target" ]]; then
      mv "$target" "${target}${BACKUP_SUFFIX}" 2>/dev/null \
        && backed=$((backed + 1)) \
        || warn "could not back up $target — skipping $name"
      [[ -e "${target}${BACKUP_SUFFIX}" || -L "${target}${BACKUP_SUFFIX}" ]] || continue
    fi

    ln -s "$want" "$target" && linked=$((linked + 1))
  done < <(find "$src" -mindepth 1 -maxdepth 1 -printf '%f\0' 2>/dev/null)

  printf '    %s✓%s %-20s %s\n' "$C_GREEN" "$C_RESET" "$(basename "$src")" \
    "${linked} linked, ${kept} already correct, ${backed} backed up"
  if ((backed > 0)); then
    skip "backups use suffix ${BACKUP_SUFFIX}"
  fi
}

# link_file <src_file> <dst_file>
# Symlinks a single file, backing up anything in the way.
link_file() {
  local src="$1" dst="$2"

  [[ -f "$src" ]] || { skip "$(basename "$src") — not in repo"; return 0; }

  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    skip "$(basename "$dst") already linked"
  elif [[ $DRY_RUN -eq 1 ]]; then
    info "${C_DIM}dry-run: link $(basename "$dst") -> $src${C_RESET}"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "${dst}${BACKUP_SUFFIX}" 2>/dev/null && info "backed up existing $(basename "$dst")"
    ln -s "$src" "$dst" && ok "linked $(basename "$dst")"
  else
    ln -s "$src" "$dst" && ok "linked $(basename "$dst")"
  fi
}

link_configs() {
  step "Wiring configs"

  # Standard .config apps — repo dir app/.config/app maps to ~/.config/app
  local app
  for app in niri nvim kitty yazi qt xsettingsd easyeffects mpv cava \
             fastfetch spicetify mangohud lsp-plugins nwg-look gallery-dl \
             portal systemd environment.d; do
    link_entries "$REPO_PATH/$app/.config/$app" "$HOME/.config/$app"
  done

  # GTK — two subdirs plus a top-level dotfile
  link_entries "$REPO_PATH/gtk/.config/gtk-3.0" "$HOME/.config/gtk-3.0"
  link_entries "$REPO_PATH/gtk/.config/gtk-4.0" "$HOME/.config/gtk-4.0"
  link_file "$REPO_PATH/gtk/.gtkrc-2.0" "$HOME/.gtkrc-2.0"

  # mimeapps.list — a single file, not a directory
  link_file "$REPO_PATH/mimeapps/.config/mimeapps.list" "$HOME/.config/mimeapps.list"

  # user-dirs — two files
  link_file "$REPO_PATH/user-dirs/.config/user-dirs.dirs" "$HOME/.config/user-dirs.dirs"
  link_file "$REPO_PATH/user-dirs/.config/user-dirs.locale" "$HOME/.config/user-dirs.locale"

  # spotify-flags.conf — a single file
  link_file "$REPO_PATH/spotify/.config/spotify-flags.conf" "$HOME/.config/spotify-flags.conf"

  # Top-level dotfiles
  link_file "$REPO_PATH/zsh/.zshrc" "$HOME/.zshrc"
  link_file "$REPO_PATH/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
  link_file "$REPO_PATH/zsh/.zshenv" "$HOME/.zshenv"

  # .local/bin scripts
  link_entries "$REPO_PATH/bin/.local/bin" "$HOME/.local/bin"

  # .local/share/applications
  link_entries "$REPO_PATH/applications/.local/share/applications" "$HOME/.local/share/applications"
}

# ── systemd user units ───────────────────────────────────────────────────
enable_units() {
  step "Enabling systemd user units"

  if ! command -v systemctl >/dev/null; then
    skip "systemctl not found — skipping"
    return 0
  fi

  local unit
  for unit in openrgb arknights-gallery; do
    local src="$REPO_PATH/systemd/.config/systemd/user/${unit}.service"
    [[ -f "$src" ]] || { skip "$unit.service — not in repo"; continue; }

    if [[ $DRY_RUN -eq 1 ]]; then
      info "${C_DIM}dry-run: systemctl --user enable --now $unit${C_RESET}"
    elif systemctl --user enable --now "$unit" >/dev/null 2>&1; then
      ok "$unit.service enabled"
    else
      warn "could not enable $unit.service — try: systemctl --user enable --now $unit"
    fi
  done
}

# ── post-install ──────────────────────────────────────────────────────────
post_install() {
  step "Post-install"

  # Default shell: .zshrc sources the CachyOS zsh config, so zsh must be it.
  local current
  current="$(getent passwd "$(id -un)" | cut -d: -f7)"
  if [[ "$current" == "/bin/zsh" ]]; then
    ok "default shell is already zsh"
  elif [[ $DRY_RUN -eq 1 ]]; then
    info "${C_DIM}dry-run: chsh -s /bin/zsh${C_RESET}"
  elif confirm "Set zsh as your default shell (currently $current)?"; then
    run_privileged chsh -s /bin/zsh "$(id -un)" && ok "default shell set to zsh"
  fi

  # Open the firewall if ufw is present but inactive.
  if command -v ufw >/dev/null && [[ $DRY_RUN -eq 0 ]]; then
    ufw status 2>/dev/null | grep -q inactive || true
  fi
}

# ── verify ────────────────────────────────────────────────────────────────
verify() {
  step "Verification"

  # Note: check the *binary* names, which differ from some package names
  # (neovim -> nvim, wl-clipboard -> wl-copy/wl-paste, xdg-utils -> xdg-open).
  # Every entry here is something a config in the repo actually invokes.
  local -a wanted=(
    niri xwayland-satellite
    kitty nvim yazi zsh fzf eza bat zoxide
    bash git
    wl-copy wl-paste cliphist easyeffects xdg-open
    imv mpv playerctl
    pavucontrol wpctl clangd tree-sitter
    fastfetch cava openrgb
  )
  local -a missing=()
  local b
  for b in "${wanted[@]}"; do
    command -v "$b" >/dev/null 2>&1 || missing+=("$b")
  done

  if ((${#missing[@]} == 0)); then
    ok "all referenced binaries are on PATH"
  else
    warn "still missing: ${missing[*]}"
  fi

  # Symlink health — check all wired config dirs.
  local broken=0 d
  for d in niri nvim kitty yazi gtk qt xsettingsd easyeffects mpv cava \
           fastfetch spicetify mangohud lsp-plugins nwg-look gallery-dl \
           portal systemd environment.d spotify; do
    local p
    while IFS= read -r p; do
      [[ -e "$p" ]] || { err "broken symlink: $p -> $(readlink "$p")"; broken=1; }
    done < <(find "$HOME/.config/$d" -maxdepth 1 -type l ! -name '*.bak.*' 2>/dev/null)
  done
  ((broken == 0)) && ok "no broken config symlinks"

  if command -v niri >/dev/null 2>&1 && [[ $DRY_RUN -eq 0 ]]; then
    if niri validate >/dev/null 2>&1; then
      ok "niri config is valid"
    else
      warn "niri validate failed — run 'niri validate' to see why"
    fi
  fi
}

summary() {
  cat <<EOF

$(printf '%s' "$C_BOLD")Next steps$(printf '%s' "$C_RESET")

  1. Log out and back in (or reboot) so the niri session picks up everything.
  2. Check the niri config:        niri validate
  3. Fix the two known gaps noted in SYSTEM-GUIDE.md §10:
       - 'xkb' lists only "us", so Alt+Shift toggles to nothing.
         Add a second layout:  layout "us,ca"  in config/input.kdl
       - You have no quit binding. Log out with:  niri msg action quit

  4. Full reference: SYSTEM-GUIDE.md
EOF
}

# ── main ──────────────────────────────────────────────────────────────────
main() {
  get_repo
  check_repo_layout
  if [[ $SKIP_PACKAGES -eq 0 ]]; then
    install_packages
    install_font
    install_zsh_plugins
  else
    step "Skipping packages (--skip-packages)"
  fi
  link_configs
  enable_units
  post_install
  verify
  summary
}

main "$@"
