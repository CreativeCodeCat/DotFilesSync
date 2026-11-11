import "../common"
import QtQuick

// One status chip: an icon and a label on an accent background. Clicks
// and the wheel run the commands in Config.clicks for its segment.
Rectangle {
    id: chip

    property string icon: ""
    property string label: ""
    // the segment name, to look up its clicks
    property string segment: ""
    // [background, bright]
    property var accent: Config.accents[0]

    implicitWidth: row.implicitWidth + 12
    implicitHeight: Config.barHeight - 6
    radius: 4
    color: area.containsMouse ? accent[1] : accent[0]

    Spawn {
        id: spawn
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: chip.icon
            font.family: Config.font
            font.pixelSize: Config.fontSize + 1
            color: Config.fg
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: chip.label
            font.family: Config.font
            font.pixelSize: Config.fontSize
            color: Config.fg
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            const cmds = Config.clicks[chip.segment] || {};
            const which = mouse.button === Qt.LeftButton ? "left"
                        : mouse.button === Qt.MiddleButton ? "middle"
                        : "right";
            spawn.run(cmds[which]);
        }

        onWheel: wheel => {
            const cmds = Config.clicks[chip.segment] || {};
            spawn.run(wheel.angleDelta.y > 0 ? cmds.scroll_up : cmds.scroll_down);
        }
    }
}
