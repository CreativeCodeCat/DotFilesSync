import "../common"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The hotkeys popup: every Hyprland bind that has a description, as key
// badges, with type-to-filter search. Toggle it with
//   qs ipc call hotkeys toggle
// Esc or a click outside the card closes it.
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

    readonly property var shown: {
        const q = query.toLowerCase();
        return binds.filter(b => describe(b).toLowerCase().includes(q));
    }

    function modNames(mask) {
        const out = [];
        if (mask & 64) out.push("Super");
        if (mask & 4) out.push("Ctrl");
        if (mask & 8) out.push("Alt");
        if (mask & 1) out.push("Shift");
        return out;
    }

    function describe(b) {
        return modNames(b.modmask).join(" ") + " " + b.key + " "
            + b.description + " " + b.dispatcher + " " + b.arg;
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
        width: Math.min(680, parent.width - 32)
        height: Math.min(560, parent.height - 64)
        radius: 8
        color: Config.barBg

        // swallow clicks on the card so they don't close the popup
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
                onTextChanged: panel.query = text
                Keys.onEscapePressed: panel.close()
            }

            Text {
                Layout.fillWidth: true
                visible: panel.binds.length === 0
                text: "No described binds (add a description to your bindd lines)"
                font.family: Config.font
                font.pixelSize: Config.fontSize + 1
                color: Config.muted
                wrapMode: Text.WordWrap
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: panel.shown

                delegate: Item {
                    id: row

                    required property var modelData
                    readonly property var keyNames: panel.modNames(modelData.modmask).concat([modelData.key])

                    width: list.width
                    height: 26

                    Row {
                        id: badges

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: row.keyNames

                            delegate: Rectangle {
                                required property string modelData

                                implicitWidth: keyText.implicitWidth + 12
                                implicitHeight: 20
                                radius: 4
                                color: Config.tagAccents[1]

                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSize
                                    color: Config.fg
                                }
                            }
                        }
                    }

                    Text {
                        anchors.left: badges.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: row.width - badges.width - 12
                        text: row.modelData.description
                        font.family: Config.font
                        font.pixelSize: Config.fontSize + 1
                        color: Config.text
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
