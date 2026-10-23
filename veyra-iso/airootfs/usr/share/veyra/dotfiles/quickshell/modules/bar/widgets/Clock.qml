import QtQuick
import Quickshell.Io
import qs.config

Text {
    id: root
    color: Colors.foreground
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize + 1
    font.bold: true
    font.weight: Font.Bold
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideNone
    wrapMode: Text.NoWrap

    property bool showDate: false
    property string timeText: ""
    property string dateText: ""
    text: root.showDate ? root.dateText : root.timeText

    Process {
        id: timeProc
        command: ["sh", "-c", "LC_TIME=C date '+%I:%M %p'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.timeText = this.text.trim()
        }
    }

    Process {
        id: dateProc
        command: ["date", "+%a, %d %b"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.dateText = this.text.trim()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            timeProc.running = true;
            if (root.showDate)
                dateProc.running = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton || mouse.button === Qt.LeftButton) {
                root.showDate = !root.showDate;
                if (root.showDate)
                    dateProc.running = true;
            }
        }
    }
}
