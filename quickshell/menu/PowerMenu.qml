import "../common"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The power menu, the same six actions as FlexiFlow's powermenu. Open it
// with the bar's power button, Super+Shift+E, or
//   qs ipc call power toggle
// Click an item, or move with Up/Down and press Return. Number keys 1-6
// pick an item directly. Esc or a click outside closes it.
PanelWindow {
    id: menu

    readonly property var items: [
        { label: "Lock", icon: "", command: "loginctl lock-session", color: "#2BC4C9" },
        { label: "Logout", icon: "", command: "loginctl terminate-session \"${XDG_SESSION_ID:-self}\"", color: "#A165E8" },
        { label: "Suspend", icon: "", command: "systemctl suspend", color: "#3DBD3D" },
        { label: "Hibernate", icon: "", command: "systemctl hibernate", color: "#3A7BE0" },
        { label: "Reboot", icon: "", command: "systemctl reboot", color: "#D4C94A" },
        { label: "Shutdown", icon: "", command: "systemctl poweroff", color: "#CC3333" }
    ]

    property int current: 0

    // where this open puts the card: the bar click that opened it, or null to center
    property var anchorAt: null
    // the screen it opens on (the clicked bar's), or "" for the focused one
    property string targetScreen: ""

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
        const name = targetScreen !== "" ? targetScreen : Hyprland.focusedMonitor?.name;
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === name)
                return list[i];
        }
        return list[0];
    }

    function open(at) {
        anchorAt = at ?? null;
        targetScreen = at ? at.screen : "";
        current = 0;
        visible = true;
        keys.forceActiveFocus();
    }

    function close() {
        visible = false;
    }

    function run(index) {
        close();
        spawn.run(items[index].command);
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            // a bar click leaves its position behind; a key binding doesn't
            const at = Config.popupAt;
            Config.popupAt = null;
            if (menu.visible)
                menu.close();
            else
                menu.open(at);
        }
    }

    Spawn {
        id: spawn
    }

    // clicking outside the card closes the menu
    MouseArea {
        anchors.fill: parent
        onClicked: menu.close()
    }

    Rectangle {
        id: card

        x: menu.anchorAt ? Math.max(8, Math.min(menu.anchorAt.x, parent.width - width - 8)) : (parent.width - width) / 2
        y: menu.anchorAt ? Math.max(8, Math.min(menu.anchorAt.y, parent.height - height - 8)) : (parent.height - height) / 2
        width: 260
        height: column.implicitHeight + 24
        radius: 8
        color: Config.barBg

        // swallow clicks on the card so they don't close the menu
        MouseArea {
            anchors.fill: parent
        }

        // keyboard handling lives here so it has focus while the menu is open
        Item {
            id: keys

            focus: true
            Keys.onUpPressed: menu.current = (menu.current + menu.items.length - 1) % menu.items.length
            Keys.onDownPressed: menu.current = (menu.current + 1) % menu.items.length
            Keys.onReturnPressed: menu.run(menu.current)
            Keys.onEnterPressed: menu.run(menu.current)
            Keys.onEscapePressed: menu.close()
            Keys.onPressed: event => {
                const n = parseInt(event.text);
                if (n >= 1 && n <= menu.items.length) {
                    menu.run(n - 1);
                    event.accepted = true;
                }
            }
        }

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

            Repeater {
                model: menu.items

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 6
                    color: index === menu.current ? Qt.lighter(modelData.color, 1.1) : "transparent"
                    border.color: modelData.color
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            text: row.modelData.icon
                            font.family: Config.font
                            font.pixelSize: Config.fontSize + 4
                            color: row.index === menu.current ? Config.fg : row.modelData.color
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.label
                            font.family: Config.font
                            font.pixelSize: Config.fontSize + 2
                            color: row.index === menu.current ? Config.fg : Config.text
                        }
                        Text {
                            text: row.index + 1
                            font.family: Config.font
                            font.pixelSize: Config.fontSize
                            color: Config.muted
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: menu.current = row.index
                        onClicked: menu.run(row.index)
                    }
                }
            }
        }
    }
}
