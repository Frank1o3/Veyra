import QtQuick
import qs.config

Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0
    property string icon: ""
    signal moved(real value)

    implicitHeight: 28
    readonly property real ratio: Math.max(0, Math.min(1, (value - from) / (to - from)))

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        width: parent.width

        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: Colors.foreground
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize + 1
            anchors.verticalCenter: parent.verticalCenter
            font.weight: Font.Bold
        }

        Item {
            id: track
            width: parent.width - (root.icon.length > 0 ? 26 : 0)
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.10)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: track.width * root.ratio
                height: 6
                radius: 3
                color: Colors.color(4)
            }
            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: Colors.foreground
                border.width: 2
                border.color: Colors.color(4)
                anchors.verticalCenter: parent.verticalCenter
                x: track.width * root.ratio - width / 2
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => {
                    if (pressed)
                        update(mouse.x);
                }
                onPressed: mouse => update(mouse.x)
                function update(x) {
                    const r = Math.max(0, Math.min(1, x / track.width));
                    root.value = root.from + r * (root.to - root.from);
                    root.moved(root.value);
                }
            }
        }
    }
}
