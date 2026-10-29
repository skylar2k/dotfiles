# Neovim keybindings

`<leader>` is **Space**. Press it and wait: which-key lists every group and key below. Inside oil press `g?`,
inside a Telescope picker press `<C-/>`.

Keys marked *(default)* come from Neovim or a plugin, not from this config.

- [Files and search](#files-and-search)
- [Oil, the file browser](#oil-the-file-browser)
- [Project root](#project-root)
- [Buffers and windows](#buffers-and-windows)
- [Code: LSP, diagnostics, format](#code-lsp-diagnostics-format)
- [Git](#git)
- [Python: run, test, debug](#python-run-test-debug)
- [Editing: pairs, surround, comments, folds](#editing-pairs-surround-comments-folds)
- [Completion](#completion)
- [Lists and jumping](#lists-and-jumping)
- [Nordic layout notes](#nordic-layout-notes)

## Files and search

| Key | Action |
| --- | --- |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fc` | Find files in the Neovim config |
| `<leader>fs` | Symbols in this file (classes, methods, functions) |
| `<leader>fS` | Symbols in the project, searched as you type |
| `<leader>fd` | Diagnostics in this buffer |
| `<leader>fD` | Diagnostics in all open buffers |
| `<leader>bb` | Search open buffers |
| `<leader>?` | Search help tags |

Search follows the working directory (see [Project root](#project-root)). Hidden files are included, `.git/` is not.

Inside a Telescope picker *(default)*: `<C-n>` / `<C-p>` move, `<CR>` open, `<C-x>` / `<C-v>` / `<C-t>` open in a
split / vertical split / tab, `<C-q>` send results to quickfix, `<Esc>` or `<C-c>` close, `<C-/>` shows all keys.

## Oil, the file browser

Open it:

| Key | Action |
| --- | --- |
| `<leader>f-` | The directory of this file |
| `<leader>fe` | The working directory |
| `<leader>fr` | The project root |
| `<leader>fb` | Floating oil, press again to close |
| `nvim .` | Oil replaces netrw for directories |

Inside an oil buffer (edit names like text, then `:w` to apply; renaming a Python module also rewrites its imports):

| Key | Action |
| --- | --- |
| `h` / `-` | Parent directory |
| `l` / `<CR>` | Open the entry |
| `gh` | Home directory |
| `gp` | Project root |
| `_` | Working directory *(default)* |
| `<C-v>` / `<C-x>` / `<C-t>` | Open in vertical split / horizontal split / tab |
| `<C-p>` | Preview *(default)* |
| `<C-l>` | Refresh *(default)* |
| `q` / `<C-c>` | Close |
| `g.` | Toggle hidden files *(default)* |
| `gs` | Change sort order *(default)* |
| `gx` | Open with the system app *(default)* |
| `gX` | Trash view |
| `gy` | Yank the entry's path |
| `gq` | Send the entries to quickfix |
| `gd` | Set the working directory to this directory |
| `gD` | Same, for this tab only |
| `gR` | Set the working directory to the project root |
| `g?` | Show all oil keys *(default)* |

`h` and `l` replace the character motions in oil buffers. Use `0`, `$`, `w` and `b` inside a name.

## Project root

The root is the nearest parent with `.git`, `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod` or `Makefile`.
The working directory decides where Telescope searches and where tests run.

| Key | Action |
| --- | --- |
| `<leader>pr` | Set the working directory to the project root |
| `<leader>pd` | Set it to this file's directory |
| `<leader>pw` | Show the working directory and the root |
| `gR`, `gd`, `gD` | The same, from inside oil |

## Buffers and windows

| Key | Action |
| --- | --- |
| `<leader>bd` | Delete buffer, keeps the window layout; refuses unsaved changes |
| `<leader>bD` | Delete buffer and discard changes |
| `<leader>bb` | Search open buffers |
| `<leader>q` | Quit |
| `<Esc>` | Clear search highlight |
| `<leader>w` + key | Any `<C-w>` window command: `h` `j` `k` `l` move, `s` / `v` split, `c` close, `o` only, `=` equalize, `H` `J` `K` `L` move the window, `d` diagnostic float |
| `[b` / `]b` | Previous / next buffer *(default)* |
| `<` / `>` (visual) | Indent and keep the selection |

## Code: LSP, diagnostics, format

Servers: **pyrefly** (Python), **lua_ls** (Lua), **zls** (Zig) and **asm-lsp** (ARM64 assembly, set in
`~/.config/asm-lsp/.asm-lsp.toml`). Hover, rename and the other `gr` keys are Neovim defaults.

| Key | Action |
| --- | --- |
| `gd` | Go to definition |
| `K` | Hover documentation *(default)* |
| `grn` | Rename symbol *(default)* |
| `gra` | Code action, in visual mode extract / refactor *(default)* |
| `grr` | References *(default)* |
| `gri` | Implementations *(default)* |
| `grt` | Type definition *(default)* |
| `grx` | Run code lens *(default)* |
| `gO` | Symbols of this file in a list *(default)* |
| `<C-s>` (insert) | Signature help *(default)* |
| `<leader>ci` / `<leader>co` | Incoming / outgoing calls (go to quickfix) |
| `<leader>ch` | Toggle inlay hints (on by default; Python hints refresh 1 s after you stop typing) |
| `<leader>cf` | Format the buffer or the selection |

Formatting also runs on save: stylua for Lua, ruff (imports, then format) for Python, prettier for Markdown and
`zig fmt` for Zig. There is no formatter for assembly.

Diagnostics:

| Key | Action |
| --- | --- |
| `]d` / `[d` | Next / previous diagnostic *(default)* |
| `]D` / `[D` | Last / first diagnostic *(default)* |
| `<leader>wd` | Show the diagnostic under the cursor (`<C-w>d` *(default)*) |
| `<leader>fd` / `<leader>fD` | Buffer / all buffers in Telescope |

The other uses of the symbol under the cursor are highlighted automatically after a short pause.

## Git

In buffers inside a git repository:

| Key | Action |
| --- | --- |
| `]c` / `[c` | Next / previous hunk |
| `<leader>gp` | Preview hunk |
| `<leader>gs` | Stage or unstage hunk |
| `<leader>gr` | Reset hunk |
| `<leader>gb` | Blame line |

## Python: run, test, debug

Tests and the debugger run from the working directory, so set the root first (`<leader>pr`). With a `uv.lock`
everything runs through `uv run`.

| Key | Action |
| --- | --- |
| `<leader>tt` | Run all tests |
| `<leader>tf` | Run the tests in this file |
| `<leader>tn` | Run the test under the cursor |
| `<leader>rr` | Run this file in a terminal split |

Failures fill the quickfix list, one entry per failure: `:cnext` / `:cprev` (or `]q` / `[q`) walk them.

Debugging, in any buffer once a session exists:

| Key | Action |
| --- | --- |
| `<leader>dT` | Debug the test under the cursor (Python files) |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dc` | Start or continue |
| `<leader>dn` / `<leader>di` / `<leader>do` | Step over / into / out |
| `<leader>dr` | Run to cursor |
| `<leader>dl` | Run the last configuration again |
| `<leader>dh` | Hover the value under the cursor or selection |
| `<leader>ds` | Toggle the variables sidebar |
| `<leader>df` | Toggle the call stack |
| `<leader>dR` | Toggle the REPL |
| `<leader>dt` | Terminate the session |

Built-in Python motions: `]m` / `[m` next / previous def or class, `]]` / `[[` top-level, `]M` end of a def.

## Editing: pairs, surround, comments, folds

**Pairs** close themselves: `(`, `[`, `{`, quotes and backticks. `<BS>` deletes an empty pair, `<CR>` between
`{}` opens the block. An apostrophe after a letter (don't) does not pair.

**Surround** (mini.surround), with a motion or text object:

| Key | Action |
| --- | --- |
| `sa{motion}{char}` | Add: `saiw"` quotes the word |
| `sd{char}` | Delete: `sd"` |
| `sr{old}{new}` | Replace: `sr"'` |
| `sf` / `sF` | Find the next / previous surrounding |
| `sh` | Highlight the surrounding |

`sa(` adds padding spaces, `sa)` does not. `s` is surround's prefix now; use `cl` for substitute-character.

**Comments, selection, folds** *(defaults)*:

| Key | Action |
| --- | --- |
| `gcc` / `gc{motion}` / `gc` (visual) | Toggle comment |
| `an` / `in` (visual) | Grow / shrink the selection by syntax node |
| `zM` | Fold everything: an outline of classes and functions |
| `zr` | Open one fold level, so methods show as one line each |
| `zR` | Open all folds |
| `za` | Toggle the fold under the cursor |

## Completion

The menu opens as you type, from the language server, with an icon per kind.

| Key | Action |
| --- | --- |
| `<Tab>` / `<S-Tab>` | Next / previous item while the menu is open |
| `<C-y>` | Accept the item, including snippets and import edits |
| `<C-e>` | Close the menu |
| `<C-x><C-n>` | Complete from words in the current file |

## Lists and jumping

| Key | Action |
| --- | --- |
| `]q` / `[q` | Next / previous quickfix entry *(default)* |
| `]Q` / `[Q` | Last / first quickfix entry *(default)* |
| `]l` / `[l` | Next / previous location-list entry *(default)* |
| `<C-o>` / `<C-i>` | Back / forward in the jump list *(default)* |

## Nordic layout notes

- `[` and `]` need AltGr, so `[d` `]d` `[c` `]c` `[q` `]q` `[b` `]b` `]m` are slower to type. The leader keys use only letters.
- Oil's dead-key defaults (`~`, `` ` ``, `g~`, `g\`) were replaced with `gh`, `gd`, `gD` and `gX`.
