_comp_options+=(globdots)

fpath+=(~/.config/zsh/functions)
cdpath=(~/projects)

export ZVM_SYSTEM_CLIPBOARD_ENABLED=true
export TERM=xterm-256color   # xterm-ghostty is unknown on remote hosts and breaks ssh

hash -d p=~/projects
setopt auto_cd

autoload -Uz sshp projects
sshp-widget() { zle push-input; BUFFER=sshp; zle accept-line }
pj-widget() { zle push-input; BUFFER=projects; zle accept-line; zle reset-prompt }

zle -N sshp-widget
zle -N pj-widget

function zvm_after_init() {
    source <(fzf --zsh)
    zvm_bindkey vicmd 'gs' sshp-widget    # normal mode: "go ssh"
    zvm_bindkey vicmd 'gp' pj-widget
}


source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
antidote load
