import QtQuick
import Quickshell.Io
import qs.config
import qs.services

Text {
    id: root
    color: connected ? Colors.color(5) : Colors.color(1)
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    font.weight: Font.Bold
    text: connected ? (isWifi ? "󰖩" : "󰈀") : "󰖪 Offline"

    property bool connected: false
    property bool isWifi: false

    Process {
        id: proc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE dev | grep -E ':connected$' | head -n1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim();
                root.connected = line.length > 0;
                root.isWifi = line.startsWith("wifi");
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

    MouseArea {
        anchors.fill: parent
        onClicked: Qt.callLater(() => Quickshell.execDetached(["nm-connection-editor"]))
    }
}
