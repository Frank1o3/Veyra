import QtQuick
import qs.config
import qs.services

Item {
    id: root
    implicitWidth: icon.implicitWidth + 6
    implicitHeight: icon.implicitHeight

    // Injected by Bar.qml — per-monitor open state.
    property bool panelOpen: false
    signal togglePanel()

    Text {
        id: icon
        anchors.centerIn: parent
        color: root.panelOpen ? Colors.color(4) : Colors.foreground
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
        font.weight: Font.Bold
        text: Notifications.dnd ? "󰂛" : "󰂚"
    }

    Rectangle {
        visible: Notifications.count > 0 && !Notifications.dnd
        width: 14
        height: 14
        radius: 7
        color: Colors.color(1)
        anchors.top: icon.top
        anchors.right: icon.right
        anchors.topMargin: -4
        anchors.rightMargin: -6

        Text {
            anchors.centerIn: parent
            text: Notifications.count > 9 ? "9+" : Notifications.count
            color: Colors.background
            font.pixelSize: 9
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.togglePanel()
    }
}
