#!/usr/bin/env bash
# Bootstrap a macOS host from this repo: Homebrew, packages, config symlinks, launch agent, Neovim plugins.
# Safe to re-run. Never overwrites existing files in $HOME: a conflict stops the script with a list.
#
# Usage: ./bootstrap.sh [--dry-run] [--skip-brew] [--skip-launchagent] [--skip-nvim]
#   --dry-run           print what would change; only read-only checks (including `stow -n`) really run
#   --skip-brew         don't install Homebrew or run `brew bundle` (stow must already be installed)
#   --skip-launchagent  don't load the key-remap launch agent
#   --skip-nvim         don't pre-install Neovim plugins and treesitter parsers
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
SKIP_BREW=0
SKIP_NVIM=0
SKIP_LAUNCHAGENT=0

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
# Run a command that changes the system, or just print it under --dry-run
run() {
    if ((DRY_RUN)); then
        printf '    + %s\n' "$*"
    else
        "$@"
    fi
}

for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=1 ;;
        --skip-brew) SKIP_BREW=1 ;;
        --skip-launchagent) SKIP_LAUNCHAGENT=1 ;;
        --skip-nvim) SKIP_NVIM=1 ;;
        -h | --help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $arg (see --help)" ;;
    esac
done

[[ "$(uname -s)" == Darwin ]] || die "macOS only (uses Homebrew casks and launchd)"
command -v git >/dev/null || die "git not found (run: xcode-select --install)"
cd "$DOTFILES"

# --- Submodules (antidote) -------------------------------------------------------------------------
say "Submodules"
run git submodule update --init --recursive

# --- Homebrew ----------------------------------------------------------------------------------------
load_brew_env() {
    local brew_bin
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x $brew_bin ]]; then
            eval "$("$brew_bin" shellenv)"
            return 0
        fi
    done
    return 1
}

if ((SKIP_BREW)); then
    say "Homebrew (skipped)"
else
    say "Homebrew"
    if ! load_brew_env; then
        if ((DRY_RUN)); then
            echo "    + install Homebrew with the official script from brew.sh"
        else
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            load_brew_env || die "Homebrew installed but brew was not found afterwards"
        fi
    fi

    # `uv` and `npm` entries in the Brewfile need these tools to exist first
    if command -v brew >/dev/null; then
        if grep -q '^uv ' "$DOTFILES/brew/Brewfile"; then
            command -v uv >/dev/null || run brew install uv
        fi
        if grep -q '^npm ' "$DOTFILES/brew/Brewfile"; then
            command -v npm >/dev/null || run brew install node
        fi
    fi

    say "Brewfile"
    run brew bundle install --file="$DOTFILES/brew/Brewfile"
fi

# --- Config symlinks (GNU Stow) ----------------------------------------------------------------------
# nvim folds, so ~/.config/nvim links to the repo and nvim-pack-lock.json is written back into it.
# The rest link file by file (--no-folding) so ~/.ssh, ~/.config/zsh and ~/Library/LaunchAgents stay real directories.
stow_package() {
    local pkg=$1 mode=$2 out
    local flags=()
    [[ $mode == nofold ]] && flags=(--no-folding)

    # Dry run first: stow exits non-zero if anything in $HOME is in the way
    if ! out=$(stow -d "$DOTFILES" -t "$HOME" ${flags[@]+"${flags[@]}"} -n -R "$pkg" 2>&1); then
        printf '%s\n' "$out" >&2
        die "stow '$pkg' would overwrite existing files in $HOME (listed above). Move them aside and re-run."
    fi
    run stow -d "$DOTFILES" -t "$HOME" ${flags[@]+"${flags[@]}"} -R "$pkg"
}

say "Config symlinks"
if command -v stow >/dev/null; then
    # Real directories first, so stow links into them instead of replacing them
    run mkdir -p "$HOME/.config" "$HOME/Library/LaunchAgents" "$HOME/.ssh/cm" # ssh's ControlPath needs cm/
    run chmod 700 "$HOME/.ssh" "$HOME/.ssh/cm"

    stow_package nvim fold
    stow_package zsh nofold
    stow_package ssh nofold
    stow_package LaunchAgents nofold
elif ((DRY_RUN)); then
    echo "    + stow is not installed yet (brew bundle installs it); skipping the symlink checks"
else
    die "stow not found: run without --skip-brew, or install it first"
fi

# --- Launch agent (key remap) ------------------------------------------------------------------------
if ((SKIP_LAUNCHAGENT)); then
    say "Launch agent (skipped)"
else
    say "Launch agent"
    for plist in "$DOTFILES"/LaunchAgents/Library/LaunchAgents/*.plist; do
        installed="$HOME/Library/LaunchAgents/$(basename "$plist")"
        label=$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist")
        # Reload so a changed plist takes effect; bootout fails harmlessly if it was not loaded
        ((DRY_RUN)) || launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
        run launchctl bootstrap "gui/$(id -u)" "$installed" ||
            warn "could not load $label now; launchd will load it at next login"
    done
fi

# --- Neovim ------------------------------------------------------------------------------------------
if ((SKIP_NVIM)); then
    say "Neovim (skipped)"
elif command -v nvim >/dev/null || ((DRY_RUN)); then
    say "Neovim plugins and treesitter parsers"
    # NVIM_BOOTSTRAP makes the treesitter config wait for parsers to compile before nvim exits
    ((DRY_RUN)) && echo "    + NVIM_BOOTSTRAP=1 nvim --headless +qa" || NVIM_BOOTSTRAP=1 nvim --headless "+qa"
else
    warn "nvim not found, skipping plugin install"
fi

say "Done"
cat <<'EOF'
Not managed by this repo (do these by hand where needed):
  - ~/.config/{git,wm,zed}: not in the dotfiles repo yet
  - uv tools installed from local project folders (graph-macos, pywm, wm-py): reinstall from their checkouts
  - Open a new terminal so ~/.zprofile (ZDOTDIR, brew shellenv) takes effect
EOF
