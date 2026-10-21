_comp_options+=(globdots)

export ZVM_SYSTEM_CLIPBOARD_ENABLED=true

function zvm_after_init() {
    source <(fzf --zsh)
}

source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh

antidote load
