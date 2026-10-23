import QtQuick 2.15

import ".."

Item {
    id: root

    property string icon: ""
    property string label: ""

    signal clicked

    implicitWidth: 44
    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 18
    }

    // Small label tooltip, shown above the button on hover.
    Rectangle {
        id: tip
        visible: mouse.containsMouse
        anchors.bottom: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8

        radius: 6
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.85)

        implicitWidth: tipLabel.implicitWidth + 14
        implicitHeight: tipLabel.implicitHeight + 8

        Text {
            id: tipLabel
            anchors.centerIn: parent
            text: root.label
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
