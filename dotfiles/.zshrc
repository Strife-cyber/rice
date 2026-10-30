# ~/.zshrc — Catppuccin Mocha rice
# Layout: this file (core) + ~/.config/zsh/{aliases,functions,local}.zsh

# ── Startup splash (top-level kitty windows only, not inside tmux/nvim/ssh) ──
if [[ -o interactive && -z $TMUX && -z $NVIM && -z $SSH_CONNECTION && $TERM == xterm-kitty ]]; then
  command -v fastfetch >/dev/null && fastfetch
  _show_quote=1
fi

# ── Environment ──────────────────────────────────────────────────────────────
typeset -U path fpath
path=($HOME/.local/bin $HOME/.cargo/bin $HOME/go/bin $path)
export EDITOR=nvim VISUAL=nvim PAGER=less
export LESS='-R --mouse --use-color'
export MANPAGER="sh -c 'col -bx | bat -l man -p'" MANROFFOPT='-c'
export BAT_THEME='Catppuccin Mocha'
export EZA_CONFIG_DIR=$HOME/.config/eza
ZDATA=$HOME/.local/share/zsh; ZPLUG=$ZDATA/plugins
mkdir -p $ZDATA ${XDG_CACHE_HOME:-$HOME/.cache}/zsh

# ── History ──────────────────────────────────────────────────────────────────
HISTFILE=$ZDATA/history HISTSIZE=100000 SAVEHIST=100000
setopt extended_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks \
       hist_verify share_history inc_append_history

# ── Options ──────────────────────────────────────────────────────────────────
setopt auto_cd auto_pushd pushd_ignore_dups pushd_silent interactive_comments \
       extended_glob glob_dots no_beep correct
WORDCHARS=${WORDCHARS//[\/.=-]}

# ── Completion ───────────────────────────────────────────────────────────────
fpath=($ZPLUG/zsh-completions/src $HOME/.config/zsh/completions $fpath)
mkdir -p $HOME/.config/zsh/completions
autoload -Uz compinit
# Rebuild the dump at most once a day
if [[ -n ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump(#qN.mh+24) || ! -f ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump ]]; then
  compinit -d ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump
else
  compinit -C -d ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump
fi
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache
zstyle ':completion:*:git-checkout:*' sort false
# fzf-tab previews
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:(cd|z|__zoxide_z|eza|ls):*' fzf-preview 'eza -1 --color=always --icons $realpath'
zstyle ':fzf-tab:complete:(nvim|vim|bat|cat):*' fzf-preview 'bat --color=always --style=numbers --line-range=:200 $realpath 2>/dev/null || eza -1 --icons --color=always $realpath'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps --pid=$word -o cmd --no-headers -w -w'
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff $word | delta'
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview 'git log --oneline --graph --color=always $word'

# ── fzf (Catppuccin Mocha) ───────────────────────────────────────────────────
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules'
export FZF_DEFAULT_OPTS="--height=60% --layout=reverse --border=rounded --info=inline-right \
  --prompt='  ' --pointer='▶' --marker='✓' --bind='ctrl-/:toggle-preview' \
  --color=bg+:#313244,bg:-1,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8 \
  --color=info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
  --color=selected-bg:#45475a,border:#6c7086,label:#cdd6f4"
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules'
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"

# ── Plugins (order matters) ──────────────────────────────────────────────────
source $ZPLUG/fzf-tab/fzf-tab.plugin.zsh
source $ZPLUG/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
source $ZPLUG/catppuccin-zsh-syntax-highlighting/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh
source $ZPLUG/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $ZPLUG/zsh-history-substring-search/zsh-history-substring-search.zsh

# ── Keybindings (emacs mode) ─────────────────────────────────────────────────
bindkey -e
bindkey '^[[A' history-substring-search-up      # ↑ searches history by prefix
bindkey '^[[B' history-substring-search-down
bindkey '^[[1;5C' forward-word                  # Ctrl+→
bindkey '^[[1;5D' backward-word                 # Ctrl+←
bindkey '^[[3~' delete-char
bindkey '^H' backward-kill-word                 # Ctrl+Backspace
bindkey '^ ' autosuggest-accept                 # Ctrl+Space accepts suggestion
autoload -Uz edit-command-line; zle -N edit-command-line
bindkey '^X^E' edit-command-line                # Ctrl+X Ctrl+E: edit in nvim

# ── Tool integrations ────────────────────────────────────────────────────────
_has() { command -v $1 >/dev/null }
_has fzf      && source <(fzf --zsh)                      # Ctrl+T files, Alt+C dirs
_has atuin    && eval "$(atuin init zsh --disable-up-arrow)"  # Ctrl+R history
_has zoxide   && eval "$(zoxide init zsh --cmd cd)"       # smart cd, `cdi` to pick
_has mise     && eval "$(mise activate zsh)"
_has direnv   && eval "$(direnv hook zsh)"
_has starship && eval "$(starship init zsh)"
# Completions generated once into ~/.config/zsh/completions
for _t in kubectl k9s mise starship; do
  [[ -f $HOME/.config/zsh/completions/_$_t ]] || { _has $_t && $_t completion zsh > $HOME/.config/zsh/completions/_$_t 2>/dev/null; }
done; unset _t

# ── Aliases, functions, machine-local overrides ──────────────────────────────
for f in aliases functions local; do
  [[ -f $HOME/.config/zsh/$f.zsh ]] && source $HOME/.config/zsh/$f.zsh
done; unset f; true

# Quote under the splash (defined in functions.zsh)
(( ${_show_quote:-0} )) && quote; unset _show_quote; true
