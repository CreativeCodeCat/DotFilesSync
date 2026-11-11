import "../common"
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Workspaces 1..Config.tagCount for one monitor, each with its own accent.
// The active one on this monitor is filled, occupied ones are tinted,
// and empty ones are outlined. A click switches to that workspace.
RowLayout {
    id: root

    // the monitor's name, as Hyprland names it
    required property string monitorName

    spacing: 3

    function workspace(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            if (ws.id === id && ws.monitor && ws.monitor.name === monitorName)
                return ws;
        }
        return null;
    }

    // a color t of the way from a to b (QML has no Qt.mix)
    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    Repeater {
        model: Config.tagCount

        delegate: Rectangle {
            id: tag

            required property int index

            readonly property int tagId: index + 1
            readonly property var ws: root.workspace(tagId)
            readonly property bool active: ws ? ws.active : false

            // a window on this tag has asked for attention (say, a link opened
            // in Chrome from Discord): the tag blinks until you go to it
            readonly property bool urgent: {
                const list = Hyprland.toplevels.values;
                for (let i = 0; i < list.length; i++) {
                    const t = list[i];
                    if (t.urgent && t.workspace?.id === tagId)
                        return true;
                }
                return false;
            }
            property real blink: 0
            SequentialAnimation on blink {
                running: tag.urgent && !tag.active
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 350 }
                NumberAnimation { to: 0; duration: 350 }
                onStopped: tag.blink = 0
            }
            readonly property bool occupied: ws ? (ws.lastIpcObject?.windows ?? 0) > 0 : false

            // with Super+w on, an empty tag that is not active is hidden
            visible: !Config.hideVacant || occupied || active
            readonly property color accent: Config.tagAccents[index % Config.tagAccents.length]
            readonly property bool hovered: area.containsMouse

            implicitWidth: 22
            implicitHeight: Config.barHeight - 6
            radius: 4
            // only the current tag is filled with its color; occupied and
            // empty tags are outlined, and hovering a non-current tag tints it
            color: active ? (hovered ? Qt.lighter(accent, 1.25) : accent)
                 : Qt.alpha(accent, hovered ? 0.2 : 0)
            border.color: hovered || occupied ? Qt.lighter(accent, 1.3) : Qt.alpha(accent, 0.5)
            border.width: active ? 0 : 1

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            // the blink: the tag's own color, fading in and out behind the label
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: tag.accent
                opacity: tag.blink
            }

            Text {
                anchors.centerIn: parent
                text: Config.tagLabels[tag.index]
                font.family: Config.tagFont
                font.pixelSize: Config.fontSize
                font.bold: tag.active
                // the label goes to the dark foreground as the blink fills the tag
                color: tag.active ? Config.fg : root.mixColor(Config.text, Config.fg, tag.blink)
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Hyprland 0.57 takes Lua dispatchers, not the old "workspace N" text
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + tag.tagId + " })")
            }
        }
    }
}
