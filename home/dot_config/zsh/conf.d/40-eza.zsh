# eza: ls with colours, git status and icons. Plain `ls` stays the system one.
(( $+commands[eza] )) || return
alias ll='eza -l --git --group-directories-first --icons=auto'
alias la='eza -la --git --group-directories-first --icons=auto'
alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
