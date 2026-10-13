# Dotfiles

Everything needed to replicate this system: compositor, terminal, shell, editor,
file manager, theming, audio, session utilities, and the scripts that tie them
together.

## Install

```bash
git clone https://github.com/joshuapieroway/Dotfiles
cd Dotfiles/
chmod +x install.sh
./install.sh
```

The installer is idempotent — safe to re-run. It installs packages, fonts, and
zsh plugins, then symlinks every config into place. See `install.sh --help` for
options (`--dry-run`, `--skip-packages`, `--no-aur`).

## Layout

```
Dotfiles/
├── install.sh              # bootstrap script
├── README.md               # this file
├── SYSTEM-GUIDE.md         # full reference
├── zsh/                    # .zshrc, .p10k.zsh, .zshenv
├── niri/                   # compositor config
├── nvim/                   # editor config
├── kitty/                  # terminal config + shaders
├── yazi/                   # file manager config
├── gtk/                    # GTK 3/4 settings + .gtkrc-2.0
├── qt/                     # Qt5/Qt6 settings
├── xsettingsd/             # X settings daemon config
├── mimeapps/               # default applications
├── user-dirs/              # XDG user directories
├── applications/           # .desktop files
├── easyeffects/            # audio FX presets
├── mpv/                    # media player config
├── cava/                   # audio visualizer config + shaders
├── fastfetch/              # system info display config
├── spicetify/              # Spotify theme
├── mangohud/               # GPU overlay config
├── lsp-plugins/            # audio plugin config
├── nwg-look/               # GTK theme exporter config
├── gallery-dl/             # image downloader config
├── portal/                 # xdg-desktop-portal config
├── systemd/                # user units (openrgb, arknights-gallery)
├── environment.d/          # environment variables
├── bin/                    # custom scripts
└── spotify/                 # Spotify flags
```

## After installing

Log out and back in (or reboot), then:

```bash
niri validate              # check compositor config
```

See **SYSTEM-GUIDE.md** for the full reference: keybindings, gotchas, and how
everything fits together.
