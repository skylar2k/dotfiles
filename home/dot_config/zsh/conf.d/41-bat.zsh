# bat: syntax highlighting for man pages (and the fzf previews in 30-fzf)
(( $+commands[bat] )) || return
export BAT_THEME=ansi # the terminal's own colours
export MANPAGER="sh -c 'col -bx | bat --language=man --plain'"
