import "../common"
import QtQuick

// A glyph button on the bar that runs a command when clicked.
Rectangle {
    id: button

    property string glyph: ""
    property string command: ""
    property var accent: Config.tagAccents[0]
    // the monitor this button is on, so a menu it opens lands on that screen
    property string screenName: ""

    implicitWidth: label.implicitWidth + 14
    implicitHeight: Config.barHeight - 6
    radius: 4
    color: area.containsMouse ? Qt.lighter(accent, 1.25) : accent

    Spawn {
        id: spawn
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.glyph
        font.family: Config.font
        font.pixelSize: Config.fontSize + 2
        color: Config.fg
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: mouse => {
            // the menus open where this was clicked (see Config.popupAt)
            const p = button.mapToItem(null, mouse.x, mouse.y);
            Config.popupAt = { screen: button.screenName, x: p.x, y: p.y };
            spawn.run(button.command);
        }
    }
}
