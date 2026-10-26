# The one file zsh always reads from $HOME. It only points zsh at the real config directory;
# PATH and other variables live in $ZDOTDIR/.zprofile (macOS reorders PATH between the two).
export ZDOTDIR=$HOME/.config/zsh
