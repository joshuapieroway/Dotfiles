#!/usr/bin/env bash
#
# install.sh — bootstrap a CachyOS/Arch machine to match this dotfiles repo.
#
# Installs every package the configs actually reference, drops the Maple Mono
# NF font kitty.conf asks for, clones the repo if it is missing, and wires
# ~/.config/{niri,nvim,kitty,yazi} up as symlinks into the repo so edits are
# live (no rsync step).
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
#
# Deliberately NOT installed, because no config references them — add them by
# hand if you want them:
#   browsers      brave / firefox        (keybinds.kdl:3 spawns "brave-origin",
#                                        which no Arch package ships anyway)
#   gaming        steam lutris prismlauncher mangohud gamescope, and the
#                 32-bit lib32-* Vulkan/Mesa drivers that only exist for
#                 Proton. The niri window rules for these are inert matchers;
#                 they cost nothing if you install the apps later.
#   media/music   cava                   (audio visualiser)
#   sysinfo       fastfetch btop htop duf
#   misc          ripgrep jq github-cli qt5ct grim slurp wlr-randr
#
# Anything the configs need that is NOT a pacman package (serpantinum,
# brave-origin, flatpak, ~/.local/bin/liked) is reported by verify() instead.

install_packages() {
  step "Installing packages"

  # bash is not implicit here: autostart.kdl spawns it as argv[0] on two lines.
  # curl is what install_font uses to fetch Maple Mono NF.
  install_group "Base toolchain" \
    bash base-devel git curl

  # niri execs xwayland-satellite itself (config/env.kdl), and env.kdl points
  # Qt and GTK at qt6ct and Papirus, so both themes are load-bearing.
  install_group "Compositor and session" \
    niri xwayland-satellite \
    qt6ct papirus-icon-theme

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
  # kitty.conf uses xdg-open for URL hints. All four were referenced but never
  # installed before, so the clipboard and audio FX silently did nothing.
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
}

