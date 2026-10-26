# Login shells only. PATH is set here, not in .zshenv: macOS runs path_helper in between,
# and it reorders anything set earlier.
eval "$(/opt/homebrew/bin/brew shellenv)"

typeset -U path                                # no duplicates; the first occurrence wins
path=(~/.local/bin $path ~/.lmstudio/bin)      # uv first; the LM Studio CLI (lms) last
