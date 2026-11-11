import "../common"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The app menu, opened by the bar's menu button, Super+m, or
//   qs ipc call apps toggle
// It lists the installed applications (from their desktop entries), narrows
// as you type, and launches the one you pick. Up/Down move, Return launches,
// Esc closes. A click outside closes it.
PanelWindow {
    id: menu

    // the applications, without the ones marked NoDisplay, sorted by name
    readonly property var apps: {
        const all = Array.from(DesktopEntries.applications.values);
        return all
            .filter(e => !e.noDisplay && e.name)
            .sort((a, b) => a.name.localeCompare(b.name));
    }

    // the apps matching the query: name or generic name, as typed
    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        if (q === "")
            return apps;
        return apps.filter(e =>
            e.name.toLowerCase().includes(q)
            || (e.genericName ?? "").toLowerCase().includes(q));
    }

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
    color: "#66000000"
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
        search.text = "";
        list.currentIndex = 0;
        visible = true;
        search.forceActiveFocus();
    }

    function close() {
        visible = false;
    }

    function launch(entry) {
        if (!entry)
            return;
        close();
        entry.execute();
    }

    IpcHandler {
        target: "apps"

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

    // clicking outside the card closes the menu
    MouseArea {
        anchors.fill: parent
        onClicked: menu.close()
    }

    Rectangle {
        id: card

        width: Math.min(380, parent.width - 16)
        height: Math.min(520, parent.height - 16)
        x: menu.anchorAt ? Math.max(8, Math.min(menu.anchorAt.x, parent.width - width - 8)) : (parent.width - width) / 2
        y: menu.anchorAt ? Math.max(8, Math.min(menu.anchorAt.y, parent.height - height - 8)) : (parent.height - height) / 2
        radius: 8
        color: Config.barBg

        // swallow clicks on the card so they don't close the menu
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
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
                Keys.onEscapePressed: menu.close()
                Keys.onReturnPressed: menu.launch(menu.shown[list.currentIndex])
                Keys.onEnterPressed: menu.launch(menu.shown[list.currentIndex])
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onDownPressed: list.incrementCurrentIndex()
            }

            Text {
                Layout.fillWidth: true
                visible: menu.shown.length === 0
                text: "No applications match"
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
                model: menu.shown
                highlightMoveDuration: 0

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    width: list.width
                    height: 36
                    radius: 6
                    color: index === list.currentIndex ? Config.tagAccents[1] : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Image {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            sourceSize.width: 24
                            sourceSize.height: 24
                            source: Quickshell.iconPath(row.modelData.icon, true)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            font.family: Config.font
                            font.pixelSize: Config.fontSize + 2
                            color: row.index === list.currentIndex ? Config.fg : Config.text
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = row.index
                        onClicked: menu.launch(row.modelData)
                    }
                }
            }
        }
    }
}
