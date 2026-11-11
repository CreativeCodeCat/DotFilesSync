import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

// The system tray. Left click activates an item, middle click runs its
// secondary action. Right-click menus aren't drawn yet.
RowLayout {
    spacing: 4

    Repeater {
        model: SystemTray.items

        delegate: Image {
            required property var modelData

            source: modelData.icon
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            sourceSize.width: 16
            sourceSize.height: 16
            fillMode: Image.PreserveAspectFit
            smooth: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        parent.modelData.activate();
                    else
                        parent.modelData.secondaryActivate();
                }
            }
        }
    }
}
