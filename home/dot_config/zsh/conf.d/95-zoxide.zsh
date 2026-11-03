# zoxide, last as its docs ask: `z proj` jumps to the most used directory matching "proj", `zi` picks with fzf
(( $+commands[zoxide] )) || return
eval "$(zoxide init zsh)"
