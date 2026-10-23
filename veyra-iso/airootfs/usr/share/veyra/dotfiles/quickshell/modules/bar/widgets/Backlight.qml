import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Text {
    id: root
    color: Colors.color(7)
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    font.weight: Font.Bold
    text: "󰃟 " + percent + "%"

    property int percent: 0

    Process {
        id: getProc
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/,(\d+)%,/);
                if (match)
                    root.percent = Number(match[1]);
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: if (!GameMode.active)
            getProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            const dir = wheel.angleDelta.y > 0 ? "5%+" : "5%-";
            Quickshell.execDetached(["brightnessctl", "set", dir]);
            getProc.running = true;
        }
    }
}
