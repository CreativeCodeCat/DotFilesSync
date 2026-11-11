import "desktop"
import Quickshell
import QtQuick

// Entry point for `qs`, which Quickshell runs from ~/.config/quickshell.
// Everything is in the folders: common/ (config and shared helpers),
// bar/, menu/ (the app and power menus), hotkeys/, and desktop/, which
// wires them together.
ShellRoot {
    Desktop {}
}
