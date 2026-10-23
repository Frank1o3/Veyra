import QtQuick
import Quickshell.Io
import qs.config
import qs.services

Text {
    id: root
    color: Colors.color(4)
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    font.weight: Font.Bold
    text: "󰘚 " + percent + "%"

    property int percent: 0

    Process {
        id: proc
        command: ["sh", "-c", "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const total = Number(lines[0].match(/\d+/)[0]);
                const avail = Number(lines[1].match(/\d+/)[0]);
                root.percent = Math.round((1 - avail / total) * 100);
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: if (!GameMode.active)
            proc.running = true
    }
}
