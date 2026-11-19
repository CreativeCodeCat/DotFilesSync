import "../bar"
import "../clipboard"
import "../common"
import "../dock"
import "../hotkeys"
import "../menu"
import "../notifications"
import "../screenshot"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// The desktop: one bar per monitor, and the popups that open over it. Each
// popup has its own IPC target (see its file), and the bar's visibility is
// toggled with `qs ipc call bar toggle`.
Scope {
    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }

    // one dock per monitor, along its bottom edge
    Variants {
        model: Quickshell.screens

        delegate: Dock {
            required property var modelData
            screen: modelData
        }
    }

    Hotkeys {}
    AppMenu {}
    Clipboard {}
    ClipboardWatcher {}
    Notifications {}
    PowerMenu {}
    Screenshot {}

    IpcHandler {
        target: "tags"

        function toggle(): void {
            Config.hideVacant = !Config.hideVacant;
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            Config.barShown = !Config.barShown;
        }
    }

    // closes the focused window, as Super+Shift+Q does
    IpcHandler {
        target: "window"

        function close(): void {
            Hyprland.dispatch("hl.dsp.window.close()");
        }
    }

    IpcHandler {
        target: "dock"

        function toggle(): void {
            Config.dockPinned = !Config.dockPinned;
        }

        // sends the focused window to the minimized workspace, as Super+n does
        function minimize(): void {
            Hyprland.dispatch("hl.dsp.window.move({ workspace = " + Config.minimizedWorkspace + ", follow = false })");
        }
    }
}
