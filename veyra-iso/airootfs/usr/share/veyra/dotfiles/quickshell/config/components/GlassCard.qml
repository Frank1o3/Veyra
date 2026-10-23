import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config

// Shared "glass" surface used by the bar pill, control center, power
// menu, wallpaper picker, launcher, and toasts — one place to tune the
// depth/translucency language instead of every surface re-deriving it.
//
// Layer order (back to front):
//   1. Ambient shadow  — wide, soft, low opacity — floating feel
//   2. Contact shadow   — tighter, darker — anchors it to the desktop
//   3. Base glass fill  — Colors.background at panelOpacity/glassOpacity
//   4. Accent tint      — very faint color(4) wash for depth
//   5. Top highlight    — gradient streak, light catching the "glass"
//   6. content          — default alias, whatever you put inside
Item {
    id: root

    default property alias content: inner.data

    property int cardRadius: Appearance.radius
    property real surfaceOpacity: Appearance.glassOpacity
    property color borderColor: Colors.color(1)
    property real borderWidth: 1

    property int shadowRadius: Appearance.shadowRadiusMedium
    property int shadowOffset: Appearance.shadowOffsetMedium
    property bool showHighlight: true
    property bool showTint: true

    // Independent corner control for panels that only round the bottom
    // (e.g. the control-center dropdown growing out of the bar pill).
    property int topLeftRadius: cardRadius
    property int topRightRadius: cardRadius
    property int bottomLeftRadius: cardRadius
    property int bottomRightRadius: cardRadius

    Rectangle {
        id: shadowSource
        anchors.fill: parent
        radius: root.cardRadius
        color: "black"
        visible: false
    }

    // Ambient — wide + soft
    DropShadow {
        anchors.fill: shadowSource
        source: shadowSource
        radius: root.shadowRadius
        samples: root.shadowRadius * 2 + 1
        verticalOffset: root.shadowOffset
        color: Appearance.shadowColorAmbient
    }

    // Contact — tight + dark, sits closer to the surface
    DropShadow {
        anchors.fill: shadowSource
        source: shadowSource
        radius: Math.round(root.shadowRadius * 0.35)
        samples: Math.round(root.shadowRadius * 0.35) * 2 + 1
        verticalOffset: Math.max(2, Math.round(root.shadowOffset * 0.35))
        color: Appearance.shadowColorContact
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Colors.background
        opacity: root.surfaceOpacity
        border.width: root.borderWidth
        border.color: root.borderColor

        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
    }

    // Faint accent wash for color depth rather than flat neutral glass.
    Rectangle {
        visible: root.showTint
        anchors.fill: parent
        color: Colors.color(4)
        opacity: Appearance.glassTintOpacity

        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
    }

    // Top-edge highlight streak
    Rectangle {
        visible: root.showHighlight
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.borderWidth
        height: parent.height * Appearance.glassHighlightHeightRatio
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, Appearance.glassHighlightOpacity) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

    // Subtle inner border for extra edge definition on top of the glass.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.borderWidth
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, Appearance.glassInnerBorderOpacity)

        topLeftRadius: Math.max(0, root.topLeftRadius - root.borderWidth)
        topRightRadius: Math.max(0, root.topRightRadius - root.borderWidth)
        bottomLeftRadius: Math.max(0, root.bottomLeftRadius - root.borderWidth)
        bottomRightRadius: Math.max(0, root.bottomRightRadius - root.borderWidth)
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
