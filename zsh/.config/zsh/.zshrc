_comp_options+=(globdots)

fpath+=(~/.config/zsh/functions)
cdpath=(~/projects)

export ZVM_SYSTEM_CLIPBOARD_ENABLED=true
export TERM=xterm-ghostty

hash -d p=~/projects
setopt auto_cd auto_pushd pushd_ignore_dups

autoload -Uz sshp projects copyfile y
sshp-widget() { zle push-input; BUFFER=sshp; zle accept-line }
pj-widget() { zle push-input; BUFFER=projects; zle accept-line; zle reset-prompt }
copyfile-widget() { zle push-input; BUFFER=copyfile; zle accept-line; zle reset-prompt }
yazi-widget() { zle push-input; BUFFER=y; zle accept-line; zle reset-prompt }

zle -N sshp-widget
zle -N pj-widget
zle -N copyfile-widget
zle -N yazi-widget

function zvm_after_init() {
    source <(fzf --zsh)
    zvm_bindkey vicmd 'gs' sshp-widget    # normal mode: "go ssh"
    zvm_bindkey vicmd 'gp' pj-widget
    zvm_bindkey vicmd 'gy' copyfile-widget    # "go yank": pick a file, copy its contents
    zvm_bindkey vicmd 'gf' yazi-widget        # "go files": yazi, then cd to where you quit
}


source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
antidote load
compdef _files copyfile   # copyfile <Tab> completes file names
compdef _files y
