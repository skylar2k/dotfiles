# Prompt: starship (~/.config/starship.toml); without it, a plain one with the directory and exit status
if (( $+commands[starship] )); then
    eval "$(starship init zsh)"
else
    PROMPT='%F{blue}%~%f %(?.%F{green}.%F{red})❯%f '
fi
