pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // True if EITHER a game explicitly registered with gamemoded,
    // OR a window matching one of your tagged game classes is open.
    property bool active: gamemodeActive || windowMatch

    property bool gamemodeActive: false
    property bool windowMatch: false

    readonly property var gamePatterns: [/^steam_app_\d+$/i, /^bloodstrike\.exe$/i, /^org\.vinegarhq\.Sober$/i, /^Minecraft.*/i,]

    Process {
        id: statusProc
        // gamemoded may not be running/installed — swallow errors rather than crash the shell
        command: ["sh", "-c", "gamemoded -s 2>/dev/null || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.gamemodeActive = this.text.toLowerCase().includes("is active")
        }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const clients = JSON.parse(this.text);
                    root.windowMatch = clients.some(c => {
                        const cls = c.class || c.initialClass || "";
                        return root.gamePatterns.some(p => p.test(cls));
                    });
                } catch (e) {
                    // leave last known state on parse failure rather than flicker
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            statusProc.running = true;
            clientsProc.running = true;
        }
    }
}
