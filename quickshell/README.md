# flexiflow-quickshell

FlexiFlow's bar, menus and clipboard history, rewritten in
[Quickshell](https://quickshell.org) for [Hyprland](https://hyprland.org).

Quickshell draws UI; it doesn't manage windows. So this is the UI half
of FlexiFlow. Hyprland does the tiling, workspaces and keybindings, and
you configure those in `~/.config/hypr/hyprland.lua`.

## What's here

- **Bar, one per monitor**: a menu button, workspaces 1 to 10 with their
  own accent (filled when active, tinted when occupied, outlined when
  empty, click to switch), a power button, the focused window's title,
  the status chips and the system tray. Super+w hides the empty tags, and
  again to show them (`qs ipc call tags toggle`).
- **Status chips** from `sysinfo.sh`, the same segments as
  `flexiflow_bar`: updates (paru), kernel, battery, RAM, CPU, keyboard
  layout, desktop, network, volume and clock. Click and scroll run
  commands from `Config.qml`.
- **App menu**: the menu button, or Super+m, lists your installed apps
  and launches the one you pick.
- **Power menu**: lock, logout, suspend, hibernate, reboot and shutdown,
  from the power button or Super+Shift+e.
- **Clipboard history**: Super+F1 opens your copy history, and a watcher
  records every copy as you make it.
- **Hotkeys popup**: every Hyprland bind with a description, as key
  badges, with type-to-filter search. Super+/ opens it.
- **Notifications**: popups in the top-right corner, from the Quickshell
  notification server (it replaces dunst). Each expires after its timeout,
  a click dismisses it, and its action buttons work.
- **System tray**: left click activates an item, middle click runs its
  secondary action.

## Files

Quickshell loads `shell.qml` from this folder. The rest is split by job:

- `shell.qml`: the entry point. It only loads `desktop/`.
- `desktop/Desktop.qml`: one bar per monitor, plus the popups, the bar
  toggle and the clipboard watcher. This is where the parts are wired
  together.
- `common/`: `Config.qml` (colors, font, segments, clicks, tag accents),
  `Sys.qml` with `sysinfo.sh` (the status data), and `Spawn.qml` (runs a
  command). Shared by everything else.
- `bar/`: `Bar.qml`, `Tags.qml`, `Status.qml`, `Chip.qml`, `BarButton.qml`
  and `Tray.qml`.
- `menu/AppMenu.qml`: the app menu, from the menu button or
  `qs ipc call apps toggle`.
- `menu/PowerMenu.qml`: the power menu, from the power button or
  `qs ipc call power toggle`.
- `hotkeys/Hotkeys.qml`: the hotkeys popup, from
  `qs ipc call hotkeys toggle`.
- `notifications/Notifications.qml`: the notification server and its
  popups. It replaces dunst, which is no longer started.
- `clipboard/Clipboard.qml`: the clipboard picker, from Super+F1 or
  `qs ipc call clipboard toggle`. It reads `~/.cache/cliphist`.
- `clipboard/ClipboardWatcher.qml` and `clipboard/record.sh`: the watcher
  runs `wl-paste --watch` with `record.sh`, which appends each copy to
  `~/.cache/cliphist` in the same format `fleximenu_clip` used. It starts
  with the shell and restarts if `wl-paste` exits.

## Install

The files live in `~/.config/quickshell/`, which is where Quickshell looks
by default, so start it with:

```sh
qs
```

Hyprland starts it with `exec-once = qs` in `hyprland.lua`. Quickshell
needs Hyprland, `wl-clipboard` (for the clipboard watcher and copy), and a
Nerd Font for the icons (Hack Nerd Font by default; change it in
`common/Config.qml`). `paru`, `pactl`, `pavucontrol`, `nm-connection-editor`
and `arch-update` are optional. Their segments or clicks do nothing when
they're missing.

## What doesn't carry over

These are Hyprland's jobs now, not Quickshell's:

- **Tiling and layouts**: Hyprland's `dwindle` or `master` layout. The
  13 FlexiFlow layouts, gaps, `cfact` and the pertag layouts have no
  equivalent here.
- **Scratchpads, rules, window swallowing and restart**: use Hyprland's
  special workspaces, window rules and `exec-once`.
- **`config.lua`**: this folder doesn't read it. Settings live in
  `common/Config.qml` (for the UI) and `hyprland.lua` (for everything else).
- **Layout symbol**: the bar doesn't show one.

## Status

The config loads cleanly in Quickshell 0.3.2. The bar, its workspace tags,
the app and power menus, the clipboard picker and its watcher have all been
checked in a live Hyprland session through their IPC calls and the layers
they create. Clicks inside the bar and the menus haven't been tested by
hand.

The hotkeys popup only lists binds written with a description, such as
`bindd`.
