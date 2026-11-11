# DotFilesSync

A small command-line tool that keeps your dotfiles in a git repo. `DotFilesSync`
mirrors folders from `~/.config` into a project folder, and mirrors them back
when you want to restore a config or push a change. A `watch` mode keeps the
copies up to date as you edit.

The tool is general-purpose: the folders it syncs are listed in a Lua config
file (see [Choosing folders](#choosing-folders)).

## Usage

```sh
DotFilesSync pull              # ~/.config  ->  project folder
DotFilesSync push              # project folder  ->  ~/.config
DotFilesSync pull --dry-run    # show what would change, change nothing
DotFilesSync push -n           # same, short flag
DotFilesSync watch             # pull automatically whenever ~/.config changes
DotFilesSync watch --interval 5
DotFilesSync drop --dry-run    # list the uncommitted changes that drop would discard
DotFilesSync drop              # discard uncommitted changes, back to the last commit
DotFilesSync help
```

Each run prints every file it adds (`+`), updates (`~`) or removes (`-`),
then a summary line.

### Commands

| Command | What it does |
|---------|--------------|
| `pull`  | Copies the `~/.config` folders into the project folder. Never writes to `~/.config`. |
| `push`  | Copies the project folders into `~/.config`. |
| `watch` | Polls `~/.config` and pulls changes into the project folder. Never writes to `~/.config`, so a live edit there can't be overwritten by accident. Stop it with Ctrl-C. |
| `drop`  | Throws away every uncommitted change in the synced folders, in the git repo (including new files) and in `~/.config`, so both match the last commit. It stops the service while it runs and starts it again afterwards. **This can't be undone.** |
| `help`  | Shows the usage text. |

Both `pull` and `push` mirror: the destination ends up matching the source.
Files missing on the receiving side are added, changed files are overwritten,
and files that no longer exist in the source are deleted. Run `--dry-run`
first if you're unsure.

A sync is refused if the source folder is missing, or if the source is empty
while the destination still has files. This stops an accidental wipe.

File permissions and symlinks are preserved. `.git`, `__pycache__` and
`.DS_Store` are never copied, at any depth.

## Choosing folders

The folders to sync are listed in `~/.config/dotfilesync/config.lua`. The
file is ordinary Lua and must return a table:

```lua
-- Folders under ~/.config that DotFilesSync keeps in sync.
return {
    folders = { "hypr", "quickshell" },
}
```

Each entry is a folder name directly under the config root (`~/.config` by
default). Names can't contain `/`, and each name can appear only once. To
track another folder, add its name to the list. The `watch` process reads the
list when it starts, so restart the service after editing the file. Without
the file, DotFilesSync stops with an error that shows the expected contents.

## Layout

```
hypr/          copy of ~/.config/hypr
quickshell/    copy of ~/.config/quickshell
src/main.rs    command-line handling
src/config.rs  reads config.lua, the list of folders
src/sync.rs    plan and apply: the mirroring logic
systemd/       user service template for `watch`
Makefile       build, install and service targets
```

Run `make help` to list the make targets.

## Install

Requires a Rust toolchain (`cargo`).

```sh
git clone git@github.com:CreativeCodeCat/DotFilesSync.git
cd DotFilesSync
make release              # build as your user
sudo make install         # copy DotFilesSync to /usr/bin and the systemd unit to /usr/lib/systemd/user
make enable               # run as your user: start watching now and at login
```

`make install` only copies files, so run `make release` first. `make enable`
must run as your user, not with sudo. `make disable` stops the service and
`sudo make uninstall` removes the files.

## Configuration

| Variable          | Default           | Purpose                                                    |
|-------------------|-------------------|------------------------------------------------------------|
| `HYPRSYNC_DIR`    | current directory | the project folder the copies are kept in                  |
| `HYPRSYNC_CONFIG` | `~/.config`       | the config root; `dotfilesync/config.lua` is read from here |

## Notes

This repo is public. Don't commit secrets, passwords, tokens or other private
machine-specific data into your config folders.
