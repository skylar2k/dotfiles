_comp_options+=(globdots)
fpath+=(~/.config/zsh/functions)

export ZVM_SYSTEM_CLIPBOARD_ENABLED=true
export TERM=xterm-256color

autoload -Uz sshp
# push-input stashes a half-typed command line and restores it after sshp has run
sshp-widget() { zle push-input; BUFFER=sshp; zle accept-line }
zle -N sshp-widget

function zvm_after_init() {
    source <(fzf --zsh)
    zvm_bindkey vicmd 'gs' sshp-widget    # normal mode: "go ssh"
}


source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
antidote load
