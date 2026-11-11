import Quickshell
import Quickshell.Io
import QtQuick

// Watches the clipboard and records every change in the history file the
// picker reads (see record.sh). wl-paste runs record.sh on each new text
// copy. It starts with the shell, and restarts if wl-paste exits.
Item {
    Process {
        id: watcher

        running: true
        command: [
            "wl-paste", "--type", "text", "--watch",
            "sh", Quickshell.shellDir + "/clipboard/record.sh"
        ]
        onExited: restart.restart()
    }

    Timer {
        id: restart

        interval: 1000
        onTriggered: watcher.running = true
    }
}
