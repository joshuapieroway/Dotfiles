# System Guide

A reference for this machine: what is installed, how it is wired together, and how to
drive it. Written against the live system, not from memory.

- **User:** Joshua Pieroway (`delta`)
- **Base:** CachyOS (Arch), Wayland-only, kernel 7.2.8-arch1-2
- **Dotfiles:** `~/Dotfiles` → <https://github.com/joshuapieroway/Dotfiles>
- **Last verified:** 2026-10-12

---

## Table of contents

1. [At a glance](#1-at-a-glance)
2. [How the dotfiles are wired](#2-how-the-dotfiles-are-wired)
3. [Niri — Wayland compositor](#3-niri--wayland-compositor)
4. [Zsh + Powerlevel10k + zoxide](#4-zsh--powerlevel10k--zoxide)
5. [Neovim](#5-neovim)
6. [Kitty](#6-kitty)
7. [Yazi](#7-yazi)
8. [Theming — GTK / Qt / xsettingsd](#8-theming--gtk--qt--xsettingsd)
9. [Audio — PipeWire + EasyEffects](#9-audio--pipewire--easyeffects)
10. [Session utilities](#10-session-utilities)
11. [Other software](#11-other-software)
12. [Gotchas and traps](#12-gotchas-and-traps)
13. [Quick reference card](#13-quick-reference-card)

---

## 1. At a glance

| Component | Version | Notes |
|---|---|---|
| Niri | 26.04 (`8ed0da4`) | Scrollable-tiling Wayland compositor |
| Kitty | 0.49.1 | Terminal. `Mod+Return` |
| Neovim | 0.12.5 | LazyVim-style *minimal custom* config — **not** LazyVim itself |
| Zsh | 5.9.2 | CachyOS config + Powerlevel10k |
| Yazi | 26.9.1 | File manager, `Mod+F` |
| zoxide | 0.10.0 | Directory jumper |
| fzf | 0.74.4 | Fuzzy finder |
| eza | — | `ls` replacement |
| bat | 0.26.1 | `cat` replacement |
| EasyEffects | — | PipeWire audio FX (equalizer) |
| Cava | — | Terminal audio visualizer |
| Monitor | DP-2 | 2560x1440 @ 165.006 Hz, scale 1.0 |

Toolchain present: `clangd`, `gcc`, `g++`, `mpv`, `imv`, `playerctl`, `easyeffects`,
`jq`, `gh`, `fd`, `ripgrep`.

---

## 2. How the dotfiles are wired

**Everything is symlinked.** There are no copies and nothing to re-sync — every live config
file is a symlink pointing straight into `~/Dotfiles`. Edit the repo and the running system
sees the change.

```
~/Dotfiles/
├── zsh/.zshrc                 -> ~/.zshrc                        SYMLINK
├── zsh/.p10k.zsh              -> ~/.p10k.zsh                     SYMLINK
├── zsh/.zshenv                -> ~/.zshenv                       SYMLINK
├── niri/.config/niri/         -> ~/.config/niri/                 SYMLINK
├── nvim/.config/nvim/         -> ~/.config/nvim/                 SYMLINK
├── kitty/.config/kitty/       -> ~/.config/kitty/                SYMLINK
├── yazi/.config/yazi/         -> ~/.config/yazi/                 SYMLINK
├── gtk/.gtkrc-2.0             -> ~/.gtkrc-2.0                    SYMLINK
├── gtk/.config/gtk-3.0/       -> ~/.config/gtk-3.0/              SYMLINK
├── gtk/.config/gtk-4.0/       -> ~/.config/gtk-4.0/              SYMLINK
├── qt/.config/qt5ct/          -> ~/.config/qt5ct/                SYMLINK
├── qt/.config/qt6ct/          -> ~/.config/qt6ct/                SYMLINK
├── xsettingsd/.config/        -> ~/.config/xsettingsd/           SYMLINK
├── easyeffects/.config/       -> ~/.config/easyeffects/          SYMLINK
├── mpv/.config/mpv/           -> ~/.config/mpv/                  SYMLINK
├── cava/.config/cava/         -> ~/.config/cava/                 SYMLINK
├── fastfetch/.config/         -> ~/.config/fastfetch/            SYMLINK
├── spicetify/.config/         -> ~/.config/spicetify/            SYMLINK
├── mangohud/.config/          -> ~/.config/MangoHud/             SYMLINK
├── lsp-plugins/.config/       -> ~/.config/lsp-plugins/          SYMLINK
├── nwg-look/.config/          -> ~/.config/nwg-look/             SYMLINK
├── gallery-dl/.config/        -> ~/.config/gallery-dl/           SYMLINK
├── portal/.config/            -> ~/.config/xdg-desktop-portal/   SYMLINK
├── systemd/.config/           -> ~/.config/systemd/              SYMLINK
├── environment.d/.config/     -> ~/.config/environment.d/        SYMLINK
├── mimeapps/.config/          -> ~/.config/mimeapps.list         SYMLINK
├── user-dirs/.config/         -> ~/.config/user-dirs.dirs        SYMLINK
├── spotify/.config/           -> ~/.config/spotify-flags.conf    SYMLINK
├── bin/.local/bin/            -> ~/.local/bin/                   SYMLINK
└── applications/.local/       -> ~/.local/share/applications/    SYMLINK
```

**Consequence:** there is no `rsync` step. Edit `~/Dotfiles/niri/.config/niri/config.kdl` and
niri has already read the new bytes by the time you save.

### What has to happen after an edit

Only the *consumers* need poking — the files themselves are already live:

```bash
# niri: nothing at all. It live-reloads on save (no restart, no load-config-file).
# kitty: no reload keybinding by default; it reads kitty.conf at startup.
# nvim:  nothing. Config is re-sourced on the next start; plugins hot-reload.
source ~/.zshrc       # the only thing that needs an explicit action
```

### Validate before reloading

```bash
niri validate                    # niri config  -> "config is valid"
nvim --headless -c 'qa'          # nvim config (will surface Lua errors)
```

---

## 3. Niri — Wayland compositor

Config root: `~/.config/niri/config.kdl`, which is only an `include` manifest:

```kdl
include "config/env.kdl"          // XDG vars, xwayland-satellite
include "config/input.kdl"        // keyboard layout, touchpad
include "config/output.kdl"       // monitor DP-2
include "config/layout.kdl"       // gaps, borders
include "config/autostart.kdl"    // cliphist, easyeffects, xwayland-satellite
include "config/keybinds.kdl"     // all your bindings
include "config/window-rules.kdl" // floating rules, corner radius
```

### 3.1 Core concepts

Niri is **scrollable-tiling**: columns scroll horizontally as a strip, and each column
stacks its windows vertically. There is no manual "tiling" mode to enter — the whole
desktop is one continuous strip. `Mod+Left`/`Mod+Right` move between columns;
`Mod+Up`/`Mod+Down` move within a column and spill onto the next workspace at the edges.

`Mod` = **Super** on a TTY, **Alt** when niri runs as a window. You are on a TTY, so it is
the Windows/Super key.

### 3.2 Keybindings

#### Launching things

| Binding | Action |
|---|---|
| `Mod+Return` | Kitty (terminal) |
| `Mod+B` | LibreWolf |
| `Mod+F` | Kitty running `Yazi` |
| `Mod+O` | Kitty running `opencode` |
| `Mod+Q` | GNOME Calculator |
| `Ctrl+Shift+Escape` | Toggle htop floating window |

#### Window management

| Binding | Action |
|---|---|
| `Mod+W` | Close window |
| `Mod+V` | Toggle floating / tiling |
| `Mod+Shift+F` | Fullscreen |
| `Mod+T` | Maximize column |
| `Mod+X` | Cycle preset column width (1/3 → 1/2 → 2/3) |
| `Mod+Backspace` | Toggle overview |
| `Mod+Left` / `Mod+Right` | Focus column left / right |
| `Mod+Up` / `Mod+Down` | Focus window up / down |
| `Mod+Shift+Left` / `Right` | Move column left / right |
| `Mod+Shift+Up` / `Down` | Move column to workspace up / down |
| `Mod+Ctrl+Left` / `Right` | Resize column −5% / +5% |
| `Mod+Ctrl+Up` / `Down` | Resize window height −5% / +5% |

#### Media keys

| Binding | Action |
|---|---|
| `XF86AudioPlay` / `Pause` | Play / pause (playerctl) |
| `XF86AudioPrev` / `Next` | Previous / next track |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle mic mute |
| `XF86AudioLower` / `Raise` | Volume down / up |
| `XF86MonBrightnessUp` / `Down` | Brightness up / down |

### 3.3 Niri's default keybindings are NOT active

This trips people up, so it is worth stating plainly. From the niri documentation:

> A notable exception is `binds {}`: they do not get filled with defaults, so make sure you
> do not erase this section.

Your `binds {}` in `config/keybinds.kdl` is the **complete and only** set of bindings. There
is no default layer underneath it. Every niri default keybinding you did not explicitly
redeclare simply does not exist on this system.

> **You have no quit binding.** niri's defaults put `quit` on `Mod+Shift+E` and
> `Ctrl+Alt+Delete`, but your `binds {}` replaces the defaults entirely. To log out, run
> `niri msg action quit`. Consider adding a binding.

### 3.4 Visual configuration

**Layout** (`config/layout.kdl`): 5px gaps, borders off, focus ring off, `prefer-no-csd`.
Window rules set 10px corner radius with `clip-to-geometry`, and match `mpv`, `imv`,
`gnome-calculator`, and `nautilus` as floating.

### 3.5 Autostart

```bash
wl-paste --type text  --watch cliphist store   # clipboard text
wl-paste --type image --watch cliphist store   # clipboard images
systemctl --user enable --now easyeffects       # audio effects
xwayland-satellite                              # XWayland for X11 apps
```

### 3.6 Environment

`config/env.kdl` sets:
- `NIXOS_OZONE_WL=1` — Wayland for Electron apps
- `XDG_CURRENT_DESKTOP=Niri`, `XDG_SESSION_TYPE=wayland`, `XDG_SESSION_DESKTOP=Niri`
- `QT_QPA_PLATFORMTHEME=qt6ct` — Qt theme via qt6ct
- `QS_ICON_THEME=Papirus-Dark`
- `xwayland-satellite` path

`~/.config/environment.d/electron-wayland.conf` sets `ELECTRON_OZONE_PLATFORM_HINT=wayland`
for Electron apps system-wide.

### 3.7 CLI

```bash
niri msg outputs                  # monitors and modes
niri msg workspaces               # workspace contents
niri msg windows                  # all windows
niri msg action focus-column-right
niri msg action load-config-file  # hot-reload config.kdl
niri validate                     # check config, non-destructively
```

---

## 4. Zsh + Powerlevel10k + zoxide

`.zshrc` is a symlink to `~/Dotfiles/zsh/.zshrc` — edit it directly and `source ~/.zshrc`.

### 4.1 Load order

1. `fastfetch` (system info on shell start)
2. Powerlevel10k **instant prompt** (must be first — it repaints fast)
3. CachyOS oh-my-zsh config from `/usr/share/cachyos-zsh-config/cachyos-config.zsh`
4. `dircolors` for directory colors
5. `compinit` + completion styling
6. fzf key-bindings and completion
7. `zoxide init zsh`
8. eza / bat aliases
9. History configuration
10. `zsh-autosuggestions` + `zsh-syntax-highlighting` (cloned to `~/.zsh/`)
11. `~/.p10k.zsh` (symlinked from the repo)
12. PATH additions

### 4.2 zoxide

zoxide learns the directories you actually visit and ranks them by frequency.

```bash
z <name>          # jump to the best match, e.g. z nvim
z foo ~/bar       # jump to best match, preferring ~/bar
zi <name>         # interactive fuzzy selector (fzf UI)
z ..              # jump to parent
z -               # jump to previous directory
z <TAB>           # complete a partial name
```

### 4.3 Aliases

```bash
ls    # eza --color=auto --group-directories-first
ll    # long + header + git status
la    # long + all (incl. dotfiles) + git
l     # la + tree, 2 levels deep
cat   # bat --paging=never --style=plain
```

### 4.4 History

```bash
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt EXTENDED_HISTORY SHARE_HISTORY INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_FIND_NO_DUPS HIST_REDUCE_BLANKS
```

### 4.5 Custom functions

- `q()` — one-shot opencode task via the `quick` agent
- `stc()` — SillyTavern context handoff: summarize the latest chat for a character into a
  pasteable prompt

### 4.6 Prompt

Powerlevel10k, `nerdfont-complete` mode, with the instant prompt enabled. To reconfigure
interactively:

```bash
p10k configure
```

The generated file is `~/.p10k.zsh`, which is a symlink into the repo — so run
`p10k configure`, then copy the result back:

```bash
cp ~/.p10k.zsh ~/Dotfiles/zsh/.p10k.zsh
```

### 4.7 PATH

```bash
export PATH=/home/delta/.opencode/bin:$PATH
export PATH=$PATH:/home/delta/.spicetify
export PATH="/home/delta/.local/bin:$PATH"
```

`~/.local/bin` is where the custom scripts live (`rgb-off`, `toggle-gtop`, `sillytavern`,
`gallery-dl-*`, `gdltui`).

---

## 5. Neovim

Config: `~/.config/nvim/init.lua`, which is a **symlink** to
`~/Dotfiles/nvim/.config/nvim/init.lua` — edit the repo file and nvim sees it.

This is a **hand-rolled minimal config**, not LazyVim. There is no telescope, no
fzf-native, no gitsigns, no which-key, no noice. The file is self-contained, which makes it
easy to read end to end.

### 5.1 Essentials

**Leader is `<Space>`.**

| Mapping | Action |
|---|---|
| `<Space>e` | Open file explorer (`:Cd` — changes directory *and* opens Oil) |
| `<Space>r` | Compile **and run** the current C/C++ file |
| `<Space>w` | Toggle soft-wrap (sticks across window splits) |
| `-` | Open the parent directory in Oil |

### 5.2 Commands

| Command | Action |
|---|---|
| `:Cd` | Change to current directory and open explorer |
| `:Cd ../other` | Change to `../other` (relative paths work) and open explorer |
| `:Cd <TAB>` | Tab-completes directories |
| `:Lazy` | Plugin manager UI |
| `:Mason` | LSP server installer UI |
| `:TSUpdate` | Update Tree-sitter parsers |
| `:checkhealth` | Built-in diagnostics |

### 5.3 Editor options

| Option | Value |
|---|---|
| `number`, `relativenumber` | both on |
| `mouse` | `a` |
| `ignorecase` + `smartcase` | case-insensitive unless you type a capital |
| `splitright`, `splitbelow` | splits go right and below |
| `signcolumn` | `yes` (always reserved) |
| `expandtab`, `tabstop`/`shiftwidth`/`softtabstop` | 4 |
| `winborder` | `rounded` |
| `termguicolors` | on |
| `updatetime` | 250 ms |
| `completeopt` | `menu,menuone,noselect` |

### 5.4 No colourscheme — this is intentional

There is no `colorscheme` call. Instead these groups are forced to `bg = "none"`:

`Normal`, `NormalNC`, `NormalFloat`, `FloatBorder`, `SignColumn`, `EndOfBuffer`

The effect: Neovim inherits kitty's palette exactly, so the terminal and the editor are
one continuous colour scheme.

### 5.5 Diagnostics

```lua
float = { border = "rounded", source = "always" }
virtual_text = { prefix = "●", spacing = 2 }
signs = true, underline = true
update_in_insert = false     -- don't re-lint while you type
severity_sort = true         -- errors float above warnings
```

### 5.6 Plugins

| Plugin | Role |
|---|---|
| `lazy.nvim` | Plugin manager, pinned by `lazy-lock.json` |
| `alpha-nvim` | Dashboard |
| `lualine.nvim` | Status line |
| `nvim-cmp` | Completion engine |
| `cmp-nvim-lsp` | LSP completion source |
| `cmp-buffer` | Words from the current buffer |
| `cmp-path` | Filesystem paths |
| `nvim-autopairs` | Bracket/quote auto-pairing |
| `oil.nvim` | File explorer |
| `nvim-treesitter` | Syntax parsing |
| `mason.nvim` | LSP server installer |
| `nvim-web-devicons` | File-type icons |
| `markview.nvim` | Markdown rendering |

### 5.7 Completion (nvim-cmp)

| Key | Action |
|---|---|
| `<C-Space>` | Open completion menu |
| `<C-n>` / `<C-p>` | Next / previous item |
| `<C-y>` or `<CR>` | Confirm and accept the selected item |
| `<C-e>` | Close the menu |
| `<Tab>` / `<S-Tab>` | Cycle items |
| `<C-c>` | Abort |

Sources: `nvim_lsp`, `path`, `buffer`.

### 5.8 Status line (lualine)

```
mode │ branch │ filename ● │                    diagnostics │ filetype │ location
```

- Mode is abbreviated to a single character (`N`, `I`, `V`, …)
- `globalstatus` is on, so one status line spans every window

### 5.9 Oil — the file explorer

Bound to `<Space>e` (via `:Cd`) and `-` for the parent directory. Hidden files are shown.
`q` closes it.

### 5.10 C/C++ workflow

`<Space>r` is the one genuinely custom piece:

1. Refuses to run unless the filetype is `c` or `cpp`
2. `:write`, then compiles:
   - **C++** → `g++ -Wall -Wextra -std=c++23 -O2 -o <basename> <file>`
   - **C** → `gcc -Wall -Wextra -std=c17 -O2 -o <basename> <file>`
3. **On success:** opens a `botright split`, resized to 12 lines, running the binary
4. **On failure:** fills the quickfix list with the compiler output and `:copen`s it

### 5.11 Language server

Only **clangd** is configured, using Neovim's native `vim.lsp` API (no nvim-lspconfig):

```lua
clangd --background-index --clang-tidy --completion-style=detailed
       --header-insertion=iwyu --suggest-missing-includes -j=4
```

### 5.12 Tree-sitter

Configured with `lazy = false` and `build = ":TSUpdate"`, and a `FileType` autocmd that
calls `vim.treesitter.start()` per buffer.

Intended parsers: `bash c cpp css dockerfile go html java javascript json lua markdown
python rust sql toml typescript vim vimdoc xml yaml`.

> These require the `tree-sitter` CLI (`tree-sitter-cli` package). The installer handles it.

### 5.13 Reading markdown (markview)

`OXY2DEV/markview.nvim`, loaded on `ft = { "markdown", "rmd", "quarto" }`. It renders the
markup in place so notes read as prose.

`<Space>w` toggles soft-wrap and records the choice in `b:prose_wrap_manual`.

---

## 6. Kitty

Config: `~/.config/kitty/kitty.conf`.

| Setting | Value |
|---|---|
| Font | JetBrains Mono, 16.0 |
| Symbol map | U+EFC5 → Iosevka Nerd Font |
| Bold / italic / bold-italic | `auto` |
| Cursor trail | 25ms threshold, 0.08/0.35s decay, color `none` (inherits cursor colour) |
| Custom shaders | `theme-lightning` (in `shaders/`) |
| Background opacity | 1.0 |
| Window padding | 4 |
| Scrollback | 2000 lines |
| Decorations | hidden |
| Close confirmation | disabled |
| Audio bell | disabled |

### 6.1 Cursor trail shader

`shaders/theme-lightning.slang` + `.pipeline` — kitty's stock lightning shader, with the
hardcoded orange/red swapped for the live theme colour, so the bolt always matches the
palette.

### 6.2 Colours

`kitty.conf` ends with `include ~/.config/kitty/colors.conf`. The colours are currently a
warm dark palette (matugen-generated from the wallpaper). The file is a static snapshot —
edit it to change colours, or regenerate with matugen.

---

## 7. Yazi

Config: `~/.config/yazi/yazi.toml`. Launch with `Mod+F` (inside Kitty).

### 7.1 Settings

- Hidden files shown
- Natural sort order (so `file2` precedes `file10`)
- Directories listed first

### 7.2 Openers

| Type | Opener |
|---|---|
| Text | `nvim` (blocking) |
| Images | `imv` (orphaned) |
| Video | `mpv` (orphaned) |
| Audio | `mpv` (orphaned) |

Because the media openers are `orphan = true`, Yazi remains responsive while `mpv`/`imv`
runs.

### 7.3 Git integration

The bundled `git.yazi` plugin is used, with `prepend_fetchers` that shell out to `git` for
any URL. This gives file-status indicators in the listing for git repositories.

---

## 8. Theming — GTK / Qt / xsettingsd

### 8.1 GTK

`~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini`:
- Theme: `adw-gtk3` (libadwaita + adw-gtk3 for GTK3 compatibility)
- Icons: Adwaita
- Font: Adwaita Sans 11
- Cursor: Adwaita, size 24
- Dark theme preferred

`~/.config/gtk-4.0/gtk.css` and `gtk-dark.css` both import `libadwaita.css` and
`libadwaita-tweaks.css`.

`~/.gtkrc-2.0` is managed by nwg-look and mirrors the GTK3 settings.

### 8.2 Qt

`~/.config/qt5ct/qt5ct.conf` and `~/.config/qt6ct/qt6ct.conf`:
- Style: Fusion
- Color scheme: `/usr/share/qt5ct/colors/darker.conf` / qt6ct equivalent
- Standard dialogs: xdgdesktopportal

### 8.3 xsettingsd

`~/.config/xsettingsd/xsettingsd.conf` propagates theme settings to XWayland apps:
- Theme: adw-gtk3
- Icons: Adwaita
- Cursor: Adwaita
- Antialiasing/hinting enabled

### 8.4 Fonts

- **JetBrains Mono** — kitty terminal font
- **Iosevka Nerd Font** — symbol map in kitty
- **Noto Sans / Noto CJK / Noto Emoji** — system fallback fonts
- **Font Awesome** (otf + woff2) — icon font
- **awesome-terminal-fonts** — additional glyphs

---

## 9. Audio — PipeWire + EasyEffects

### 9.1 PipeWire

Standard Arch PipeWire setup:
- `pipewire` — server
- `pipewire-pulse` — PulseAudio compatibility
- `pipewire-alsa` — ALSA compatibility
- `pipewire-jack` — JACK compatibility (skipped if jack2 is installed)
- `wireplumber` — session manager
- `pavucontrol` — volume control GUI

### 9.2 EasyEffects

Equalizer preset loaded on startup. The equalizer config is in
`~/.config/easyeffects/db/equalizerrc` — a 31-band EQ with a custom curve.

The `easyeffects` user service is enabled by niri's `autostart.kdl` on every login.

### 9.3 Cava

Terminal audio visualizer. Config in `~/.config/cava/config` with a warm gradient
(`#ffb77a` → `#6b3a05` → `#88511d`). Custom shaders in `shaders/`, themes in `themes/`.

---

## 10. Session utilities

### 10.1 Clipboard

`wl-paste --watch cliphist store` (text and image) started by niri autostart.

### 10.2 OpenRGB

`openrgb.service` — starts the OpenRGB server and runs `rgb-off` to force all RGB devices
to black/off. The `rgb-off` script targets devices by name (MSI motherboard, Corsair RAM,
Corsair iCUE hub, Gigabyte GPU, Razer peripherals).

### 10.3 Arknights gallery

`arknights-gallery.service` — a local web server (port 8080) that serves a browsable
gallery of downloaded Arknights art. Hardened with `ProtectSystem=strict`,
`NoNewPrivileges`, `MemoryMax=2G`, `CPUWeight=20`.

### 10.4 xdg-desktop-portal

`niri-portals.conf` selects backends:
- Default: gnome, gtk, wlr
- Access: gtk
- Notification: gtk
- Secret: gnome-keyring
- Screenshot: wlr
- ScreenCast: wlr

### 10.5 Custom scripts (`~/.local/bin`)

| Script | Purpose |
|---|---|
| `rgb-off` | Force all RGB devices to black/off |
| `toggle-gtop` | Toggle htop floating window (spawn/focus/close) |
| `sillytavern` | Launch SillyTavern (node server + browser) |
| `gallery-dl-launch` | Launch gdltui |
| `gallery-dl-dispatch` | Dispatch queued downloads |
| `gdltui` | Booru downloader TUI |

---

## 11. Other software

| Category | Software |
|---|---|
| Browser | LibreWolf |
| Music | Spotify (via spotify-launcher), librespot |
| Video | Kdenlive |
| Notes | Obsidian |
| Archive | Ark |
| Gaming | PrismLauncher, gamemode, MangoHud, protonup-qt |
| Dev | Docker, Node.js, OpenJDK 17, clangd |
| File management | Nautilus, yazi |
| Media | mpv, imv |
| Communication | Vesktop (Discord) |
| Recorder | wf-recorder, gpu-screen-recorder, OBS |
| Screenshot | satty, grim, slurp |

---

## 12. Gotchas and traps

1. **Niri's default keybindings do not exist on this system.** Only what is in
   `config/keybinds.kdl` is bound — niri does not merge a default `binds` layer. Most
   consequentially you have **no quit binding** (use `niri msg action quit`).

2. **`xkb` lists only `"us"`.** `options "grp:alt_shift_toggle"` sets up a group toggle with
   no second group to toggle to, so `Alt+Shift` currently does nothing. To make it work:
   `layout "us,ca"`, then `Alt+Shift`.

3. **`tree-sitter` CLI** is needed for the full parser list in nvim. Install
   `tree-sitter-cli` (the installer handles it) and run `:TSUpdate`.

4. **`cat` is `bat` with paging disabled.** Piping works, but `bat` will not page. Call
   `bat` directly if you want the pager.

5. **Aliases are not expanded in non-interactive shells.** Scripts, cron jobs and `sh -c`
   get real `ls`/`cat`. Use `eza`/`bat` explicitly there.

6. **Kitty is the only terminal configured.** `Mod+Return` opens kitty. The terminal
   colours (and thus the Neovim colours, which inherit them) come from
   `~/.config/kitty/colors.conf`.

7. **`~/.p10k.zsh` is a symlink into the repo**, so `p10k configure` writes through to your
   git working tree. That is intentional, but it will show up as a diff.

8. **zsh plugins are git clones**, not pacman packages. `zsh-autosuggestions` and
   `zsh-syntax-highlighting` live in `~/.zsh/`. The installer clones them.

9. **The `rgb-off` script targets specific hardware.** It knows about MSI B550-VC, Corsair
   Vengeance RGB Pro, Corsair iCUE LINK, Gigabyte RX 7600 XT, and Razer peripherals. On
   different hardware it will skip devices it doesn't recognize.

10. **EasyEffects config has device-specific paths.** `~/.config/easyeffects/db/easyeffectsrc`
    references specific ALSA device names (e.g., `alsa_input.usb-Generic_Razer_Seiren_V3...`).
    On different hardware these won't match.

11. **Spotify runs as a native Wayland client** via `spotify-flags.conf`
    (`--ozone-platform=wayland`). This is needed for window transparency and niri blur.

---

## 13. Quick reference card

```
LAUNCH      Mod+Return kitty      Mod+F yazi
            Mod+B librewolf       Mod+O opencode
            Mod+Q calculator      Ctrl+Shift+Esc htop

WINDOW      Mod+W close           Mod+V float          Mod+Shift+F fullscreen
            Mod+T max column      Mod+X preset width   Mod+Backspace overview

NAVIGATE    Mod+Left/Right column Mod+Up/Down window
MOVE        Mod+Shift+Left/Right  Mod+Shift+Up/Down to ws
RESIZE      Mod+Ctrl+Left/Right   Mod+Ctrl+Up/Down

MEDIA       XF86AudioPlay/Pause   XF86AudioPrev/Next
            XF86AudioMute         XF86AudioMicMute
            XF86AudioLower/Raise   XF86MonBrightnessUp/Down

SYSTEM      niri msg action quit  (no quit keybound — see §3.3)
```

```
SHELL       z foo      jump        zi        interactive picker
            z --clean  purge dead entries
            ll / la    git-aware listings
            cat        bat (no paging)

NVIM        <Space>e   explorer    -         parent dir
            <Space>r   compile+run C/C++
            :Cd ../x    change dir + explorer
            <C-Space>  completion  <C-y> accept
            :Lazy :Mason :TSUpdate

FILES       Mod+F yazi            q quit   / filter   . hidden
```

---

## Maintenance

```bash
# Update everything
sudo pacman -Syu

# Update dotfiles
cd ~/Dotfiles && git pull

# Update nvim plugins
nvim -c 'Lazy update' -c 'qa'

# Validate niri config
niri validate
```
