fastfetch

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Powerlevel10k
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Directory colors for ls and completion menu
eval "$(dircolors -b)"
export LS_COLORS

# Completion system
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'

# fzf (fuzzy history/file completion)
[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

eval "$(zoxide init zsh)"

alias ls='eza --color=auto --group-directories-first'
alias ll='eza --color=auto --group-directories-first --long --header --git'
alias la='eza --color=auto --group-directories-first --long --all --header --git'
alias l='eza --color=auto --group-directories-first --long --all --header --git --tree --level=2'

alias cat='bat --paging=never --style=plain'

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS

# Autosuggestions + syntax highlighting
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#666666'
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# opencode
export PATH=/home/delta/.opencode/bin:$PATH

# One-shot opencode task via the step-capped `quick` agent.
# Model comes from the global `model` pin in ~/.config/opencode/opencode.json.
q() { opencode run --auto --agent quick "$@" }

# SillyTavern context handoff: summarize the latest chat for a character into a
# pasteable prompt that restores continuity in a fresh chat with no memory.
# Usage: stc              -> newest chat across all characters
#        stc Laevatain    -> newest chat for a character (case-insensitive match)
stc() {
  local base="$HOME/Projects/SillyTavern/data/default-user/chats"
  local file dir
  if [[ -n $1 ]]; then
    dir=$(print -l "$base"/*/ | grep -i -- "$1" | head -1)
    if [[ -z $dir ]]; then
      print -u2 "stc: no chat directory matching '$1'. Available:"
      print -l "$base"/*/ | sed "s|$base/||; s|/$||" | sed 's/^/  /' >&2
      return 1
    fi
    file=$(command ls -t "$dir"/*.jsonl 2>/dev/null | head -1)
  else
    file=$(command ls -t "$base"/*/*.jsonl 2>/dev/null | head -1)
  fi
  if [[ -z $file ]]; then print -u2 "stc: no chat files found"; return 1; fi
  print -u2 "stc: ${file#$base/}"
  local transcript=$(jq -r 'select(.mes) | "**\(.name):** \(.mes)"' "$file")
  local out=$(opencode run --auto "Summarize the roleplay transcript below into a single pasteable context handoff so the character can continue naturally in a NEW chat that has no memory of this one.

Cover, in order:
1. Character: relationship to the user, personality, speech style, pet names, running jokes.
2. The user's name and anything personal established about them.
3. Where the story is right now: exact setting, time, what each was doing.
4. Recent events, most recent first.
5. Unresolved threads: open questions, plans, promises, anything hanging.
6. Tone and pacing notes.

Write it as standing instructions to the character plus a short 'Story so far' section, NOT as a chat message. Third person for events. No preamble, no markdown headers other than those two. Under 400 words.

<transcript>
$transcript
</transcript>")
  local tmp=$(mktemp /tmp/stc.XXXXXX)
  print -r -- "$out" > "$tmp"
  wl-copy < "$tmp"
  command cat "$tmp"
  rm -f "$tmp"
  print -u2 "\n[copied to clipboard]"
}

export PATH=$PATH:/home/delta/.spicetify


# Added by Antigravity CLI installer
export PATH="/home/delta/.local/bin:$PATH"
