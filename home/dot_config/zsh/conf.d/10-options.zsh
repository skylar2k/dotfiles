# Directories, completion and terminal
_comp_options+=(globdots) # completion offers dotfiles
fpath+=($ZDOTDIR/functions)
autoload -Uz $ZDOTDIR/functions/*(N:t)

cdpath=(~/projects)
hash -d p=~/projects # ~p is ~/projects
setopt auto_cd auto_pushd pushd_ignore_dups

# Only inside Ghostty: over ssh the other machine usually has no terminfo entry for it
[[ -n $GHOSTTY_RESOURCES_DIR ]] && export TERM=xterm-ghostty

# zsh-vi-mode (loaded in 60-plugins): yanks (yy, yw, visual y) also go to the clipboard, through `clip`, which
# uses the local tool or, over ssh, OSC 52 to reach the clipboard of the machine your terminal runs on
ZVM_SYSTEM_CLIPBOARD_ENABLED=true
ZVM_CLIPBOARD_COPY_CMD=clip
ZVM_CLIPBOARD_PASTE_CMD='clip -o'
typeset -ga zvm_after_init_commands # later files add key bindings that must run after zsh-vi-mode starts

export EDITOR="nvim"
