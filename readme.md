# My dotfiles

Managed with [chezmoi](https://www.chezmoi.io). The source lives in `home/` (see `.chezmoiroot`); the Neovim config
is a plain directory, `nvim/`, that chezmoi links to `~/.config/nvim` as a whole, so whatever Neovim writes there (such as
`nvim-pack-lock.json`, or a new plugin file) lands in the repo.

## New machine

1. Install chezmoi from a package manager that verifies what it installs. Don't pipe a script from the web into `sh`.
   - **macOS:** `brew install chezmoi`. Install Homebrew first with the signed `Homebrew.pkg` from
     https://github.com/Homebrew/brew/releases/latest.
     - Check it with `pkgutil --check-signature Homebrew.pkg`. It should say "trusted by the Apple notary service",
       with a Developer ID Installer certificate for team `927JGANW46` (Homebrew's release signer in 2026).
     - Then install it with `sudo installer -pkg Homebrew.pkg -target /`.
   - **Arch:** `sudo pacman -S chezmoi`
   - **Gentoo:** from the GURU overlay (`app-admin/chezmoi`)
   - **Servers and anywhere else:** the release binary, checked against a hash pinned in this file (below).
2. Clone and apply in one go. `skylar2k` expands to github.com/skylar2k/dotfiles, and the clone lands in
   `~/.local/share/chezmoi`:
   ```sh
   chezmoi init --apply skylar2k
   ```
   - Use `--ssh` on a machine where you push changes back.
   - Use `--source ~/dotfiles` to keep the clone in `~/dotfiles`, as on the work Mac.
   - Use `--dry-run` to see what would happen first.

`chezmoi init` asks a few questions, then applies. The answers are kept in `~/.config/chezmoi/chezmoi.toml` on that
machine only, never in this repo:

| Question         | Used for                                                                                     |
| ---------------- | -------------------------------------------------------------------------------------------- |
| Machine role     | `workstation`, `server` or `guest` (below)                                                   |
| Work machine     | UiB ssh hosts, the munki cask, and git's work identity for itgit repos                       |
| Name and emails  | git identity: personal by default, work for itgit remotes (or by default on a work server)  |
| SSH signing key  | workstations only: commits and tags are signed with it                                       |

`chezmoi init --prompt` asks again.

### chezmoi on a server without a package

Download the release and check it against the hash below before running anything. `sha256sum -c` refuses a
tarball that differs from the one checked here, so a tampered or swapped download never runs.

```sh
v=2.74.0 arch=linux_amd64   # or linux_arm64
curl -fsSLO https://github.com/twpayne/chezmoi/releases/download/v$v/chezmoi_${v}_${arch}.tar.gz
grep " chezmoi_${v}_${arch}.tar.gz$" <<'EOF' | sha256sum -c &&
1b98a567f726f41540414aea4caf912699d53e248b29ccf8369cf553657b2374  chezmoi_2.74.0_linux_amd64.tar.gz
bf89495d1aab5e4fa0fc1ba9457837b34ee8dec9b787570f2de3e1c12a5835a5  chezmoi_2.74.0_linux_arm64.tar.gz
EOF
mkdir -p ~/.local/bin && tar -xzf chezmoi_${v}_${arch}.tar.gz -C ~/.local/bin chezmoi # runs only if the check passed
```

On a shared (guest) account, use `~/.skylar/.local/bin` instead of `~/.local/bin`, so the account's own PATH is not
affected.

The hashes come from the release's `checksums.txt`, whose signature was checked against chezmoi's cosign key.
That key's SHA-256 is `b0dabc5b39f58d3727ab47974c0ca218d15d71d164dfee2515f9c13f3a13fc2a`.

To move to a newer release:
1. Download the release's `checksums.txt`, `checksums.txt.sigstore.json` and `chezmoi_cosign.pub`.
2. Check that the key's SHA-256 still matches the one above.
3. Run `cosign verify-blob --key chezmoi_cosign.pub --bundle chezmoi_<v>_checksums.txt.sigstore.json chezmoi_<v>_checksums.txt`.
4. Copy the two Linux lines into the block above.

## Roles

Which configs each role gets is set in one place, `home/.chezmoidata/configs.yaml`: every config lists its paths,
the roles that get it and, optionally, an OS. `.chezmoiignore` is generated from it, and `hostConfigs` there adds or
drops a config on a single machine by hostname.

| Role          | Gets                                                                                                 |
| ------------- | ---------------------------------------------------------------------------------------------------- |
| `workstation` | zsh, starship, full Neovim, git, ssh, Ghostty, yazi, asm-lsp; on macOS also the Brewfile, the key-remap launch agent and borders; on Arch or Gentoo the packages in `home/.chezmoidata/packages.yaml` |
| `server`      | a Linux host with your own account: `~/.bashrc` (the distro's defaults first, then `~/.bashrc.local`), starship, git, Neovim with `NVIM_PROFILE=lite`; nothing is installed |
| `guest`       | a shared account: zsh, bash, starship, git and lite Neovim, all installed into `~/.skylar` instead of the account's home |

### Guest: a shared account

Everything goes into `~/.skylar`, laid out like a home directory (`~/.skylar/.config/zsh`, `~/.skylar/.config/nvim`,
…), and nothing outside it is written or read. Install with the XDG folders pointed there, so chezmoi keeps its own
config and clone in `~/.skylar` too:

```sh
export XDG_CONFIG_HOME=~/.skylar/.config XDG_DATA_HOME=~/.skylar/.local/share
chezmoi init --apply skylar2k        # role: guest
```

Start your shell with `~/.skylar/.local/bin/skylar-shell`. It sets the XDG folders, git, starship, zoxide and
antidote to `~/.skylar`, then runs your full zsh config, or bash where there is no zsh. Neovim, plugins included,
lives under `~/.skylar` too. Inside that shell plain `chezmoi update` works. Add the host to
`home/.chezmoidata/hosts.yaml`, and your workstation gets `ssh <name>-me`, which logs in and runs the launcher for you.

## zsh

`~/.config/zsh/.zshrc` only loads `conf.d/*.zsh` in name order. Each file covers one topic (options, history, fzf,
eza, bat, keys, plugins, prompt, zoxide). A file for an optional tool returns early when the tool is missing, and the
vi normal-mode keys (`gs` ssh, `gp` projects, `gy` copy a file, `gf` yazi) are only bound when their tools exist.
Copying (`gy`, `copyfile`, and vi yanks like `yy`) goes through `clip`: the local clipboard tool, or OSC 52 over ssh,
which reaches the clipboard of the machine your terminal runs on.

## Day to day

| Task                          | Command                                                                  |
| ----------------------------- | ------------------------------------------------------------------------ |
| See what would change         | `chezmoi diff`                                                           |
| Apply the repo to `$HOME`     | `chezmoi apply`                                                          |
| Pull and apply                | `chezmoi update`                                                         |
| Start managing a file         | `chezmoi add ~/.config/foo/bar`                                          |
| Edit a templated file         | `chezmoi edit ~/.config/git/config` (then `chezmoi apply`)               |
| Update Neovim plugins         | `:PackUpdate` in Neovim, review the changelog, `:write`; commit `nvim/nvim-pack-lock.json` |

Plain files are symlinks into the repo (`mode = "symlink"`), so editing them in `$HOME` edits the repo directly, as
with stow. Templates (`*.tmpl`), private and executable files are written as real files: edit those in `home/`, or
with `chezmoi edit`.

Scripts in `home/.chezmoiscripts/` run during `apply`:
- `brew bundle`, again whenever the Brewfile changes.
- The Linux packages.
- The launch agent and borders.
- The Neovim plugin sync, again whenever `nvim-pack-lock.json` changes. It installs missing plugins and moves the
  others to the locked commits, so an update you commit on one machine reaches the others on their next
  `chezmoi update`. Servers and guest accounts get it too, with their lite profile.

## Brewfile

The Brewfile is `home/dot_config/homebrew/Brewfile.tmpl` (rendered to `~/.config/homebrew/Brewfile`).

```sh
brew bundle check --file=~/.config/homebrew/Brewfile     # what is missing here
brew bundle cleanup --file=~/.config/homebrew/Brewfile   # what is installed but not listed
```

`uv` entries installed from a local folder (not PyPI) must not be in the Brewfile; a new host would try to install a
same-named PyPI package instead. After `brew bundle dump`, move the changes into the template by hand and keep the
`{{ if .work }}` block around the work-only casks.
