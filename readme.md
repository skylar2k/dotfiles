# My dotfiles

## New host

```sh
git clone --recurse-submodules <your-dotfiles-url> ~/dotfiles
~/dotfiles/bootstrap.sh
```

`bootstrap.sh` installs Homebrew if needed, runs `brew bundle` on `brew/Brewfile`, symlinks the config with
GNU Stow, loads the key-remap launch agent and pre-installs the Neovim plugins and treesitter parsers.
It is safe to re-run and never overwrites existing files in `$HOME`: a conflict stops it with a list.

```sh
./bootstrap.sh --dry-run   # show what would happen
./bootstrap.sh --help      # --skip-brew, --skip-launchagent, --skip-nvim
```

## Packages

| Package        | Linked as                                     | Stow mode                                          |
| -------------- | --------------------------------------------- | -------------------------------------------------- |
| `nvim`         | `~/.config/nvim` (a single symlink)           | folded, so `nvim-pack-lock.json` is written back   |
| `ghostty`         | `~/.config/ghostty/config` (a single symlink)           | folded   |
| `zsh`          | `~/.zprofile`, `~/.config/zsh/*`              | `--no-folding`                                     |
| `ssh`          | `~/.ssh/config`                               | `--no-folding`, `~/.ssh` stays a real 700 dir      |
| `LaunchAgents` | `~/Library/LaunchAgents/*.plist`              | `--no-folding`                                     |

To relink one package by hand: `stow -R nvim`, or `stow --no-folding -R zsh` for the others.

## Brewfile

```sh
brew bundle dump --force --file=~/dotfiles/brew/Brewfile              # refresh from this machine
brew bundle check --file=~/dotfiles/brew/Brewfile                     # what is missing here
brew bundle cleanup --file=~/dotfiles/brew/Brewfile                   # what is installed but not listed
```

`uv` entries installed from a local folder (not PyPI) must not be in the Brewfile; a new host would try to
install a same-named PyPI package instead. `dump --force` overwrites the file and re-adds them, so check
`git diff brew/Brewfile` after a refresh.
