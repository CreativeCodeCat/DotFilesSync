pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Status-bar data. sysinfo.sh runs every Config.interval ms and prints
// one `name|field|...` line per segment; the paru update count is checked
// on its own, every Config.updatesInterval ms, since it hits the AUR.
Item {
    id: root

    // name -> array of fields from sysinfo.sh
    property var fields: ({})
    // null until the first check, -1 when paru isn't installed
    property var updateCount: null

    // the last volume reading seen, as "mute|vol"; null until the first one
    property var lastVolume: null

    function parse(text) {
        const next = {};
        for (const line of text.split("\n")) {
            const parts = line.split("|");
            if (parts.length > 1)
                next[parts[0]] = parts.slice(1);
        }
        fields = next;
        checkVolume();
    }

    // Pops a volume notification whenever the sink's volume or mute changes,
    // whether it came from the bar, the Hyprland keys or anything else. The
    // first reading is only remembered, so starting the shell doesn't notify.
    function checkVolume() {
        const f = fields["volume"];
        if (!f) return;
        const key = f[0] + "|" + f[1];
        const previous = lastVolume;
        lastVolume = key;
        if (previous === null || previous === key) return;

        const muted = f[0] === "yes";
        const vol = Number(f[1]);
        const argv = ["notify-send", "-p", "-a", "Volume", "-t", "1500"];
        // reuse the popup we already showed, so it updates instead of stacking
        if (volumeNotifId > 0)
            argv.push("-r", String(volumeNotifId));
        argv.push("-h", "int:value:" + (muted ? 0 : vol),
                  muted ? "Volume muted" : "Volume " + vol + "%");
        if (notifier.running) {
            // still sending the last one; forget this change so the next poll retries it
            lastVolume = previous;
            return;
        }
        notifier.command = argv;
        notifier.running = true;
    }

    // the id of the volume popup on screen, so the next update replaces it
    property int volumeNotifId: 0

    // notify-send -p prints the id the notification server gave the popup
    Process {
        id: notifier
        stdout: StdioCollector {
            id: notifOut
            onStreamFinished: {
                const id = parseInt(notifOut.text.trim());
                if (id > 0) root.volumeNotifId = id;
            }
        }
    }

    function batteryIcon(status, charge) {
        if (status !== "Discharging")
            return "";
        if (charge > 80) return "";
        if (charge > 60) return "";
        if (charge > 40) return "";
        if (charge > 20) return "";
        return "";
    }

    function volumeIcon(vol) {
        if (vol >= 75) return "";
        if (vol >= 25) return "";
        return "";
    }

    // The chips ({icon, label}) a segment shows right now; [] hides it.
    function chips(name) {
        const f = fields[name];
        if (name === "updates") {
            if (updateCount === -1) return [];
            if (updateCount === null) return [{ icon: "", label: ".." }];
            const label = updateCount === 0 ? "Fully Updated"
                        : updateCount === 1 ? "1 Update"
                        : updateCount + " Updates";
            return [{ icon: "", label: label }];
        }
        if (!f) return [];
        if (name === "kernel")
            return [{ icon: "", label: f[0] }];
        if (name === "battery") {
            const charge = Number(f[1]);
            return [{ icon: batteryIcon(f[0], charge), label: charge + "%" }];
        }
        if (name === "ram") {
            const kib = Number(f[0]);
            const label = kib >= 1024 * 1024
                ? (kib / 1048576).toFixed(1) + "G"
                : Math.round(kib / 1024) + "M";
            return [{ icon: "", label: label }];
        }
        if (name === "cpu")
            return [{ icon: "", label: f[0] + "%" }];
        if (name === "keyboard")
            return [{ icon: "", label: f[0] }];
        if (name === "desktop")
            return [{ icon: "", label: f[0] }];
        if (name === "network")
            return f[0] === "up"
                ? [{ icon: "", label: "Connected" }]
                : [{ icon: "", label: "Disconnected" }];
        if (name === "volume") {
            if (f[0] === "yes")
                return [{ icon: "", label: "muted" }];
            const vol = Number(f[1]);
            return [{ icon: volumeIcon(vol), label: vol + "%" }];
        }
        if (name === "clock")
            return [
                { icon: "", label: f[0] },
                { icon: "", label: f[1] }
            ];
        console.warn("unknown segment " + name);
        return [];
    }

    Timer {
        interval: Config.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!stats.running) stats.running = true
    }

    Process {
        id: stats
        command: ["sh", Quickshell.shellDir + "/common/sysinfo.sh"]
        stdout: StdioCollector {
            id: statsOut
            onStreamFinished: root.parse(statsOut.text)
        }
    }

    Timer {
        interval: Config.updatesInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pacman.running) pacman.running = true
    }

    Process {
        id: pacman
        command: ["sh", "-c",
            "command -v paru >/dev/null 2>&1 || { echo -1; exit 0; }; paru -Qu 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            id: pacmanOut
            onStreamFinished: root.updateCount = Number(pacmanOut.text.trim())
        }
    }
}
