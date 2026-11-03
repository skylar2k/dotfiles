# Plugins from .zsh_plugins.txt, through antidote (cloned by chezmoi into $ZDOTDIR/.antidote)
[[ -r $ZDOTDIR/.antidote/antidote.zsh ]] || return
source $ZDOTDIR/.antidote/antidote.zsh
antidote load

compdef _files copyfile # copyfile <Tab> completes file names
compdef _files y
