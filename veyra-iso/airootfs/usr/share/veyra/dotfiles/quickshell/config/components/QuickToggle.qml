import QtQuick
import qs.config

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string subLabel: ""
    property bool active: false
    property bool interactive: true
    signal clicked

    implicitHeight: 60
    readonly property color accentColor: Colors.color(4)

    Rectangle {
        anchors.fill: parent
        radius: Appearance.cardRadius
        color: root.active
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)
            : Qt.rgba(1, 1, 1, (mouse.containsMouse && root.interactive) ? 0.08 : 0.045)
        border.width: 1
        border.color: root.active ? root.accentColor : Qt.rgba(1, 1, 1, 0.07)

        Behavior on color {
            ColorAnimation { duration: Appearance.animFast }
        }
        Behavior on border.color {
            ColorAnimation { duration: Appearance.animFast }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 2

        Text {
            text: root.icon + "  " + root.label
            color: root.active ? root.accentColor : Colors.foreground
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
        }
        Text {
            visible: root.subLabel.length > 0
            text: root.subLabel
            color: Colors.color(7)
            font.family: Appearance.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
            width: parent.width
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}