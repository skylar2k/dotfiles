# One history file per ZDOTDIR (the guest shell keeps its own), shared live between open shells
HISTFILE=$ZDOTDIR/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt extended_history     # save when each command ran and how long it took
setopt share_history        # every shell writes each command at once and sees the others'
setopt hist_ignore_all_dups # running a command again drops its older copy
setopt hist_ignore_space    # a command typed with a leading space is not saved
setopt hist_reduce_blanks
setopt hist_verify          # !! and friends expand into the line for review instead of running
