import "../common"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// The dock along the bottom of one monitor. Windows minimized with Super+n
// move to a hidden workspace (Config.minimizedWorkspace), and show here as
// icons. Click one to bring it back to the workspace you're on.
//
// The dock stays hidden. While something is minimized, moving the pointer to
// the bottom edge shows it, and it hides again once the pointer has left it
// for Config.dockHideDelay ms. With nothing minimized it isn't shown at all.
// `qs ipc call dock toggle` pins it up.
Scope {
    id: dock

    // the monitor this dock sits on
    property var screen

    // true while the pointer is on the edge strip or in the dock
    property bool hovered: false

    // the workspace a window is on: Quickshell's link, or Hyprland's own
    // report of it when that link hasn't caught up
    function workspaceIdOf(toplevel) {
        return toplevel.workspace?.id ?? toplevel.lastIpcObject?.workspace?.id;
    }

    // Bumped on window and workspace events, so `minimized` is re-read
    property int revision: 0

    // the windows minimized right now, in the order Hyprland lists them
    readonly property var minimized: {
        revision;
        const list = Hyprland.toplevels.values;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (workspaceIdOf(list[i]) === Config.minimizedWorkspace)
                out.push(list[i]);
        }
        return out;
    }

    // Quickshell doesn't always see a window move onto a workspace that no
    // tag shows, such as the minimized one, so ask Hyprland for the windows
    // again after each window or workspace event.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const name = event?.name ?? "";
            if (name.indexOf("window") !== -1 || name.indexOf("workspace") !== -1 || name.indexOf("movewindow") !== -1) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
                dock.revision++;
            }
        }
    }
    readonly property bool hasWindows: minimized.length > 0
    // the dock shows only while something is minimized, and then when the
    // pointer reaches the bottom edge, or stays up when pinned
    readonly property bool shown: hasWindows && (Config.dockPinned || hovered)

    // the title of the icon under the pointer, or "" when none
    property string hoverTitle: ""
    // the dock window's width: enough for the longest title (see titleText)
    readonly property int panelWidth: 440

    onShownChanged: {
        if (!shown)
            hoverTitle = "";
    }

    // the app id for a window's icon, or "" when it isn't known
    function appIdOf(toplevel) {
        return toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "";
    }

    // Icon names the theme uses for apps whose window class doesn't match.
    readonly property var iconAliases: ({
        "org.kde.konsole": "utilities-terminal"
    })

    // The icon names to try for a window, best first. A window's class often
    // isn't its icon name: VS Code's class is com.microsoft.VSCode, and its
    // icon is vscode, so the last part of the class is tried too.
    function iconCandidates(toplevel) {
        const id = appIdOf(toplevel);
        if (!id)
            return [];
        const last = id.split(".").pop();
        const out = [];
        if (iconAliases[id])
            out.push(iconAliases[id]);
        out.push(id, last, last.toLowerCase(), id.toLowerCase());
        return out;
    }

    // the first icon the theme has for a window, or "" when it has none
    function iconSource(toplevel) {
        for (const name of iconCandidates(toplevel)) {
            const path = Quickshell.iconPath(name, true);
            if (path)
                return path;
        }
        return "";
    }

    // Quickshell's toplevel.address has no "0x" prefix, and Hyprland's
    // address selector only matches with it, so use Hyprland's own address.
    function addressOf(toplevel) {
        const addr = toplevel.lastIpcObject?.address ?? ("0x" + toplevel.address);
        return addr.indexOf("0x") === 0 ? addr : "0x" + addr;
    }

    // Moves a minimized window to the workspace you're on, then focuses it.
    // Hyprland 0.57 takes Lua dispatchers, as the tags do.
    function restore(toplevel) {
        const ws = Hyprland.focusedWorkspace?.id;
        if (ws === undefined || ws === null)
            return;
        const target = "address:" + addressOf(toplevel);
        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + ws
            + ", follow = false, window = \"" + target + "\" })");
        Hyprland.dispatch("hl.dsp.focus({ window = \"" + target + "\" })");
    }

    // Hiding is decided by where the pointer really is, not by enter/exit
    // events, which don't always arrive when the dock appears under a
    // pointer that isn't moving. While the dock is up, the cursor is read
    // every poll interval, and the dock hides once it has been outside the
    // dock's area for Config.dockHideDelay ms.
    Timer {
        id: hideTimer

        interval: Config.dockHideDelay
        onTriggered: dock.hovered = false
    }

    Process {
        id: cursor

        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            id: cursorOut

            onStreamFinished: dock.checkCursor(cursorOut.text)
        }
    }

    Timer {
        id: poll

        interval: 200
        running: dock.shown && !Config.dockPinned
        repeat: true
        onTriggered: if (!cursor.running) cursor.running = true
    }

    // true when the cursor (global layout coordinates, from `hyprctl
    // cursorpos`, as "x, y") is over the dock or its bottom-edge strip
    function checkCursor(text) {
        const m = text.match(/(-?\d+)\D+(-?\d+)/);
        if (!m || !dock.screen)
            return;
        const x = Number(m[1]);
        const y = Number(m[2]);
        const s = dock.screen;
        const w = body.width + 2 * Config.dockMargin;
        const h = Config.dockHeight + Config.dockMargin + Config.dockTipRoom;
        const inside = x >= s.x + (s.width - w) / 2 && x <= s.x + (s.width + w) / 2
            && y >= s.y + s.height - h && y <= s.y + s.height;
        if (inside)
            hideTimer.stop();
        else if (!hideTimer.running)
            hideTimer.restart();
    }

    // the strip along the bottom edge; entering it shows the dock
    PanelWindow {
        id: trigger

        screen: dock.screen
        // no strip while nothing is minimized, or while the dock is pinned up
        visible: dock.hasWindows && !Config.dockPinned
        anchors {
            left: true
            right: true
            bottom: true
        }
        implicitHeight: Config.dockTrigger
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-dock-trigger"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                hideTimer.stop();
                dock.hovered = true;
            }
        }
    }

    // the dock itself, centered at the bottom. Its window is as tall as the
    // dock plus room above it for the title tooltip, and transparent around
    // the panel.
    PanelWindow {
        id: panel

        screen: dock.screen
        visible: dock.shown
        anchors.bottom: true
        // a fixed width, so the window doesn't resize as the title changes
        // under the pointer (that resizing is what made it flicker)
        implicitWidth: Math.max(body.width, dock.panelWidth)
        implicitHeight: Config.dockHeight + Config.dockMargin + Config.dockTipRoom
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-dock"

        // the title of the icon under the pointer, centered above the dock
        Rectangle {
            id: titleBox

            visible: dock.hoverTitle !== ""
            anchors.bottom: body.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: titleText.width + 16
            height: titleText.height + 8
            radius: 4
            color: Config.barBg
            border.color: Config.muted
            border.width: 1

            Text {
                id: titleText

                anchors.centerIn: parent
                width: Math.min(implicitWidth, dock.panelWidth - 16)
                text: dock.hoverTitle
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSize + 1
                color: Config.text
            }
        }

        Rectangle {
            id: body

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Config.dockMargin
            anchors.horizontalCenter: parent.horizontalCenter
            width: dock.hasWindows ? row.implicitWidth + 20 : emptyText.implicitWidth + 32
            height: Config.dockHeight
            radius: 10
            color: Config.barBg
            border.color: Config.muted
            border.width: 1

            // shown while the dock is up with nothing minimized
            Text {
                id: emptyText

                anchors.centerIn: parent
                visible: !dock.hasWindows
                text: "Nothing minimized"
                font.family: Config.font
                font.pixelSize: Config.fontSize + 1
                color: Config.muted
            }

            Row {
                id: row

                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: dock.minimized

                    delegate: Item {
                        id: slot

                        required property var modelData
                        required property int index

                        readonly property color accent: Config.tagAccents[index % Config.tagAccents.length]
                        readonly property string appId: dock.appIdOf(modelData)

                        width: 44
                        height: 44

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: slotArea.containsMouse ? Qt.alpha(slot.accent, 0.4) : Qt.alpha(slot.accent, 0.15)
                            border.color: Qt.alpha(slot.accent, 0.8)
                            border.width: 1
                        }

                        Image {
                            id: icon

                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            sourceSize.width: 30
                            sourceSize.height: 30
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            source: dock.iconSource(slot.modelData)
                        }

                        // the first letter of the title, when no icon was found
                        Text {
                            anchors.centerIn: parent
                            visible: icon.status !== Image.Ready
                            text: (slot.modelData.title || "?").charAt(0).toUpperCase()
                            font.family: Config.font
                            font.pixelSize: Config.fontSize + 6
                            font.bold: true
                            color: Config.text
                        }

                        MouseArea {
                            id: slotArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: dock.hoverTitle = slot.modelData.title
                            onExited: {
                                if (dock.hoverTitle === slot.modelData.title)
                                    dock.hoverTitle = "";
                            }
                            onClicked: dock.restore(slot.modelData)
                        }
                    }
                }
            }
        }
    }
}
