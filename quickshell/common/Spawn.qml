import Quickshell.Io
import QtQuick

// Runs a command, one at a time. `run` goes through `sh -c` with a string;
// `runArgv` runs an argument list directly, so no quoting is needed.
Process {
    function run(command) {
        if (!command)
            return;
        this.command = ["sh", "-c", command];
        this.running = true;
    }

    function runArgv(argv) {
        this.command = argv;
        this.running = true;
    }
}
