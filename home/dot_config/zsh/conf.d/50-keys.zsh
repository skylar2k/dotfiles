# Normal-mode keys (Esc, then the key) for the functions in ../functions. A key is only bound when every tool its
# function needs is installed; otherwise it keeps zsh-vi-mode's own meaning.

# Run a command as if typed; a half-typed line comes back afterwards (push-input)
_run_typed() { zle push-input; BUFFER=$1; zle accept-line }
sshp-widget()     { _run_typed sshp }
projects-widget() { _run_typed projects }
copyfile-widget() { _run_typed copyfile }
yazi-widget()     { _run_typed y }
zle -N sshp-widget
zle -N projects-widget
zle -N copyfile-widget
zle -N yazi-widget

# key widget tools...
_bind_if_installed() {
    local key=$1 widget=$2 tool
    shift 2
    for tool; do
        (( $+commands[$tool] )) || return 0
    done
    zvm_after_init_commands+=("zvm_bindkey vicmd $key $widget")
}
_bind_if_installed gs sshp-widget fzf ssh       # "go ssh": pick a host from ~/.ssh/config
_bind_if_installed gp projects-widget fzf       # "go project": cd into ~/projects/<pick>
_bind_if_installed gy copyfile-widget fzf fd    # "go yank": pick a file, copy its contents
_bind_if_installed gf yazi-widget yazi          # "go files": yazi, then cd to where you quit
unfunction _bind_if_installed
