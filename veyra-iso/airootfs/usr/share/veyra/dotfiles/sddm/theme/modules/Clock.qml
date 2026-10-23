import QtQuick 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects

import ".."

ColumnLayout {
    id: root

    spacing: 10

    property string clockText: ""
    property string dateString: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            const now = new Date();

            root.clockText = Qt.formatTime(now, "hh:mm AP");
            root.dateString = Qt.formatDate(now, "dddd, MMMM d");
        }
    }

    Text {
        id: timeLabel
        text: root.clockText

        color: Theme.fg

        font.family: Theme.fontFamily
        font.pixelSize: 74
        font.bold: true

        Layout.alignment: Qt.AlignHCenter

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            radius: 12
            samples: 25
            verticalOffset: 2
            color: "#66000000"
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignHCenter

        radius: 999
        color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        implicitWidth: dateLabel.implicitWidth + 26
        implicitHeight: dateLabel.implicitHeight + 10

        Text {
            id: dateLabel
            anchors.centerIn: parent

            text: root.dateString

            color: Theme.muted

            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }
}
