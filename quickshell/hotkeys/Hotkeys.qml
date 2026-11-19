import "../common"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The keybindings popup, opened with Super+/ or
//   qs ipc call hotkeys toggle
// It lists every Hyprland bind that has a description, grouped into sections
// and laid out in columns, with key badges. Numbered tag binds share one row.
// Type to filter; Esc or a click outside the card closes it.
PanelWindow {
    id: panel

    visible: false
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "#99000000"
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

    property var binds: []
    property string query: ""

    // the sections, in the column they're shown in
    readonly property var columnNames: [
        ["System", "Apps & Launchers"],
        ["Windows", "Layouts", "Tags"],
        ["Monitors", "Gaps"],
        ["Scratchpads", "Screenshots", "Bar", "Media"]
    ]

    // each section's header color
    readonly property var sectionAccents: ({
        "System": Config.tagAccents[5],
        "Apps & Launchers": Config.tagAccents[2],
        "Windows": Config.tagAccents[7],
        "Layouts": Config.tagAccents[8],
        "Tags": Config.tagAccents[4],
        "Monitors": Config.tagAccents[1],
        "Gaps": Config.tagAccents[3],
        "Scratchpads": Config.tagAccents[9],
        "Screenshots": "#81A1C1",
        "Bar": "#81A1C1",
        "Media": Config.tagAccents[4]
    })

    // key names that read better as symbols or words
    readonly property var keyLabels: ({
        "slash": "/",
        "comma": ",",
        "period": ".",
        "bracketleft": "[",
        "bracketright": "]",
        "space": "Space",
        "mouse:272": "Mouse L",
        "mouse:273": "Mouse R",
        "mouse:274": "Mouse M"
    })

    // the binds the filter lets through
    readonly property var shown: {
        const q = query.toLowerCase();
        return binds.filter(b => describe(b).toLowerCase().includes(q));
    }

    // the sections and their rows, per column; empty sections are left out
    readonly property var columns: {
        const rows = rowsFor(shown);
        return columnNames.map(col => col
            .map(name => ({
                name: name,
                accent: sectionAccents[name],
                rows: rows.filter(r => r.section === name)
            }))
            .filter(s => s.rows.length > 0));
    }

    function modNames(mask) {
        const out = [];
        if (mask & 64) out.push("Super");
        if (mask & 4) out.push("Ctrl");
        if (mask & 8) out.push("Alt");
        if (mask & 1) out.push("Shift");
        return out;
    }

    function keyLabel(key) {
        if (keyLabels[key] !== undefined)
            return keyLabels[key];
        return key.replace(/^XF86/, "");
    }

    function describe(b) {
        return modNames(b.modmask).join(" ") + " " + b.key + " "
            + b.description + " " + b.dispatcher + " " + b.arg;
    }

    // the section a bind belongs to, from its description
    function sectionOf(b) {
        const d = b.description;
        if (/^(Show this hotkeys|Quit Hyprland|Reload config)/.test(d)) return "System";
        if (/scratchpad/.test(d)) return "Scratchpads";
        if (/^Screenshot/.test(d)) return "Screenshots";
        if (/^(Toggle top bar|Hide or show|Toggle title bars)/.test(d)) return "Bar";
        if (/volume|brightness|mute|track|play/i.test(d)) return "Media";
        if (/gap/i.test(d)) return "Gaps";
        if (/monitor/i.test(d)) return "Monitors";
        if (/tag \d+/.test(d)) return "Tags";
        if (/^(Cycle layout|Shrink master|Grow master|Add window to master|Remove window from master)/.test(d)) return "Layouts";
        if (/^(Open |Power menu|App menu|Clipboard)/.test(d)) return "Apps & Launchers";
        return "Windows";
    }

    // one row per bind, except the numbered tag binds of a kind, which share
    // a row keyed 1-0 (the reference shows 0-9 the same way)
    function rowsFor(list) {
        const rows = [];
        const seen = {};
        for (const b of list) {
            const mods = modNames(b.modmask);
            if (/tag \d+/.test(b.description)) {
                const text = b.description.replace(/\d+/, "N");
                const id = b.modmask + "|" + text;
                if (seen[id])
                    continue;
                seen[id] = true;
                rows.push({ keys: mods.concat(["1-0"]), text: text, section: sectionOf(b) });
            } else {
                rows.push({ keys: mods.concat([keyLabel(b.key)]), text: b.description, section: sectionOf(b) });
            }
        }
        return rows;
    }

    function open() {
        query = "";
        search.text = "";
        visible = true;
        load.running = true;
        search.forceActiveFocus();
    }

    function close() {
        visible = false;
    }

    IpcHandler {
        target: "hotkeys"

        function toggle(): void {
            if (panel.visible)
                panel.close();
            else
                panel.open();
        }
    }

    Process {
        id: load
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            id: loadOut
            onStreamFinished: {
                try {
                    panel.binds = JSON.parse(loadOut.text)
                        .filter(b => b.has_description && b.description);
                } catch (e) {
                    panel.binds = [];
                }
            }
        }
    }

    // clicking outside the card closes the popup
    MouseArea {
        anchors.fill: parent
        onClicked: panel.close()
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(1180, parent.width - 48)
        height: Math.min(parent.height - 96, 780)
        radius: 8
        color: Config.barBg

        // swallow clicks on the card so they don't close the popup
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Keybindings"
                    font.family: Config.font
                    font.pixelSize: Config.fontSize + 6
                    color: Config.text
                    Layout.fillWidth: true
                }

                // the filter box, with a hint while it's empty
                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 30
                    radius: 6
                    color: Qt.alpha(Config.text, 0.06)
                    border.color: Config.muted
                    border.width: 1

                    TextInput {
                        id: search

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Config.font
                        font.pixelSize: Config.fontSize + 2
                        color: Config.text
                        selectionColor: Config.tagAccents[0]
                        focus: true
                        onTextChanged: panel.query = text
                        Keys.onEscapePressed: panel.close()
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        visible: search.text === ""
                        text: "Type to filter"
                        font.family: Config.font
                        font.pixelSize: Config.fontSize + 2
                        color: Config.muted
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Config.muted
            }

            Text {
                Layout.fillWidth: true
                visible: panel.binds.length === 0
                text: "No described binds. Each bind needs a description to show here."
                font.family: Config.font
                font.pixelSize: Config.fontSize + 1
                color: Config.muted
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 28

                Repeater {
                    model: panel.columns

                    delegate: ColumnLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 18

                        Repeater {
                            model: modelData

                            delegate: ColumnLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 6

                                // the section header, in its color
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 3
                                        Layout.preferredHeight: 16
                                        color: modelData.accent
                                    }

                                    Text {
                                        text: modelData.name
                                        font.family: Config.font
                                        font.pixelSize: Config.fontSize + 2
                                        font.bold: true
                                        color: modelData.accent
                                    }
                                }

                                Repeater {
                                    model: modelData.rows

                                    delegate: RowLayout {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: 10

                                        // the key badges: modifiers, then the key
                                        Row {
                                            spacing: 4

                                            Repeater {
                                                model: modelData.keys

                                                delegate: Rectangle {
                                                    required property string modelData

                                                    implicitWidth: keyText.implicitWidth + 12
                                                    implicitHeight: 20
                                                    radius: 4
                                                    color: "#3B4252"
                                                    border.color: Config.muted
                                                    border.width: 1

                                                    Text {
                                                        id: keyText

                                                        anchors.centerIn: parent
                                                        text: parent.modelData
                                                        font.family: Config.font
                                                        font.pixelSize: Config.fontSize
                                                        color: Config.text
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: modelData.text
                                            elide: Text.ElideRight
                                            font.family: Config.font
                                            font.pixelSize: Config.fontSize + 1
                                            color: Config.text
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
