# mkcd DIR — make a directory and enter it
mkcd() { mkdir -p -- "$1" && cd -- "$1" }

# extract FILE — unpack any archive
extract() {
  [[ -f $1 ]] || { echo "extract: '$1' is not a file"; return 1 }
  case ${1:l} in
    *.tar.bz2|*.tbz2|*.tbz) tar xjf "$1" ;;
    *.tar.gz|*.tgz)         tar xzf "$1" ;;
    *.tar.xz|*.txz)         tar xJf "$1" ;;
    *.tar.zst)              tar --zstd -xf "$1" ;;
    *.tar)                  tar xf "$1" ;;
    *.bz2)                  bunzip2 "$1" ;;
    *.gz)                   gunzip "$1" ;;
    *.xz)                   unxz "$1" ;;
    *.zip|*.jar)            unzip "$1" ;;
    *.7z)                   7z x "$1" ;;
    *.rar)                  unrar x "$1" ;;
    *) echo "extract: don't know how to unpack '$1'"; return 1 ;;
  esac
}

# y — yazi file manager; on quit, cd to the directory you were browsing
y() {
  local tmp=$(mktemp -t yazi-cwd.XXXXXX) cwd
  yazi "$@" --cwd-file="$tmp"
  cwd=$(<"$tmp"); [[ -n $cwd && $cwd != $PWD ]] && cd -- "$cwd"
  rm -f -- "$tmp"
}

# sshp — fuzzy-pick a host from ~/.ssh/config and connect
sshp() {
  local host=$(awk '/^Host / && $2 !~ /[*?]/ {print $2}' ~/.ssh/config 2>/dev/null |
    fzf --prompt='ssh ❯ ' --preview 'awk -v h={} "\$1==\"Host\"{p=(\$2==h)} p" ~/.ssh/config')
  [[ -n $host ]] && ssh "$host"
}

# fkill — fuzzy-pick processes and kill them (default signal TERM)
fkill() {
  local pids=$(ps -u $USER -o pid=,%cpu=,%mem=,cmd= --sort=-%cpu |
    fzf -m --header='Tab: multi-select' --prompt='kill ❯ ' | awk '{print $1}')
  [[ -n $pids ]] && echo $pids | xargs kill -${1:-15}
}

# port N — show what is listening on port N;  killport N — kill it
port()     { ss -tulpn | awk -v p=":$1\$" 'NR==1 || $5 ~ p' }
killport() {
  local pids=$(ss -tlpnH "sport = :$1" | grep -oP 'pid=\K\d+' | sort -u)
  [[ -z $pids ]] && { echo "nothing on :$1"; return 1 }
  echo "killing $pids on :$1"; kill $pids
}

# gco — fuzzy git branch switcher (local + remote)
gco() {
  local b=$(git branch -a --sort=-committerdate --format='%(refname:short)' |
    fzf --prompt='branch ❯ ' --preview 'git log --oneline --graph --color=always -20 {}')
  [[ -n $b ]] && git switch "${b#origin/}"
}

# fgl — browse git log with diff preview; Enter shows the commit
fgl() {
  git log --color=always --format='%C(magenta)%h%Creset %s %C(green)(%cr)%Creset' "$@" |
    fzf --ansi --no-sort --preview 'git show --color=always {1} | delta' \
        --bind 'enter:execute(git show {1} | delta --paging=always)'
}

# rgf PATTERN — ripgrep, pick a match, open it in nvim at that line
rgf() {
  local sel=$(rg --line-number --no-heading --color=always --smart-case "$@" |
    fzf --ansi --delimiter : --preview 'bat --color=always --highlight-line {2} {1}' \
        --preview-window '+{2}-/2')
  [[ -n $sel ]] && nvim "${sel%%:*}" +$(cut -d: -f2 <<< "$sel")
}

# fe — fuzzy-find a file and open it in nvim
fe() { local f=$(fzf --preview 'bat --color=always --style=numbers {}'); [[ -n $f ]] && nvim "$f" }

# serve [PORT] — quick HTTP server for the current directory
serve() { python3 -m http.server "${1:-8000}" }

# backup FILE — timestamped copy next to the original
backup() { cp -a -- "$1" "$1.$(date +%Y%m%d-%H%M%S).bak" }

# cheat CMD — quick cheatsheet from cheat.sh
cheat() { curl -s "https://cheat.sh/$*" }

# weather [CITY]
weather() { curl -s "https://wttr.in/${1:-}?format=v2" }

