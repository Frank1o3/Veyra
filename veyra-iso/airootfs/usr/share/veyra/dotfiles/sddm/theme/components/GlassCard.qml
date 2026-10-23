import QtQuick 2.15

import ".."

Rectangle {
    id: root

    property real glassOpacity: Theme.glassOpacity

    radius: Theme.cardRadius

    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, glassOpacity)

    border.width: 1
    border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.85)

    // A soft top-edge highlight so the card reads as "glass" rather
    // than a flat panel, matching the pill/panel styling used across
    // the Quickshell bar and power menu.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        height: parent.height * 0.45
        radius: parent.radius

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(1, 1, 1, 0.07)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(1, 1, 1, 0.0)
            }
        }
    }
}
