import "../common"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The bar, one per monitor: the menu and power buttons, the
// workspaces, the focused window's title, then the status chips and tray.
PanelWindow {
    id: bar

    visible: Config.barShown
    implicitHeight: Config.barHeight
    color: Config.barBg
    anchors {
        top: true
        left: true
        right: true
    }
    exclusiveZone: implicitHeight
    // above the special workspaces (scratchpads), so the bar stays clickable
    WlrLayershell.layer: WlrLayer.Overlay

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 6

        BarButton {
            glyph: "󰀻"
            command: "qs ipc call apps toggle"
            screenName: bar.screen.name
            accent: Config.tagAccents[0]
        }

        Tags {
            monitorName: bar.screen.name
        }

        LayoutLabel {}

        BarButton {
            glyph: ""
            command: "qs ipc call power toggle"
            screenName: bar.screen.name
            accent: Config.tagAccents[6]
        }

        Text {
            // the title shows on the focused monitor only
            visible: Hyprland.focusedMonitor?.name === bar.screen.name
            text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
            font.family: Config.font
            font.pixelSize: Config.fontSize + 1
            color: Config.text
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        Item {
            Layout.fillWidth: true
            visible: Hyprland.focusedMonitor?.name !== bar.screen.name
        }

        Status {}

        Tray {}
    }
}
