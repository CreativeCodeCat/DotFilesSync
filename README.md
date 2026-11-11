# HyprSync

A small dotfile organiser for Hyprland and Quickshell. `hyprsync` copies
`~/.config/hypr` and `~/.config/quickshell` into this repo, and copies them
back when you want to restore or push changes.

## Usage

```sh
hyprsync pull              # ~/.config  ->  this repo
hyprsync push              # this repo  ->  ~/.config
hyprsync pull --dry-run    # show what would change, change nothing
hyprsync push -n           # same, short flag
hyprsync help
```

Each run prints every file it adds (`+`), updates (`~`) or removes (`-`),
then a summary line.

Both directions mirror: the destination ends up matching the source. Files
missing on the receiving side are added, changed files are overwritten, and
files that no longer exist in the source are deleted. Run `--dry-run` first
if you're unsure.

A sync is refused if the source folder is missing, or if the source is empty
while the destination still has files. This stops an accidental wipe.

File permissions and symlinks are preserved. `.git`, `__pycache__` and
`.DS_Store` are never copied.

## Layout

```
hypr/          copy of ~/.config/hypr
quickshell/    copy of ~/.config/quickshell
src/main.rs    command-line handling
src/sync.rs    plan and apply: the mirroring logic
```

## Install

Requires a Rust toolchain (`cargo`).

```sh
git clone git@github.com:CreativeCodeCat/HyprSync.git
cd HyprSync
cargo install --path .     # installs hyprsync to ~/.cargo/bin
```

## Configuration

| Variable          | Default        | Purpose                 |
|-------------------|----------------|-------------------------|
| `HYPRSYNC_DIR`    | `~/HyprSync`   | the repo folder         |
| `HYPRSYNC_CONFIG` | `~/.config`    | the config root         |

The folders synced are set by `FOLDERS` in `src/sync.rs`.

## Notes

This repo is public. Don't commit secrets or machine-specific private data
to your config folders.
