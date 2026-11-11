import "../common"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// The notification daemon and its popups, in the top-right corner of the
// focused monitor. Each popup expires after its own timeout (5 seconds if
// the app doesn't set one). Click a popup to dismiss it, or click one of its
// action buttons. At most Config.notificationMax are shown at once.
Scope {
    id: root

    // the notifications on screen, newest first
    property var items: []

    function add(notification) {
        notification.tracked = true;
        items = [notification].concat(items).slice(0, Config.notificationMax);
    }

    function remove(notification) {
        items = items.filter(n => n !== notification);
    }

    // Focuses the window of the app that sent the notification: its desktop
    // entry (which is usually the window class), else its app name. Does
    // nothing when no window matches.
    function focusApp(notification) {
        const names = [notification.desktopEntry, notification.appName]
            .filter(n => n && n.length > 0);
        if (names.length === 0)
            return;
        // this config is Lua, so the dispatch is a Lua call
        focusProc.runArgv(["hyprctl", "dispatch",
                           "hl.dsp.focus({ window = \"class:^(" + names[0] + ")$\" })"]);
    }

    Spawn {
        id: focusProc
    }

    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        imageSupported: true

        onNotification: notification => root.add(notification)
    }

    PanelWindow {
        id: popups

        visible: root.items.length > 0
        implicitWidth: Config.notificationWidth
        implicitHeight: column.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            right: true
        }
        margins {
            top: Config.barHeight + 8
            right: 8
        }

        // the focused monitor
        screen: {
            const name = Hyprland.focusedMonitor?.name;
            const list = Quickshell.screens;
            for (let i = 0; i < list.length; i++) {
                if (list[i].name === name)
                    return list[i];
            }
            return list[0];
        }

        ColumnLayout {
            id: column

            width: parent.width
            spacing: 8

            Repeater {
                model: root.items

                delegate: Rectangle {
                    id: card

                    required property var modelData

                    // colored by urgency: low is cyan, critical is red, normal is purple
                    readonly property color accent: modelData.urgency === NotificationUrgency.Critical
                        ? Config.tagAccents[6]
                        : modelData.urgency === NotificationUrgency.Low
                            ? Config.tagAccents[1]
                            : Config.tagAccents[0]

                    // the image: quickshell's `image`, else the raw image-path hint
                    // (file paths need a file:// prefix to load)
                    readonly property string imageSource: {
                        const p = modelData.image
                            || modelData.hints?.["image-path"]
                            || modelData.hints?.["image_path"]
                            || "";
                        return p.startsWith("/") ? "file://" + p : p;
                    }

                    // the progress from `notify-send -h int:value:N`, 0 to 100
                    readonly property bool hasProgress: modelData.hints?.value !== undefined
                    readonly property real progress: hasProgress
                        ? Math.max(0, Math.min(100, Number(modelData.hints.value)))
                        : 0

                    Layout.fillWidth: true
                    implicitHeight: content.implicitHeight + 20
                    radius: 8
                    color: Config.barBg
                    border.color: card.accent
                    border.width: 1

                    // expire after the app's timeout (in seconds), or 5 seconds
                    Timer {
                        interval: card.modelData.expireTimeout > 0 ? card.modelData.expireTimeout * 1000 : 5000
                        running: true
                        onTriggered: card.modelData.dismiss()
                    }

                    // the notification was closed (by its app, or by us)
                    Connections {
                        target: card.modelData

                        function onClosed() {
                            root.remove(card.modelData);
                        }
                    }

                    // a click anywhere on the card dismisses it; the action
                    // buttons below take their own clicks
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.focusApp(card.modelData);
                            card.modelData.dismiss();
                        }
                    }

                    ColumnLayout {
                        id: content

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.appName
                            elide: Text.ElideRight
                            font.family: Config.font
                            font.pixelSize: Config.fontSize
                            color: Config.muted
                        }

                        // the notification's image (image-path hint), such as a screenshot
                        Image {
                            Layout.fillWidth: true
                            visible: source !== ""
                            source: card.imageSource
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            Layout.maximumHeight: 160
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.summary
                            wrapMode: Text.WordWrap
                            font.family: Config.font
                            font.pixelSize: Config.fontSize + 2
                            font.bold: true
                            color: Config.text
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: card.modelData.body
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            font.family: Config.font
                            font.pixelSize: Config.fontSize + 1
                            color: Config.text
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: card.hasProgress
                            implicitHeight: 6
                            radius: 3
                            color: Config.muted

                            Rectangle {
                                width: parent.width * card.progress / 100
                                height: parent.height
                                radius: 3
                                color: card.accent
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: card.modelData.actions.length > 0

                            Repeater {
                                model: card.modelData.actions

                                delegate: Rectangle {
                                    required property var modelData

                                    implicitWidth: actionText.implicitWidth + 16
                                    implicitHeight: 24
                                    radius: 4
                                    color: card.accent

                                    Text {
                                        id: actionText
                                        anchors.centerIn: parent
                                        text: modelData.text
                                        font.family: Config.font
                                        font.pixelSize: Config.fontSize
                                        color: Config.fg
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
