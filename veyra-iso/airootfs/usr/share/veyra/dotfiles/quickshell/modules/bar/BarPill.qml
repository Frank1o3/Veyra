import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root

    default property alias content: row.data
    property bool hovered: mouse.containsMouse

    implicitWidth: row.implicitWidth + Appearance.spacing * 4
    implicitHeight: Appearance.barHeight - 12

    Rectangle {
        anchors.fill: parent
        radius: Appearance.radius
        color: Colors.background
        opacity: root.hovered ? Appearance.hoverOpacity + 0.15 : Appearance.glassOpacity
        border.width: 1
        border.color: Colors.color(1)

        Behavior on opacity {
            NumberAnimation { duration: Appearance.animFast }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton // widgets add their own click areas
    }
}