import Quickshell._Window
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

// The system tray. Left click activates an item, middle click runs its
// secondary action, right click opens the item's menu at the click.
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
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        parent.modelData.activate();
                    else if (mouse.button === Qt.RightButton) {
                        // open the menu at the click, on this bar's window
                        if (parent.modelData.hasMenu) {
                            const p = mapToItem(null, mouse.x, mouse.y);
                            parent.modelData.display(QsWindow.window, p.x, p.y);
                        }
                    } else
                        parent.modelData.secondaryActivate();
                }
            }
        }
    }
}
