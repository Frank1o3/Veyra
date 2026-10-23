import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config

Item {
    id: root
    signal clicked
    property string text: ""
    property string icon: ""
    property bool accent: false

    implicitWidth: label.implicitWidth + (root.icon.length > 0 ? 28 : 20) + 20
    implicitHeight: 32

    // Soft glow behind accent buttons — a small hint of the same
    // ambient-shadow language used on the bigger glass panels, scaled
    // down and tinted so it reads as "glowing" rather than "shadowed".
    Rectangle {
        id: glowSource
        anchors.fill: parent
        radius: 10
        color: Colors.color(4)
        visible: false
    }

    Glow {
        anchors.fill: glowSource
        source: glowSource
        visible: root.accent
        radius: 14
        samples: 29
        color: Colors.color(4)
        spread: 0.15
        opacity: 0.35
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 10
        color: root.accent ? Colors.color(4) : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
        border.width: root.accent ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        Behavior on color {
            ColorAnimation {
                duration: Appearance.animFast
            }
        }
    }

    // Top-edge highlight, same "light catching glass" idea as GlassCard,
    // scaled down to button size.
    Rectangle {
        anchors.top: surface.top
        anchors.left: surface.left
        anchors.right: surface.right
        anchors.margins: 1
        height: surface.height * 0.5
        radius: surface.radius
        color: Qt.rgba(1, 1, 1, root.accent ? 0.12 : Appearance.glassHighlightOpacity)
    }

    Row {
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.accent ? Colors.background : Colors.foreground
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
            font.weight: Font.Bold
        }
        Text {
            id: label
            text: root.text
            color: root.accent ? Colors.background : Colors.foreground
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
            font.bold: root.accent
            font.weight: Font.Bold
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
