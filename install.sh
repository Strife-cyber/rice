#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Catppuccin Mocha rice for Linux Mint (Cinnamon, X11)
#  Terminal → dev tools → desktop → login & boot, reproducible from scratch.
#
#  Usage:  bash install.sh [options] [phase ...]
#    phases:  packages tools terminal themes dotfiles git runtimes desktop system
#             (default: all, in that order)
#    --no-grub      skip the GRUB theme / boot-menu changes
#    --no-system    skip everything in the "system" phase (login screen, GRUB, helper)
#    --sync         copy your current configs from $HOME back into this repo, then exit
#    -h, --help     show this help
#
#  Safe to re-run: every step checks or overwrites; replaced dotfiles are backed
#  up to ~/.rice-backup/<timestamp>/ first.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

RICE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOT=$RICE/dotfiles
BIN=$HOME/.local/bin
OPT=$HOME/.local/opt
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
BACKUP=$HOME/.rice-backup/$(date +%Y%m%d-%H%M%S)
GTK_THEME=catppuccin-mocha-mauve-standard+default
CURSOR=catppuccin-mocha-dark-cursors
WALLPAPER=shaded_landscape.png
NO_GRUB=0 NO_SYSTEM=0 FAILED=()

# Files shipped in dotfiles/ (paths relative to $HOME)
DOTFILES=(
  .zshrc .tmux.conf
  .config/zsh/aliases.zsh .config/zsh/functions.zsh .config/zsh/quotes.txt
  .config/starship.toml .config/kitty/kitty.conf .config/fastfetch/config.jsonc
  .config/btop/btop.conf .config/atuin/config.toml .config/k9s/config.yaml
  .config/mise/config.toml .config/nvim/lua/plugins/colorscheme.lua
  .config/rofi/config.rasi .config/rofi/themes/catppuccin-mocha.rasi
  .config/eww/eww.yuck .config/eww/eww.scss .config/eww/scripts/net.sh .config/greenclip.toml
  .local/bin/quote .local/bin/rofi-power .local/bin/dashboard
)

# ── helpers ──────────────────────────────────────────────────────────────────
c_m=$'\e[1;38;2;203;166;247m' c_g=$'\e[38;2;166;227;161m' c_r=$'\e[38;2;243;139;168m' c_d=$'\e[38;2;108;112;134m' c_0=$'\e[0m'
phase() { printf '\n%s━━ %s ━━%s\n' "$c_m" "$*" "$c_0"; }
ok()    { printf '  %s✓%s %s\n' "$c_g" "$c_0" "$*"; }
warn()  { printf '  %s✗%s %s\n' "$c_r" "$c_0" "$*"; FAILED+=("$*"); }
info()  { printf '  %s%s%s\n' "$c_d" "$*" "$c_0"; }
have()  { command -v "$1" >/dev/null 2>&1; }

# Latest GitHub release asset URL matching a regex
gh_asset() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    python3 -I -c 'import sys,json,re
r=json.load(sys.stdin); p=re.compile(sys.argv[1],re.I)
m=[a["browser_download_url"] for a in r.get("assets",[]) if p.search(a["name"])]
print(m[0] if m else "")' "$2"
}

# gh_bin NAME REPO REGEX BINARY... — download a release and install its binaries
gh_bin() {
  local name=$1 repo=$2 re=$3; shift 3
  local url; url=$(gh_asset "$repo" "$re")
  [[ -z $url ]] && { warn "$name: no release asset matched"; return; }
  local d=$WORK/$name; mkdir -p "$d/x"; local f=$d/${url##*/}
  curl -fsSL "$url" -o "$f" || { warn "$name: download failed"; return; }
  case $f in
    *.tar.gz|*.tgz) tar -xzf "$f" -C "$d/x" ;;
    *.tar.xz)       tar -xJf "$f" -C "$d/x" ;;
    *.tbz|*.tar.bz2) tar -xjf "$f" -C "$d/x" ;;
    *.zip)          unzip -qo "$f" -d "$d/x" ;;
    *)              cp "$f" "$d/x/$1" ;;
  esac
  local b src
  for b in "$@"; do
    src=$(find "$d/x" -type f -name "$b" | head -1)
    [[ -n $src ]] && install -m755 "$src" "$BIN/$b" || { warn "$name: '$b' not in archive"; return; }
  done
  ok "$name"
}

