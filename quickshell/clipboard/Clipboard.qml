import "../common"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The clipboard history, opened with Super+F1 or
//   qs ipc call clipboard toggle
// It reads ~/.cache/cliphist, the file fleximenu_clip (and its `watch`,
// started at login) keeps up to date. Entries are shown newest first, with
// repeats dropped. Type to filter, Up/Down to move, Return copies the entry
// to the clipboard, Esc closes. A click outside closes it.
PanelWindow {
    id: picker

    // the unique entries, newest first
    property var entries: []

    // the entries matching the search text
    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        if (q === "")
            return entries;
        return entries.filter(e => e.toLowerCase().includes(q));
    }

    visible: false
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "#66000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // open on the focused monitor
    screen: {
        const name = Hyprland.focusedMonitor?.name;
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === name)
                return list[i];
        }
        return list[0];
    }

    function open() {
        search.text = "";
        list.currentIndex = 0;
        load.running = true;
        visible = true;
        search.forceActiveFocus();
    }

    function close() {
        visible = false;
    }

    // history lines are stored with newlines as <NEWLINE>; show them as one line
    function oneLine(entry) {
        return entry.replace(/<NEWLINE>/g, " ↵ ");
    }

    // copy an entry back to the clipboard, with its newlines restored
    function copy(entry) {
        if (!entry)
            return;
        close();
        const text = entry.replace(/<NEWLINE>/g, "\n");
        spawn.runArgv(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text]);
    }

    function setEntries(text) {
        const seen = new Set();
        const out = [];
        const lines = text.split("\n");
        for (let i = lines.length - 1; i >= 0; i--) {
            const line = lines[i];
            if (line !== "" && !seen.has(line)) {
                seen.add(line);
                out.push(line);
            }
        }
        entries = out;
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            if (picker.visible)
                picker.close();
            else
                picker.open();
        }
    }

    Spawn {
        id: spawn
    }

    Process {
        id: load
        command: ["sh", "-c", "cat \"$HOME/.cache/cliphist\" 2>/dev/null"]
        stdout: StdioCollector {
            id: loadOut
            onStreamFinished: picker.setEntries(loadOut.text)
        }
    }

    // clicking outside the card closes the picker
    MouseArea {
        anchors.fill: parent
        onClicked: picker.close()
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(560, parent.width - 32)
        height: Math.min(460, parent.height - 64)
        radius: 8
        color: Config.barBg

        // swallow clicks on the card so they don't close the picker
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            TextInput {
                id: search

                Layout.fillWidth: true
                font.family: Config.font
                font.pixelSize: Config.fontSize + 4
                color: Config.text
                selectionColor: Config.tagAccents[0]
                focus: true
                onTextChanged: list.currentIndex = 0
                Keys.onEscapePressed: picker.close()
                Keys.onReturnPressed: picker.copy(picker.shown[list.currentIndex])
                Keys.onEnterPressed: picker.copy(picker.shown[list.currentIndex])
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onDownPressed: list.incrementCurrentIndex()
            }

            Text {
                Layout.fillWidth: true
                visible: picker.shown.length === 0
                text: picker.entries.length === 0
                    ? "The clipboard history is empty"
                    : "No entries match"
                font.family: Config.font
                font.pixelSize: Config.fontSize + 1
                color: Config.muted
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: picker.shown

                delegate: Rectangle {
                    id: row

                    required property string modelData
                    required property int index

                    width: list.width
                    height: 34
                    radius: 6
                    color: index === list.currentIndex ? Config.tagAccents[1] : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        text: picker.oneLine(row.modelData)
                        elide: Text.ElideRight
                        font.family: Config.font
                        font.pixelSize: Config.fontSize + 2
                        color: row.index === list.currentIndex ? Config.fg : Config.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = row.index
                        onClicked: picker.copy(row.modelData)
                    }
                }
            }
        }
    }
}
