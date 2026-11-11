pragma Singleton

import QtQuick

// Everything the Quickshell bar and hotkeys popup are configured with.
// The defaults mirror flexiflow_bar's bar.lua and FlexiFlow's tag colors.
// This file replaces both for the Quickshell UI; the Lua config.lua is
// not read here.
QtObject {
    // toggled by `qs ipc call bar toggle` (Super+b)
    property bool barShown: true
    // set by a bar button just before it opens a menu: {screen, x, y} of the
    // click. The menu consumes it, and centers itself when it is null.
    property var popupAt: null
    // when true, tags with no windows are hidden; toggled by Super+w
    property bool hideVacant: false

    // notification popups
    readonly property int notificationWidth: 360
    readonly property int notificationMax: 5
    readonly property int barHeight: 26
    readonly property color barBg: "#2E3440"
    readonly property color text: "#D8DEE9"
    readonly property color muted: "#4C566A"
    // text drawn on top of an accent chip
    readonly property color fg: "#283036"
    readonly property string font: "Hack Nerd Font"
    readonly property int fontSize: 9

    // ms between status refreshes
    readonly property int interval: 1000
    // ms between update-count checks (paru -Qu hits the AUR)
    readonly property int updatesInterval: 15 * 60 * 1000

    readonly property int tagCount: 10
    // the tag labels, as in FlexiFlow: Japanese numerals 1 to 10 (0 is 零)
    readonly property var tagLabels: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "零"]
    readonly property string tagFont: "Noto Sans CJK JP"
    readonly property var tagAccents: [
        "#A165E8", "#2BC4C9", "#3DBD3D", "#D4C94A", "#E0813A",
        "#D136C9", "#CC3333", "#3A7BE0", "#2BA98F", "#6655C9"
    ]

    // [background, bright] pairs. Segment N (0-indexed, by its position
    // in `segments`) uses accents[N % length].
    readonly property var accents: [
        ["#A165E8", "#C9A4FF"],
        ["#2BC4C9", "#59FFF9"],
        ["#3DBD3D", "#59FF59"],
        ["#D4C94A", "#FFFF59"],
        ["#E0813A", "#FF9C59"],
        ["#D136C9", "#FF59F9"],
        ["#CC3333", "#FF5959"]
    ]

    // Any of: updates, kernel, battery, ram, cpu, keyboard, desktop,
    // network, volume, clock. Reorder, drop or repeat as you like.
    readonly property var segments: [
        "updates", "kernel", "battery", "ram", "cpu",
        "keyboard", "desktop", "network", "volume", "clock"
    ]

    // Shell commands run by `sh -c` when a segment's chips are clicked.
    readonly property var clicks: ({
        updates: {
            left: "${TERMINAL:-alacritty} -e arch-update"
        },
        volume: {
            left: "pavucontrol",
            middle: "pactl set-sink-mute @DEFAULT_SINK@ toggle",
            scroll_up: "pactl set-sink-volume @DEFAULT_SINK@ +5%",
            scroll_down: "pactl set-sink-volume @DEFAULT_SINK@ -5%"
        },
        network: {
            left: "nm-connection-editor"
        }
    })

}
