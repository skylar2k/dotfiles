# fzf: Ctrl-R history, Ctrl-T files, Alt-C directories, and the menus of fzf-tab and the functions
(( $+commands[fzf] )) || return

# TokyoNight Moon colours (tokyonight.nvim's extras/fzf)
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=rounded --info=inline-right --highlight-line --ansi \
  --color=bg+:#2d3f76,bg:#1e2030,border:#589ed7,fg:#c8d3f5,gutter:#1e2030,header:#ff966c,hl+:#65bcff,hl:#65bcff \
  --color=info:#545c7e,marker:#ff007c,pointer:#ff007c,prompt:#65bcff,query:#c8d3f5:regular,scrollbar:#589ed7 \
  --color=separator:#ff966c,spinner:#ff007c"
if (( $+commands[fd] )); then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi
if (( $+commands[bat] )); then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
else
    export FZF_CTRL_T_OPTS="--preview 'head -n 300 {}'"
fi
if (( $+commands[eza] )); then
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons=always {}'"
    zstyle ':fzf-tab:complete:(cd|z|__zoxide_z):*' fzf-preview 'eza -1 --color=always --icons=always $realpath'
fi
zstyle ':fzf-tab:*' use-fzf-default-opts yes # fzf-tab menus get the colours above

# fzf's key bindings, after zsh-vi-mode, which would otherwise replace them
zvm_after_init_commands+=('source <(fzf --zsh)')
