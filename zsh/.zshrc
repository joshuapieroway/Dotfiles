# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# Modern command-line tools
# zoxide learns the directories you visit: `z <name>` jumps to a match and
# `zi` opens its interactive selector.
eval "$(zoxide init zsh)"

# eza provides readable, Git-aware directory listings.
alias ls='eza --color=auto --group-directories-first'
alias ll='eza --color=auto --group-directories-first --long --header --git'
alias la='eza --color=auto --group-directories-first --long --all --header --git'
alias l='eza --color=auto --group-directories-first --long --all --header --git --tree --level=2'

# Use bat's syntax highlighting and paging in place of cat.
alias cat='bat --paging=never --style=plain'

# Emoji picker using fzf
emoji() {
  local emojis=(
    "😀" "😃" "😄" "😁" "😆" "😅" "🤣" "😂" "🙂" "🙃"
    "😉" "😊" "😇" "🥰" "😍" "🤩" "😘" "😗" "😚" "😙"
    "🥲" "😋" "😛" "😜" "🤪" "😝" "🤑" "🤗" "🤭" "🤫"
    "🤔" "🫡" "🤐" "🤨" "😐" "😑" "😶" "🫥" "😏" "😒"
    "🙄" "😬" "🤥" "😌" "😔" "😪" "🤤" "😴" "😷" "🤒"
    "🤕" "🤢" "🤮" "🥵" "🥶" "🥴" "😵" "🤯" "🤠" "🥳"
    "🥸" "😎" "🤓" "🧐" "😕" "🫤" "😟" "🙁" "☹️" "😮"
    "😯" "😲" "😳" "🥺" "🥹" "😦" "😧" "😨" "😰" "😥"
    "😢" "😭" "😱" "😖" "😣" "😞" "😓" "😩" "😫" "🥱"
    "😤" "😡" "😠" "🤬" "😈" "👿" "💀" "☠️" "💩" "🤡"
    "👹" "👺" "👻" "👽" "👾" "🤖" "❤️" "🧡" "💛" "💚"
    "💙" "💜" "🖤" "🤍" "🤎" "💔" "❤️‍🔥" "❤️‍🩹" "❣️" "💕"
    "💞" "💓" "💗" "💖" "💘" "💝" "👍" "👎" "👊" "✊"
    "🤛" "🤜" "👏" "🙌" "🫶" "👐" "🤲" "🤝" "🙏" "✍️"
    "💪" "🦾" "🦿" "🦵" "🦶" "👂" "🦻" "👃" "🧠" "🫀"
    "🦷" "🦴" "👀" "👁️" "👅" "👄" "🔥" "⭐" "🌟" "✨"
    "💫" "🌈" "☀️" "🌙" "⚡" "❄️" "🌊" "🎵" "🎶" "🎤"
    "🎧" "🎸" "🎹" "🥁" "🎺" "🎻" "🎬" "🎨" "🎯" "🎲"
    "🎮" "🏆" "🥇" "🥈" "🥉" "⚽" "🏀" "🏈" "⚾" "🎾"
    "💻" "🖥️" "🖨️" "⌨️" "🖱️" "💾" "💿" "📀" "📱" "📞"
    "📧" "📬" "📝" "📅" "📁" "🗂️" "📊" "📈" "🔍" "🔒"
  )
  printf '%s\n' "${emojis[@]}" | fzf --height 40% --reverse --prompt="Emoji: " | tr -d '\n' | wl-copy 2>/dev/null || true
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export PATH=$PATH:/home/delta/.spicetify
