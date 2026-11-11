import "../common"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Region screenshots, like Flameshot's gui mode. `qs ipc call screenshot region`
// freezes the focused monitor, then shows a selector over it: drag to draw the
// box, drag inside it to move it, drag an edge or corner to resize it. Enter
// saves the selection to ~/Pictures/Screenshots and copies it to the clipboard;
// Escape cancels.
Scope {
    id: root

    // "idle", "freezing" (capturing the screen) or "selecting"
    property string stage: "idle"
    // the monitor being captured
    property string targetName: ""
    // the frozen frame, as a file URL once captured
    property url frozenUrl: ""
    // the saved screen, for scaling the selection to physical pixels
    readonly property string saveDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    // the selection, in logical pixels of the selector window
    property real sx: 0
    property real sy: 0
    property real sw: 0
    property real sh: 0
    readonly property bool hasSelection: sw > 0 && sh > 0

    signal frameReady(var item)

    function screenFor(name) {
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === name)
                return list[i];
        }
        return list[0];
    }

    // "region" (drag a box), "window" (the active window) or "full" (the screen)
    property string mode: "region"
    // the active window's box on the monitor, for "window" mode
    property var windowRect: null

    function start(newMode) {
        if (stage !== "idle")
            return;
        mode = newMode;
        targetName = Hyprland.focusedMonitor?.name ?? "";
        sw = 0;
        sh = 0;
        mkdirProc.runArgv(["mkdir", "-p", saveDir]);
        if (mode === "window") {
            windowProc.running = true;
        } else {
            stage = "freezing";
        }
    }

    // reads the active window's box, then captures the screen
    function onWindowInfo(text) {
        windowRect = null;
        try {
            const w = JSON.parse(text);
            const ox = Hyprland.focusedMonitor?.x ?? 0;
            const oy = Hyprland.focusedMonitor?.y ?? 0;
            if (w.size && w.size[0] > 0 && w.size[1] > 0)
                windowRect = { x: w.at[0] - ox, y: w.at[1] - oy, w: w.size[0], h: w.size[1] };
        } catch (e) {
            windowRect = null;
        }
        if (windowRect === null)
            mode = "full";
        stage = "freezing";
    }

    // the selection for the one-shot modes: the window's box or the whole screen
    function presetSelection() {
        if (mode === "window" && windowRect !== null) {
            sx = windowRect.x;
            sy = windowRect.y;
            sw = windowRect.w;
            sh = windowRect.h;
        } else {
            const scr = screenFor(targetName);
            sx = 0;
            sy = 0;
            sw = scr.width;
            sh = scr.height;
        }
    }

    function close() {
        stage = "idle";
        frozenUrl = "";
        sw = 0;
        sh = 0;
    }

    function confirm() {
        if (!hasSelection)
            return;
        const scale = frozen.sourceSize.width > 0 ? frozen.sourceSize.width / selector.width : 1;
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        const path = saveDir + "/" + stamp + ".png";
        selection.grabToImage(function (result) {
            if (result.saveToFile(path)) {
                copyProc.runArgv(["sh", "-c", "wl-copy --type image/png < \"$1\"", "sh", path]);
                notifyProc.runArgv(["notify-send", "-a", "Screenshot",
                                    "-h", "string:image-path:" + path,
                                    "Screenshot saved", path]);
            }
            close();
        }, Qt.size(sw * scale, sh * scale));
    }

    // which part of the selection a press at (x, y) grabs: a corner or edge
    // to resize, "move" inside it, or "new" to draw a fresh box
    function hitMode(x, y) {
        if (!hasSelection)
            return "new";
        const m = 8;
        const inX = x >= sx - m && x <= sx + sw + m;
        const inY = y >= sy - m && y <= sy + sh + m;
        if (!inX || !inY)
            return "new";
        const l = Math.abs(x - sx) <= m;
        const r = Math.abs(x - (sx + sw)) <= m;
        const t = Math.abs(y - sy) <= m;
        const b = Math.abs(y - (sy + sh)) <= m;
        const edges = (t ? "t" : "") + (b ? "b" : "") + (l ? "l" : "") + (r ? "r" : "");
        if (edges !== "")
            return edges;
        if (x >= sx && x <= sx + sw && y >= sy && y <= sy + sh)
            return "move";
        return "new";
    }

    property string dragMode: "new"
    property real dragX: 0
    property real dragY: 0
    property real dragSX: 0
    property real dragSY: 0

    function clampX(v) { return Math.max(0, Math.min(selector.width, v)); }
    function clampY(v) { return Math.max(0, Math.min(selector.height, v)); }

    function dragTo(x, y) {
        if (dragMode === "new") {
            const x0 = dragX, y0 = dragY;
            sx = Math.min(x0, x);
            sy = Math.min(y0, y);
            sw = Math.abs(x - x0);
            sh = Math.abs(y - y0);
            return;
        }
        if (dragMode === "move") {
            const nx = Math.max(0, Math.min(selector.width - sw, x - dragX + dragSX));
            const ny = Math.max(0, Math.min(selector.height - sh, y - dragY + dragSY));
            sx = nx;
            sy = ny;
            return;
        }
        // resizing: move only the edges named in the mode
        let L = sx, R = sx + sw, T = sy, B = sy + sh;
        if (dragMode.includes("l")) L = Math.min(clampX(x), R - 1);
        if (dragMode.includes("r")) R = Math.max(clampX(x), L + 1);
        if (dragMode.includes("t")) T = Math.min(clampY(y), B - 1);
        if (dragMode.includes("b")) B = Math.max(clampY(y), T + 1);
        sx = L;
        sy = T;
        sw = R - L;
        sh = B - T;
    }

    Spawn {
        id: mkdirProc
    }

    Spawn {
        id: copyProc
    }

    Spawn {
        id: notifyProc
    }

    IpcHandler {
        target: "screenshot"

        function region(): void {
            root.start("region");
        }

        function window(): void {
            root.start("window");
        }

        function full(): void {
            root.start("full");
        }

        function cancel(): void {
            root.close();
        }
    }

    // Captures the monitor. The window is transparent, so the frame holds the
    // desktop and not this window.
    PanelWindow {
        id: shooter

        visible: root.stage === "freezing"
        screen: root.screenFor(root.targetName)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Loader {
            anchors.fill: parent
            active: root.stage === "freezing"

            sourceComponent: ScreencopyView {
                id: view

                captureSource: shooter.screen
                live: false
                // the frame is ready once it has content
                onHasContentChanged: if (hasContent) root.frameReady(view)

                // the capture context isn't ready straight away, so ask again
                // every 50 ms until there's a frame, giving up after 2 s
                property int tries: 0
                Timer {
                    interval: 50
                    running: true
                    repeat: true
                    onTriggered: {
                        view.tries++;
                        if (view.hasContent) {
                            stop();
                        } else if (view.tries > 40) {
                            stop();
                            root.close();
                        } else {
                            view.captureFrame();
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root
        function onFrameReady(item) {
            item.grabToImage(function (result) {
                root.frozenUrl = result.url;
                root.stage = "selecting";
                if (root.mode === "region") {
                    selector.forceActiveFocus();
                } else {
                    // window and full: save the preset box without waiting for keys
                    root.presetSelection();
                    autoConfirm.start();
                }
            });
        }
    }

    // gives the selector one frame to draw, then saves the preset box
    Timer {
        id: autoConfirm

        interval: 60
        onTriggered: root.confirm()
    }

    Process {
        id: windowProc

        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            id: windowOut
            onStreamFinished: root.onWindowInfo(windowOut.text)
        }
    }

    PanelWindow {
        id: selector

        visible: root.stage === "selecting"
        screen: root.screenFor(root.targetName)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // the frozen screen, dimmed
        Image {
            id: frozen

            anchors.fill: parent
            source: root.frozenUrl
            fillMode: Image.Stretch
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            color: "#88000000"
        }

        // the selected part, shown at full brightness
        Item {
            id: selection

            x: root.sx
            y: root.sy
            width: root.sw
            height: root.sh
            clip: true

            Image {
                x: -root.sx
                y: -root.sy
                width: selector.width
                height: selector.height
                source: root.frozenUrl
                fillMode: Image.Stretch
                asynchronous: true
            }
        }

        // the box outline
        Rectangle {
            visible: root.hasSelection
            x: root.sx
            y: root.sy
            width: root.sw
            height: root.sh
            color: "transparent"
            border.color: Config.tagAccents[0]
            border.width: 2
        }

        // dimensions, above the box
        Rectangle {
            visible: root.hasSelection
            x: root.sx
            y: Math.max(0, root.sy - height - 4)
            width: sizeText.implicitWidth + 12
            height: sizeText.implicitHeight + 6
            radius: 4
            color: Config.barBg

            Text {
                id: sizeText
                anchors.centerIn: parent
                text: Math.round(root.sw) + " × " + Math.round(root.sh)
                font.family: Config.font
                font.pixelSize: Config.fontSize
                color: Config.text
            }
        }

        // the mouse: draws, moves or resizes the selection
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true

            onPressed: mouse => {
                root.dragMode = root.hitMode(mouse.x, mouse.y);
                root.dragX = mouse.x;
                root.dragY = mouse.y;
                root.dragSX = root.sx;
                root.dragSY = root.sy;
                if (root.dragMode === "new") {
                    root.sx = mouse.x;
                    root.sy = mouse.y;
                    root.sw = 0;
                    root.sh = 0;
                }
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                root.dragTo(mouse.x, mouse.y);
            }

            onReleased: root.dragMode = "new"
        }

        Item {
            id: keys

            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.confirm();
                }
                event.accepted = true;
            }
        }

        Component.onCompleted: keys.forceActiveFocus()
    }
}
