# ── Files ────────────────────────────────────────────────────────────────────
alias ls='eza --icons --group-directories-first'
alias l='eza -l --icons --git --group-directories-first --time-style=relative'
alias la='eza -la --icons --git --group-directories-first --time-style=relative'
alias lt='eza --tree --level=2 --icons --git-ignore'
alias ltt='eza --tree --level=4 --icons --git-ignore'
alias cat='bat --paging=never'
alias less='bat'
alias tree='eza --tree --icons'
alias cp='cp -iv' mv='mv -iv' rm='rm -Iv' mkdir='mkdir -pv'
alias df='df -h' du='du -h' free='free -h'
alias ..='cd ..' ...='cd ../..' ....='cd ../../..'
alias -- -='cd -'

# ── Editors & tools ──────────────────────────────────────────────────────────
alias v='nvim' vi='nvim' vim='nvim'
alias lg='lazygit' lzd='lazydocker'
alias top='btop' htop='btop'
alias ff='fastfetch'
alias help='tldr'
alias reload='exec zsh'
alias zshrc='nvim ~/.zshrc' aliases='nvim ~/.config/zsh/aliases.zsh'
alias path='print -l $path'
alias ip='ip -c'
alias myip='curl -s https://ifconfig.me; echo'
alias ports='ss -tulpn'
alias icat='kitten icat'
alias clip='xclip -selection clipboard'
[[ $TERM == xterm-kitty ]] && alias ssh='kitten ssh'   # copies terminfo to the remote host

# ── Git ──────────────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status -sb' ga='git add' gaa='git add -A' gap='git add -p'
alias gc='git commit' gcm='git commit -m' gca='git commit --amend --no-edit'
alias gd='git diff' gds='git diff --staged'
alias gp='git push' gpf='git push --force-with-lease' gl='git pull --rebase'
alias gsw='git switch' gswc='git switch -c' gb='git branch -vv'
alias glog='git log --graph --pretty=format:"%C(magenta)%h%Creset %C(blue)%an%Creset %s %C(green)(%cr)%Creset%C(auto)%d" --abbrev-commit'
alias gst='git stash' gstp='git stash pop'
alias unpushed='git log --branches --not --remotes --oneline'

# ── Docker / Kubernetes ──────────────────────────────────────────────────────
alias d='docker' dc='docker compose' dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias k='kubectl' kgp='kubectl get pods' kgs='kubectl get svc' kgd='kubectl get deploy'
alias kctx='kubectl config use-context' kns='kubectl config set-context --current --namespace'
alias kl='kubectl logs -f'

# ── tmux ─────────────────────────────────────────────────────────────────────
alias t='tmux new -A -s main'      # attach to (or create) the "main" session
alias ta='tmux attach -t' tl='tmux ls' tk='tmux kill-session -t'

# ── Suffix aliases: type a filename to open it ───────────────────────────────
alias -s {md,txt,json,yaml,yml,toml,lua,py,ts,js,go,rs,php}=nvim
