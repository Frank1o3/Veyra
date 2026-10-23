import QtQuick
import Quickshell.Io
import qs.config
import qs.services

Text {
    id: root
    color: temp >= 85 ? "#f38ba8" : (temp >= 70 ? "#f9e2af" : Colors.color(2))
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    font.weight: Font.Bold
    text: "  " + temp + "°C"

    property real temp: 0

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
        }
    }

    Process {
        id: proc
        command: ["cat", "/sys/class/hwmon/hwmon2/temp1_input"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.temp = Math.round(Number(this.text.trim()) / 1000)
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
