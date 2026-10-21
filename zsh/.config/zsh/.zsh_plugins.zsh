fpath+=( "$HOME/Library/Caches/antidote/github.com/mattmc3/zephyr/plugins/color" )
source "$HOME/Library/Caches/antidote/github.com/mattmc3/zephyr/plugins/color/color.plugin.zsh"
fpath+=( "$HOME/Library/Caches/antidote/github.com/mattmc3/zephyr/plugins/autosuggest" )
source "$HOME/Library/Caches/antidote/github.com/mattmc3/zephyr/plugins/autosuggest/autosuggest.plugin.zsh"
fpath+=( "$HOME/Library/Caches/antidote/github.com/mattmc3/zephyr/plugins/macos" )
source "$HOME/Library/Caches/antidote/github.com/mattmc3/zephyr/plugins/macos/macos.plugin.zsh"
fpath+=( "$HOME/Library/Caches/antidote/github.com/mattmc3/ez-compinit" )
source "$HOME/Library/Caches/antidote/github.com/mattmc3/ez-compinit/ez-compinit.plugin.zsh"
fpath+=( "$HOME/Library/Caches/antidote/github.com/zsh-users/zsh-completions/src" )
fpath+=( "$HOME/Library/Caches/antidote/github.com/jeffreytse/zsh-vi-mode" )
source "$HOME/Library/Caches/antidote/github.com/jeffreytse/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
fpath+=( "$HOME/Library/Caches/antidote/github.com/aloxaf/fzf-tab" )
source "$HOME/Library/Caches/antidote/github.com/aloxaf/fzf-tab/fzf-tab.plugin.zsh"
if ! (( $+functions[zsh-defer] )); then
  fpath+=( "$HOME/Library/Caches/antidote/github.com/romkatv/zsh-defer" )
  source "$HOME/Library/Caches/antidote/github.com/romkatv/zsh-defer/zsh-defer.plugin.zsh"
fi
fpath+=( "$HOME/Library/Caches/antidote/github.com/zdharma-continuum/fast-syntax-highlighting" )
zsh-defer source "$HOME/Library/Caches/antidote/github.com/zdharma-continuum/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
