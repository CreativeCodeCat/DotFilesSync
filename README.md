# DotFilesSync

DotFilesSync keeps your dotfiles in a git repo. It mirrors folders from
`~/.config` into a project folder, and mirrors them back when you want to
restore a config or push a change. A `watch` mode keeps the copies up to date
as you edit.

The command is `DotFilesSync`. The folders it syncs are listed in a Lua config
file, so it works for any dotfile folder under `~/.config` (see
[Choosing folders](#choosing-folders)).

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
| `watch` | Polls `~/.config` (every 2 seconds by default, `--interval` to change it, 0.5 at least) and pulls changes into the project folder. Never writes to `~/.config`, so a live edit there can't be overwritten by accident. Stop it with Ctrl-C. |
| `drop`  | Throws away every uncommitted change in the synced folders, in the git repo (including new files) and in `~/.config`, so both match the last commit. It stops the service while it runs and starts it again afterwards. **This can't be undone.** |
| `help`  | Shows the usage text. |

`pull` and `push` mirror: the destination ends up matching the source. Files
missing on the receiving side are added, changed files are overwritten, and
files that no longer exist in the source are deleted. Run `--dry-run` first
if you're unsure.

A sync is refused if a source folder is missing, or if the source is empty
while the destination still has files. This stops an accidental wipe. A
missing folder stops the whole run before anything is changed.

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

- Each entry is a folder name directly under the config root (`~/.config` by
  default), such as `"nvim"` or `"kitty"`.
- Names can't contain `/`, and each name can appear only once.
- The list can't be empty.
- The file is required. Without it, DotFilesSync stops with an error that
  shows the expected contents.
- `watch` reads the list when it starts. Restart the service after editing
  the file.

## Layout

```
hypr/          copy of ~/.config/hypr
quickshell/    copy of ~/.config/quickshell
src/main.rs    command-line handling and commands
src/config.rs  reads config.lua, the list of folders
src/sync.rs    plan and apply: the mirroring logic
systemd/       user service template for `watch`
Makefile       build, install and service targets
```

`hypr/` and `quickshell/` are the copies made by the last `pull`. Your
folder list lives in `~/.config/dotfilesync/config.lua`, not in this repo.

Run `make help` to list the make targets.

## Install

Requires a Rust toolchain (`cargo`) and a C compiler. The Lua interpreter is
built from source during the build.

```sh
git clone git@github.com:CreativeCodeCat/DotFilesSync.git
cd DotFilesSync
make release              # build as your user
sudo make install         # copy DotFilesSync to /usr/bin and the service to /usr/lib/systemd/user
make enable               # run as your user: start watching now and at login
```

- `make install` only copies files, so run `make release` first.
- `make install` sets the service's working folder to the folder you ran it
  from, so run it from the folder you want the copies kept in.
- `make enable` must run as your user, not with sudo.
- `make disable` stops the service and stops it starting at login.
- `sudo make uninstall` removes the binary and the service file.

### Upgrading from HyprSync

The binary and service used to be called `hyprsync`. Before installing, turn
off the old service as your user, then remove its files:

```sh
systemctl --user disable --now hyprsync.service
sudo rm -f /usr/bin/hyprsync /usr/lib/systemd/user/hyprsync.service
```

Then run the install steps above.

## Configuration

| Variable          | Default           | Purpose                                                     |
|-------------------|-------------------|-------------------------------------------------------------|
| `HYPRSYNC_DIR`    | current directory | the project folder the copies are kept in                   |
| `HYPRSYNC_CONFIG` | `~/.config`       | the config root; `dotfilesync/config.lua` is read from here |

## Notes

This repo is public. Don't commit secrets, passwords, tokens or other private
machine-specific data into your config folders.