clone() { # clone URL DEST [ref] — shallow clone, or fast-forward if present
  if [[ -d $2/.git ]]; then git -C "$2" pull -q --ff-only 2>/dev/null || true
  else rm -rf "$2"; git clone -q --depth 1 ${3:+-b "$3"} "$1" "$2"; fi
}

raw() { curl -fsSL "https://raw.githubusercontent.com/$1" -o "$2" --create-dirs || warn "download $1"; }

# ── phases ───────────────────────────────────────────────────────────────────
p_packages() {
  phase "1/9 System packages (sudo)"
  sudo apt-get update -qq
  sudo apt-get install -y \
    zsh tmux git curl unzip xz-utils build-essential xclip ncurses-term figlet python3-venv \
    plank rofi playerctl gir1.2-gtop-2.0 xdotool \
    libgtk-3-dev libgtk-layer-shell-dev libdbusmenu-gtk3-dev pkg-config && ok "apt packages"
  if [[ $(getent passwd "$USER" | cut -d: -f7) != */zsh ]]; then
    chsh -s "$(command -v zsh)" && ok "default shell → zsh"
  else ok "zsh already default shell"; fi
}

p_tools() {
  phase "2/9 CLI tools → ~/.local/bin"
  mkdir -p "$BIN" "$OPT"
  gh_bin starship   starship/starship        'x86_64-unknown-linux-musl\.tar\.gz$' starship
  gh_bin eza        eza-community/eza        '^eza_x86_64-unknown-linux-gnu\.tar\.gz$' eza
  gh_bin bat        sharkdp/bat              'x86_64-unknown-linux-musl\.tar\.gz$' bat
  gh_bin fd         sharkdp/fd               'x86_64-unknown-linux-musl\.tar\.gz$' fd
  gh_bin ripgrep    BurntSushi/ripgrep       'x86_64-unknown-linux-musl\.tar\.gz$' rg
  gh_bin fzf        junegunn/fzf             'linux_amd64\.tar\.gz$' fzf
  gh_bin zoxide     ajeetdsouza/zoxide       'x86_64-unknown-linux-musl\.tar\.gz$' zoxide
  gh_bin delta      dandavison/delta         'x86_64-unknown-linux-musl\.tar\.gz$' delta
  gh_bin lazygit    jesseduffield/lazygit    'linux_x86_64\.tar\.gz$' lazygit
  gh_bin lazydocker jesseduffield/lazydocker 'linux_x86_64\.tar\.gz$' lazydocker
  gh_bin yazi       sxyazi/yazi              'x86_64-unknown-linux-musl\.zip$' yazi ya
  gh_bin btop       aristocratos/btop        '^btop-x86_64-unknown-linux-musl\.tar\.gz$' btop
  gh_bin fastfetch  fastfetch-cli/fastfetch  'linux-amd64\.tar\.gz$' fastfetch
  gh_bin atuin      atuinsh/atuin            '^atuin-x86_64-unknown-linux-musl\.tar\.gz$' atuin
  gh_bin mise       jdx/mise                 'linux-x64-musl\.tar\.gz$' mise
  gh_bin direnv     direnv/direnv            '^direnv\.linux-amd64$' direnv
  gh_bin k9s        derailed/k9s             '^k9s_linux_amd64\.tar\.gz$' k9s
  gh_bin tldr       tealdeer-rs/tealdeer     '^tealdeer-linux-x86_64-musl$' tldr
  gh_bin jq         jqlang/jq                '^jq-linux-amd64$' jq
  gh_bin greenclip  erebe/greenclip          '^greenclip$' greenclip

  local url v
  url=$(gh_asset neovim/neovim '^nvim-linux-x86_64\.tar\.gz$')
  mkdir -p "$WORK/nvim" && curl -fsSL "$url" | tar -xz -C "$WORK/nvim" &&
    rm -rf "$OPT/nvim" && mv "$WORK/nvim/nvim-linux-x86_64" "$OPT/nvim" &&
    ln -sf "$OPT/nvim/bin/nvim" "$BIN/nvim" && ok neovim || warn neovim
  v=$(curl -fsSL https://dl.k8s.io/release/stable.txt) &&
    curl -fsSL "https://dl.k8s.io/release/$v/bin/linux/amd64/kubectl" -o "$BIN/kubectl" &&
    chmod 755 "$BIN/kubectl" && ok "kubectl $v" || warn kubectl
}

p_terminal() {
  phase "3/9 Kitty, fonts, shell & editor plugins"
  local url
  url=$(gh_asset kovidgoyal/kitty '-x86_64\.txz$')
  mkdir -p "$HOME/.local/kitty.app" && curl -fsSL "$url" | tar -xJ -C "$HOME/.local/kitty.app" &&
    ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/kitty.app/bin/kitten" "$BIN/" && ok kitty || warn kitty
  local A=$HOME/.local/share/applications K=$HOME/.local/kitty.app; mkdir -p "$A"
  cp "$K"/share/applications/kitty{,-open}.desktop "$A/"
  sed -i "s|Icon=kitty|Icon=$K/share/icons/hicolor/256x256/apps/kitty.png|g; s|Exec=kitty|Exec=$K/bin/kitty|g" "$A"/kitty*.desktop

  local F=$HOME/.local/share/fonts; mkdir -p "$F/JetBrainsMonoNerd" "$F/Inter"
  curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar -xJ -C "$F/JetBrainsMonoNerd" && ok "JetBrainsMono Nerd Font" || warn "nerd font"
  url=$(gh_asset rsms/inter '^Inter-[0-9.]+\.zip$')
  curl -fsSL "$url" -o "$WORK/inter.zip" && unzip -qo "$WORK/inter.zip" 'InterVariable*.ttf' -d "$F/Inter" && ok "Inter font" || warn "inter font"
  fc-cache -f >/dev/null

  local P=$HOME/.local/share/zsh/plugins r
  for r in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting zsh-users/zsh-completions \
           zsh-users/zsh-history-substring-search Aloxaf/fzf-tab; do clone "https://github.com/$r" "$P/${r#*/}"; done
  clone https://github.com/catppuccin/zsh-syntax-highlighting "$P/catppuccin-zsh-syntax-highlighting"
  ok "zsh plugins"

  local T=$HOME/.tmux/plugins tag
  for r in tmux-plugins/tpm tmux-plugins/tmux-sensible tmux-plugins/tmux-resurrect tmux-plugins/tmux-continuum \
           tmux-plugins/tmux-yank christoomey/vim-tmux-navigator; do clone "https://github.com/$r" "$T/${r#*/}"; done
  tag=$(git ls-remote --tags --refs https://github.com/catppuccin/tmux 'v*' | sed 's#.*refs/tags/##' | sort -V | tail -1)
  rm -rf "$T/catppuccin-tmux"; git -c advice.detachedHead=false clone -q --depth 1 -b "$tag" https://github.com/catppuccin/tmux "$T/catppuccin-tmux"
  ok "tmux plugins (catppuccin $tag)"

  if [[ ! -f $HOME/.config/nvim/lazy-lock.json && ! -f $HOME/.config/nvim/init.lua ]]; then
    git clone -q --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim" && rm -rf "$HOME/.config/nvim/.git" && ok "LazyVim starter"
  else ok "nvim config already present"; fi
}

p_themes() {
  phase "4/9 Catppuccin themes for CLI tools"
  local C=$HOME/.config
  raw catppuccin/kitty/main/themes/mocha.conf                          "$C/kitty/current-theme.conf"
  raw "catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme"          "$C/bat/themes/Catppuccin Mocha.tmTheme"
  raw catppuccin/btop/main/themes/catppuccin_mocha.theme               "$C/btop/themes/catppuccin_mocha.theme"
  raw catppuccin/delta/main/catppuccin.gitconfig                       "$C/delta/catppuccin.gitconfig"
  raw catppuccin/lazygit/main/themes-mergable/mocha/blue.yml           "$C/lazygit/config.yml"
  raw catppuccin/yazi/main/themes/mocha/catppuccin-mocha-blue.toml     "$C/yazi/theme.toml"
  raw "catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme"          "$C/yazi/Catppuccin-mocha.tmTheme"
  raw eza-community/eza-themes/main/themes/catppuccin-mocha.yml        "$C/eza/theme.yml"
  raw catppuccin/k9s/main/dist/catppuccin-mocha.yaml                   "$C/k9s/skins/catppuccin-mocha.yaml"
  raw catppuccin/atuin/main/themes/mocha/catppuccin-mocha-mauve.toml   "$C/atuin/themes/catppuccin-mocha-mauve.toml"
  have bat && bat cache --build >/dev/null 2>&1
  ok "themes for kitty, bat, btop, delta, lazygit, yazi, eza, k9s, atuin"
}

p_dotfiles() {
  phase "5/9 Dotfiles"
  local f dst
  for f in "${DOTFILES[@]}"; do
    dst=$HOME/$f
    if [[ -e $dst ]] && ! cmp -s <(sed "s|@HOME@|$HOME|g" "$DOT/$f") "$dst"; then
      mkdir -p "$BACKUP/$(dirname "$f")"; cp -a "$dst" "$BACKUP/$f"
    fi
    mkdir -p "$(dirname "$dst")"
    sed "s|@HOME@|$HOME|g" "$DOT/$f" > "$dst"
    [[ -x $DOT/$f ]] && chmod +x "$dst"
  done
  ok "${#DOTFILES[@]} files installed"
  [[ -d $BACKUP ]] && info "previous versions backed up to $BACKUP"

  # bash: same banner + quote, guarded so re-runs don't duplicate it
  if ! grep -q 'local/bin/quote' "$HOME/.bashrc" 2>/dev/null; then
    printf '\n# rice: banner + inspiring quote\n[[ $- == *i* && -x $HOME/.local/bin/quote ]] && "$HOME/.local/bin/quote" --banner\n' >> "$HOME/.bashrc"
  fi
  ok "~/.bashrc banner"
}

p_git() {
  phase "6/9 Git (delta pager, sane defaults, aliases)"
  local g="git config --global"
  $g include.path '~/.config/delta/catppuccin.gitconfig'
  $g core.pager delta;                $g interactive.diffFilter 'delta --color-only'
  $g delta.features catppuccin-mocha; $g delta.navigate true; $g delta.line-numbers true
  $g merge.conflictStyle zdiff3;      $g diff.colorMoved default
  $g core.editor nvim;                $g init.defaultBranch main
  $g pull.rebase true;                $g rebase.autoStash true
  $g push.autoSetupRemote true;       $g fetch.prune true;  $g rerere.enabled true
  $g alias.lg "log --graph --pretty=format:'%C(magenta)%h%Creset %s %C(green)(%cr) %C(blue)<%an>%Creset%C(auto)%d' --abbrev-commit"
  $g alias.undo 'reset --soft HEAD~1'
  $g alias.wip '!git add -A && git commit -m wip --no-verify'
  ok "git configured (name/email untouched)"
}

p_runtimes() {
  phase "7/9 Runtimes, Neovim plugins, caches"
  export PATH=$BIN:$HOME/.local/share/mise/shims:$PATH
  mise install -y >/dev/null 2>&1 && ok "mise: $(mise ls --current 2>/dev/null | awk '{print $1"@"$2}' | xargs)" || warn "mise install"
  mise use -g uv@latest >/dev/null 2>&1 && mise use -g pipx:rofimoji@latest >/dev/null 2>&1 && ok "rofimoji (emoji picker)" || warn rofimoji
  eval "$(mise activate bash)"; mise exec -- npm i -g tree-sitter-cli >/dev/null 2>&1 && ok "tree-sitter-cli" || warn "tree-sitter-cli"
  mise exec -- nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 && ok "LazyVim plugins synced" || warn "nvim plugin sync"
  tldr --update >/dev/null 2>&1 && ok "tldr cache"

  # Eww (hover dashboard) has no prebuilt binaries: build v0.6.0 with Rust from mise
  if [[ ! -x $BIN/eww ]]; then
    info "building Eww (one-time, ~5-10 min)…"
    local src=$HOME/.local/src/eww
    mise use -g rust@stable >/dev/null 2>&1 || warn "rust toolchain"
    clone https://github.com/elkowar/eww "$src" v0.6.0
    ( cd "$src" &&
      mise exec rust@stable -- cargo update -p time@0.3.34 >/dev/null 2>&1   # 0.3.34 doesn't build on Rust >= 1.80
      mise exec rust@stable -- cargo build --release --no-default-features --features x11 >"$HOME/.cache/eww-build.log" 2>&1 ) &&
      install -m755 "$src/target/release/eww" "$BIN/eww" && ok "eww built" || warn "eww build (see ~/.cache/eww-build.log)"
  else ok "eww already installed"; fi
  rm -f "$HOME/.config/zsh/completions/"_* # regenerated on next zsh start
}

p_desktop() {
  phase "8/9 Desktop (Cinnamon)"
  [[ ${XDG_CURRENT_DESKTOP:-} == *Cinnamon* ]] || info "not in a Cinnamon session — settings are written but apply at next login"
  local W=$WORK/desk; mkdir -p "$W" "$HOME/.themes" "$HOME/.icons" "$HOME/.local/share/icons"

  # GTK + Cinnamon + Plank theme
  url=$(gh_asset catppuccin/gtk "^${GTK_THEME//+/\\+}\\.zip$")
  curl -fsSL "$url" -o "$W/gtk.zip" && unzip -qo "$W/gtk.zip" -d "$W/gtk" &&
    rm -rf "$HOME/.themes/$GTK_THEME" && cp -r "$W/gtk/$GTK_THEME" "$HOME/.themes/" && ok "GTK theme" || warn "gtk theme"
  mkdir -p "$HOME/.config/gtk-4.0"
  ln -sfn "$HOME/.themes/$GTK_THEME/gtk-4.0/assets" "$HOME/.config/gtk-4.0/assets"
  ln -sf "$HOME/.themes/$GTK_THEME/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
  ln -sf "$HOME/.themes/$GTK_THEME/gtk-4.0/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"

  # Cursor
  url=$(gh_asset catppuccin/cursors "^$CURSOR\\.zip$")
  curl -fsSL "$url" -o "$W/cur.zip" && unzip -qo "$W/cur.zip" -d "$HOME/.icons" && ok cursor || warn cursor
  mkdir -p "$HOME/.icons/default"; printf '[Icon Theme]\nInherits=%s\n' "$CURSOR" > "$HOME/.icons/default/index.theme"

  # Papirus icons + Catppuccin folder colours
  local tag; tag=$(curl -fsSL https://api.github.com/repos/PapirusDevelopmentTeam/papirus-icon-theme/releases/latest | python3 -I -c 'import sys,json;print(json.load(sys.stdin)["tag_name"])')
  mkdir -p "$W/pap" && curl -fsSL "https://github.com/PapirusDevelopmentTeam/papirus-icon-theme/archive/refs/tags/$tag.tar.gz" | tar -xz -C "$W/pap" &&
    for t in Papirus Papirus-Dark; do rm -rf "$HOME/.local/share/icons/$t"; cp -a "$W"/pap/*/"$t" "$HOME/.local/share/icons/"; done && ok "Papirus $tag" || warn papirus
  git clone -q --depth 1 https://github.com/catppuccin/papirus-folders "$W/pf-cat" &&
    git clone -q --depth 1 https://github.com/PapirusDevelopmentTeam/papirus-folders "$W/pf-tool" &&
    cp -r "$W"/pf-cat/src/* "$HOME/.local/share/icons/Papirus/" &&
    install -m755 "$W/pf-tool/papirus-folders" "$BIN/papirus-folders" &&
    "$BIN/papirus-folders" -C cat-mocha-mauve --theme Papirus-Dark >/dev/null && ok "mauve folders" || warn "papirus folders"

  # Wallpapers
  mkdir -p "$HOME/Pictures/Wallpapers"; cp -n "$RICE"/wallpapers/* "$HOME/Pictures/Wallpapers/" 2>/dev/null; ok wallpapers

  # Apply look
  local I=org.cinnamon.desktop.interface
  gsettings set $I gtk-theme "$GTK_THEME"
  gsettings set org.cinnamon.desktop.wm.preferences theme "$GTK_THEME"
  gsettings set org.cinnamon.theme name "$GTK_THEME"
  gsettings set $I icon-theme Papirus-Dark
  gsettings set $I cursor-theme "$CURSOR"; gsettings set $I cursor-size 24
  gsettings set $I font-name 'Inter Variable 10'
  gsettings set org.nemo.desktop font 'Inter Variable 10'
  gsettings set org.cinnamon.desktop.wm.preferences titlebar-font 'Inter Variable Bold 10'
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark
  gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
  gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
  gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR"
  gsettings set org.cinnamon.desktop.background picture-uri "file://$HOME/Pictures/Wallpapers/$WALLPAPER"
  gsettings set org.cinnamon.desktop.background picture-options zoom
  gsettings set org.cinnamon.desktop.default-applications.terminal exec "$BIN/kitty"
  ok "theme, icons, cursor, fonts, wallpaper applied"

  # Panel: one slim vertical bar on the right (Zen keeps its tabs on the left)
  mkdir -p "$RICE/backups"; dconf dump /org/cinnamon/ > "$RICE/backups/cinnamon-$(date +%Y%m%d-%H%M%S).dconf"
  local S=$HOME/.local/share/cinnamon/applets
  mkdir -p "$S" && curl -fsSL https://cinnamon-spices.linuxmint.com/files/applets/sysmonitor@orcus.zip -o "$W/sm.zip" &&
    unzip -qo "$W/sm.zip" -d "$S" && ok "system monitor applet" || warn "sysmonitor applet"
  gsettings set org.cinnamon panels-enabled "['1:0:right']"
  gsettings set org.cinnamon panels-height "['1:42']"
  gsettings set org.cinnamon panel-zone-icon-sizes '[{"panelId": 1, "left": 0, "center": 0, "right": 20}]'
  gsettings set org.cinnamon panel-zone-symbolic-icon-sizes '[{"panelId": 1, "left": 20, "center": 18, "right": 18}]'
  gsettings set org.cinnamon enabled-applets "['panel1:left:0:menu@cinnamon.org:0', 'panel1:left:1:workspace-switcher@cinnamon.org:15', 'panel1:center:0:calendar@cinnamon.org:13', 'panel1:right:0:sysmonitor@orcus:16', 'panel1:right:1:systray@cinnamon.org:3', 'panel1:right:2:xapp-status@cinnamon.org:4', 'panel1:right:3:notifications@cinnamon.org:5', 'panel1:right:4:removable-drives@cinnamon.org:7', 'panel1:right:5:network@cinnamon.org:10', 'panel1:right:6:sound@cinnamon.org:11', 'panel1:right:7:power@cinnamon.org:12', 'panel1:right:8:cornerbar@cinnamon.org:14']"
  gsettings set org.cinnamon number-workspaces 4 2>/dev/null
  local cal=$HOME/.config/cinnamon/spices/calendar@cinnamon.org/13.json
  [[ -f $cal ]] || sleep 3
  if [[ -f $cal ]]; then
    python3 -I - "$cal" <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["use-custom-format"]["value"] = True
d["custom-format"]["value"] = "%H%n%M"
json.dump(d, open(p, "w"), indent=4)
EOF
  else info "clock format: re-run 'install.sh desktop' after first login to stack the clock"; fi
  ok "panel → right edge"

  # Plank dock
  mkdir -p "$HOME/.local/share/plank/themes/catppuccin-mocha"
  cp -r "$HOME/.themes/$GTK_THEME/plank/." "$HOME/.local/share/plank/themes/catppuccin-mocha/"
  local L=$HOME/.config/plank/dock1/launchers items=() d n; mkdir -p "$L"
  for d in /usr/share/applications/nemo.desktop "$HOME/.local/share/applications/kitty.desktop" \
           /usr/share/applications/firefox.desktop /usr/share/applications/google-chrome.desktop \
           "$HOME"/.local/share/applications/jetbrains-{idea,pycharm,datagrip}-*.desktop \
           /usr/share/applications/cinnamon-settings.desktop; do
    [[ -f $d ]] || continue
    n=$(basename "$d" .desktop); [[ $n == jetbrains-* ]] && n=$(cut -d- -f1-2 <<< "$n")
    printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$d" > "$L/$n.dockitem"; items+=("'$n.dockitem'")
  done
  local P=net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/
  gsettings set $P theme 'catppuccin-mocha'
  gsettings set $P dock-items "[$(IFS=,; echo "${items[*]}")]"
  gsettings set $P position bottom; gsettings set $P alignment center
  gsettings set $P icon-size 44; gsettings set $P zoom-enabled true; gsettings set $P zoom-percent 140
  gsettings set $P hide-mode window-dodge; gsettings set $P show-dock-item false
  ok "Plank dock (${#items[@]} launchers)"

  # Keyboard shortcuts (Super+Space was the layout switcher — moved to the keyboard key)
  gsettings set org.cinnamon.desktop.keybindings.wm switch-input-source "['XF86Keyboard']"
  kb() {
    local p=org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$1/
    gsettings set "$p" name "$2"; gsettings set "$p" command "$3"; gsettings set "$p" binding "['$4']"
  }
  kb custom0 "Rofi: apps"       "rofi -show drun"                         '<Super>space'
  kb custom1 "Rofi: windows"    "rofi -show window"                       '<Super>w'
  kb custom2 "Rofi: clipboard"  "rofi -modi 'clipboard:$BIN/greenclip print' -show clipboard -run-command '{cmd}'" '<Super>v'
  kb custom3 "Rofi: emoji"      "$HOME/.local/share/mise/shims/rofimoji --action copy --skin-tone neutral" '<Super>period'
  kb custom4 "Rofi: power menu" "$BIN/rofi-power"                         '<Super>Escape'
  kb custom5 "Terminal (kitty)" "$BIN/kitty"                              '<Super>Return'
  kb custom6 "Dashboard"        "$BIN/dashboard toggle"                   '<Super>a'
  gsettings set org.cinnamon.desktop.keybindings custom-list "['custom0','custom1','custom2','custom3','custom4','custom5','custom6']"
  ok "shortcuts: Super+Space/W/V/./Esc/Enter/A"

  # Autostart
  local A=$HOME/.config/autostart; mkdir -p "$A"
  autostart() { printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nX-GNOME-Autostart-enabled=true\nX-GNOME-Autostart-Delay=%s\n' "$2" "$3" "$4" > "$A/$1.desktop"; }
  autostart plank     "Plank dock"        plank 2
  autostart greenclip "Clipboard history" "$BIN/greenclip daemon" 3
  autostart eww-dashboard "Eww dashboard"  "$BIN/dashboard start" 4
  rm -f "$A/conky.desktop"
  ok "autostart: plank, greenclip, eww dashboard"
}

p_system() {
  phase "9/9 Login screen, GRUB, reboot-to-Windows (sudo)"
  (( NO_SYSTEM )) && { info "skipped (--no-system)"; return; }
  sudo env NO_GRUB=$NO_GRUB GTK_THEME="$GTK_THEME" CURSOR="$CURSOR" WALL="$HOME/Pictures/Wallpapers/$WALLPAPER" H="$HOME" bash <<'ROOT'
set -euo pipefail
# Login screen (slick-greeter) needs the theme assets system-wide
cp -r "$H/.themes/$GTK_THEME" /usr/share/themes/
cp -r "$H/.icons/$CURSOR" /usr/share/icons/
# Mint ships an older Papirus whose symlinks point the other way; replace files, never write through links
for t in Papirus Papirus-Dark; do
  mkdir -p "/usr/share/icons/$t"
  cp -a --remove-destination "$H/.local/share/icons/$t/." "/usr/share/icons/$t/"
  chown -R root:root "/usr/share/icons/$t"; gtk-update-icon-cache -q "/usr/share/icons/$t" 2>/dev/null || true
done
mkdir -p /usr/share/fonts/truetype/inter && cp "$H"/.local/share/fonts/Inter/*.ttf /usr/share/fonts/truetype/inter/
mkdir -p /usr/share/backgrounds/rice && cp "$WALL" /usr/share/backgrounds/rice/login.png
fc-cache -f >/dev/null
cat > /etc/lightdm/slick-greeter.conf <<EOF
[Greeter]
background=/usr/share/backgrounds/rice/login.png
draw-user-backgrounds=false
background-color=#1e1e2e
theme-name=$GTK_THEME
icon-theme-name=Papirus-Dark
cursor-theme-name=$CURSOR
cursor-theme-size=24
font-name=Inter Variable 11
draw-grid=false
show-hostname=true
clock-format=%H:%M  ·  %A %d %B
EOF
echo "  ✓ login screen"

# Power-menu helper: boot Windows once on next restart
cat > /usr/local/sbin/reboot-to-windows <<'EOF'
#!/bin/sh
entry=$(grep -oP "menuentry '\KWindows[^']*" /boot/grub/grub.cfg | head -1)
[ -n "$entry" ] && grub-reboot "$entry"
EOF
chmod 755 /usr/local/sbin/reboot-to-windows
echo "  ✓ reboot-to-windows helper"

[ "$NO_GRUB" = 1 ] && { echo "  - GRUB skipped (--no-grub)"; exit 0; }
tmp=$(mktemp -d); git clone -q --depth 1 https://github.com/catppuccin/grub "$tmp/grub"
mkdir -p /usr/share/grub/themes; rm -rf /usr/share/grub/themes/catppuccin-mocha-grub-theme
cp -r "$tmp/grub/src/catppuccin-mocha-grub-theme" /usr/share/grub/themes/; rm -rf "$tmp"
[ -f /etc/default/grub.bak-rice ] || cp /etc/default/grub /etc/default/grub.bak-rice
set_grub() { grep -q "^$1=" /etc/default/grub && sed -i "s|^$1=.*|$1=$2|" /etc/default/grub || echo "$1=$2" >> /etc/default/grub; }
set_grub GRUB_THEME '"/usr/share/grub/themes/catppuccin-mocha-grub-theme/theme.txt"'
set_grub GRUB_TIMEOUT_STYLE menu
set_grub GRUB_TIMEOUT 5
set_grub GRUB_DEFAULT saved            # lets grub-reboot pick Windows for one boot
set_grub GRUB_GFXMODE 1920x1080,auto
update-grub 2>/dev/null
echo "  ✓ GRUB theme (original: /etc/default/grub.bak-rice)"
ROOT
}

sync_back() {
  phase "Syncing current configs from \$HOME into $DOT"
  local f
  for f in "${DOTFILES[@]}"; do
    [[ -f $HOME/$f ]] || { warn "missing ~/$f"; continue; }
    mkdir -p "$DOT/$(dirname "$f")"; sed "s|$HOME|@HOME@|g" "$HOME/$f" > "$DOT/$f"
    [[ -x $HOME/$f ]] && chmod +x "$DOT/$f"
  done
  ok "${#DOTFILES[@]} files synced"
}

# ── main ─────────────────────────────────────────────────────────────────────
ALL=(packages tools terminal themes dotfiles git runtimes desktop system)
RUN=()
while (($#)); do
  case $1 in
    --no-grub) NO_GRUB=1 ;;
    --no-system) NO_SYSTEM=1 ;;
    --sync) sync_back; exit ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit ;;
    packages|tools|terminal|themes|dotfiles|git|runtimes|desktop|system) RUN+=("$1") ;;
    *) echo "unknown option: $1 (try --help)"; exit 1 ;;
  esac; shift
done
((${#RUN[@]})) || RUN=("${ALL[@]}")

[[ $EUID -eq 0 ]] && { echo "Run as your normal user, not root — it asks for sudo when needed."; exit 1; }
grep -qi mint /etc/os-release || info "not Linux Mint — continuing, but this is tested on Mint 22 Cinnamon"
printf '%s\n  Catppuccin Mocha rice — phases: %s%s\n' "$c_m" "${RUN[*]}" "$c_0"
[[ " ${RUN[*]} " == *" packages "* || " ${RUN[*]} " == *" system "* ]] && sudo -v

for p in "${RUN[@]}"; do "p_$p"; done

phase "Done"
if ((${#FAILED[@]})); then printf '  %s%d step(s) had problems:%s\n' "$c_r" "${#FAILED[@]}" "$c_0"; printf '   - %s\n' "${FAILED[@]}"
else ok "everything installed"; fi
info "Log out and back in (or reboot) to start zsh, the dock, widget and clipboard daemon."
