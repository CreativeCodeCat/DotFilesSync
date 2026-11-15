import "../common"
import Quickshell.Io
import QtQuick

// The current Hyprland layout (master, dwindle, monocle or scrolling), read
// from `hyprctl getoption general:layout` once a second. Clicking it cycles
// the layout through the config's bar_toggle_layout (see hyprland.lua).
Rectangle {
    id: label

    // the layout's name, or "" until it's read
    property string layout: ""

    implicitWidth: text.implicitWidth + 12
    implicitHeight: Config.barHeight - 6
    radius: 4
    color: Config.barBg
    border.color: Config.tagAccents[0]
    border.width: 1
    visible: layout !== ""

    Text {
        id: text

        anchors.centerIn: parent
        text: label.layout
        font.family: Config.font
        font.pixelSize: Config.fontSize
        color: Config.text
    }

    // runs the config's layout cycle, the same one as the layout keybinds
    Spawn {
        id: spawn
    }

    MouseArea {
        anchors.fill: parent
        onClicked: spawn.runArgv(["hyprctl", "eval", "bar_toggle_layout()"])
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }

    Process {
        id: reader

        command: ["sh", "-c", "hyprctl getoption general:layout; hyprctl getoption master:orientation"]
        stdout: StdioCollector {
            id: readerOut
            onStreamFinished: {
                // each output starts "str: <value>": the layout, then the master orientation
                const values = readerOut.text.split(/str:\s*/).slice(1).map(s => s.split(/\s/)[0]);
                if (values.length < 2)
                    return;
                // show the symbol for the layout
                const symbols = {
                    "master-left": "[]=",
                    "master-center": "|M|",
                    "dwindle": "[D]",
                    "monocle": "[M]",
                };
                const key = values[0] === "master" ? "master-" + values[1] : values[0];
                label.layout = symbols[key] ?? values[0];
            }
        }
    }
}
