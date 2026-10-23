import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.config

RowLayout {
    id: root
    spacing: 6

    Repeater {
        model: Hyprland.workspaces.values

        delegate: Rectangle {
            id: ws
            required property var modelData
            property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
            property bool occupied: modelData.windows > 0

            implicitWidth: active ? 22 : 16
            implicitHeight: 10
            radius: 5
            color: active ? Colors.color(4) : (occupied ? Qt.rgba(1, 1, 1, 0.33) : Qt.rgba(1, 1, 1, 0.12))
            border.width: active ? 0 : 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Appearance.animFast
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animFast
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + ws.modelData.id)
            }
        }
    }
}