# ── fonts ─────────────────────────────────────────────────────────────────
# kitty.conf pins "Maple Mono NF Bold", which no Arch package ships.
install_font() {
  step "Installing Maple Mono NF"

  if fc-list 2>/dev/null | grep -qi 'Maple Mono NF'; then
    ok "Maple Mono NF already present"
    return 0
  fi

  local url="https://github.com/subframe7536/maple-font/releases/latest/download/MapleMono-NF-unhinted.zip"
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
    curl -fL --retry 2 --max-time 180 -o "$tmp/maple.zip" "$url" \
      || { warn "font download failed — kitty will fall back to its default face"; return 0; }
  else
    warn "curl missing — skipping font"
    return 0
  fi

  mkdir -p "$fontdir"
  if command -v unzip >/dev/null; then
    unzip -oq "$tmp/maple.zip" -d "$fontdir" || warn "unzip failed"
  else
    warn "unzip missing — install it and re-run, or fetch the font manually"
    return 0
  fi

  command -v fc-cache >/dev/null && fc-cache -f "$fontdir" >/dev/null 2>&1 || true
  ok "Maple Mono NF installed to $fontdir"
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

link_app() {
  local app="$1"
  local src="$REPO_PATH/$app/.config/$app"
  local dst="$HOME/.config/$app"

  if [[ ! -d "$src" ]]; then
    skip "$app — no config in repo, leaving alone"
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

  printf '    %s✓%s %-6s %s\n' "$C_GREEN" "$C_RESET" "$app" \
    "${linked} linked, ${kept} already correct, ${backed} backed up"
  if ((backed > 0)); then
    skip "backups use suffix ${BACKUP_SUFFIX}"
  fi
}

link_configs() {
  step "Wiring configs"
  local app
  for app in niri nvim kitty yazi; do
    link_app "$app"
  done

  # .zshrc and .p10k.zsh live at the top of the repo, not under a .config dir.
  local f
  for f in .zshrc .p10k.zsh; do
    local src="$REPO_PATH/zsh/$f" target="$HOME/$f"
    [[ -f "$src" ]] || { skip "$f — not in repo"; continue; }
    if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$src")" ]]; then
      skip "$f already linked"
    elif [[ $DRY_RUN -eq 1 ]]; then
      info "${C_DIM}dry-run: link $f -> $src${C_RESET}"
    elif [[ -e "$target" ]]; then
      mv "$target" "${target}${BACKUP_SUFFIX}" 2>/dev/null && info "backed up existing $f"
      ln -s "$src" "$target" && ok "linked $f"
    else
      ln -s "$src" "$target" && ok "linked $f"
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

  # autostart.kdl also does this every login, but doing it now means the
  # effects are live without a reboot.
  if command -v systemctl >/dev/null && [[ $DRY_RUN -eq 0 ]]; then
    if systemctl --user enable --now easyeffects >/dev/null 2>&1; then
      ok "easyeffects user service enabled"
    else
      skip "easyeffects will be enabled on next niri login"
    fi
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

  # These are invoked by the configs but are not pacman packages, so this script
  # cannot install them and will not pretend to. Report them separately: a
  # missing one means keybinds silently do nothing at login.
  #   serpantinum  bar/launcher/screenshots/volume + 20 workspace routes
  #                (keybinds.kdl, ~40 spawns) and serpantinumd (autostart.kdl)
  #   brave-origin Mod+B (keybinds.kdl:3) — Arch's brave package ships
  #                "brave", not "brave-origin", so this key is unbacked
  #   flatpak      Mod+O runs `flatpak run ai.opencode.opencode`
  #   liked        Mod+Shift+L runs $HOME/.local/bin/liked
  local -a external=(serpantinum serpantinumd brave-origin liked)
  local -a absent=()
  for b in "${external[@]}"; do
    command -v "$b" >/dev/null 2>&1 || absent+=("$b")
  done
  if ((${#absent[@]})); then
    warn "not on PATH, so those keybinds will do nothing: ${absent[*]}"
    info "see SYSTEM-GUIDE.md for how these are installed"
  else
    ok "external keybind helpers are on PATH"
  fi

  # Symlink health.
  local broken=0 d
  for d in niri nvim kitty yazi; do
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

  $(printf '%s' "$C_DIM")-----------------------------------------------------------------------$(printf '%s' "$C_RESET")
  $(printf '%s' "$C_BOLD")These dotfiles are intended for use with the Serpantinum$(printf '%s' "$C_RESET")
  $(printf '%s' "$C_BOLD")desktop shell — install it or most keybinds do nothing.$(printf '%s' "$C_RESET")
  $(printf '%s' "$C_DIM")-----------------------------------------------------------------------$(printf '%s' "$C_RESET")

  Serpantinum is a Quickshell/QML shell that owns the bar, the app launcher and
  every popout. It is not optional decoration here: almost every binding in
  config/keybinds.kdl is a serpantinum command, not a niri action — the bar,
  Mod+Space, screenshots, volume, lock, and all twenty workspace routes. Skip
  it and you get a bare compositor with keys wired to nothing.

  Install (Arch/CachyOS), from a normal user shell — do NOT run this as root:

      bash -c "\$(curl -fsSL https://raw.githubusercontent.com/ilyamiro/serpantinum/master/install/install.sh)"

  It clones itself to ~/.local/share/serpantinum/src/ and installs serpantinum
  and serpantinumd into ~/.local/bin, which .zshrc already puts on your PATH.
  autostart.kdl starts the daemon for you via "serpantinumd start".
  It clones an AUR helper (paru or yay) if you have none, pulls quickshell,
  and asks before enabling telemetry. Re-run it and choose "update" to upgrade.

  Worth knowing before you run it:
    - Choose niri when it asks which compositor to wire up. Since v2 it leaves
      monitors, keybinds and autostart to you, so it will not fight this repo.
    - An update overwrites the local Bluetooth bar patch — see SYSTEM-GUIDE.md
      §10 and re-apply it, or drop a pristine BtWidget.qml.orig alongside it.
    - It installs its own dependency set, which is a lot larger than the
      trimmed list this script uses, and includes matugen, fastfetch, ripgrep,
      grim, slurp, ffmpeg and nautilus. Those are its requirements, not
      anything the configs here reference.

  Confirm it landed with:  serpantinum -V   and   serpantinumd status

  4. Full reference: SYSTEM-GUIDE.md §4 (Serpantinum) and §10 (gotchas)
EOF
}

# ── main ──────────────────────────────────────────────────────────────────
main() {
  get_repo
  check_repo_layout
  if [[ $SKIP_PACKAGES -eq 0 ]]; then
    install_packages
    install_font
  else
    step "Skipping packages (--skip-packages)"
  fi
  link_configs
  post_install
  verify
  summary
}

main "$@"
