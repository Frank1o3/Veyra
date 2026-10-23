pragma Singleton

import QtQuick 2.15

QtObject {
    readonly property color bg: config.colorBackground || "#1e1e2e"
    readonly property color fg: config.colorForeground || "#cdd6f4"
    readonly property color accent: config.colorAccent || "#89b4fa"
    // Derived, not read from theme.conf.user — keeps sddm-theme-sync.py untouched
    readonly property color accent2: Qt.lighter(accent, 1.35)
    readonly property color border: config.colorBorder || "#313244"

    readonly property color surface: Qt.rgba(bg.r, bg.g, bg.b, 0.60)
    readonly property color input: Qt.rgba(1, 1, 1, 0.07)
    readonly property color inputBorder: Qt.rgba(1, 1, 1, 0.12)
    readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.62)
    readonly property color error: "#f38ba8"

    readonly property string fontFamily: config.fontFamily || "SpaceMono Nerd Font"

    readonly property int radius: 12
    readonly property int cardRadius: 22

    readonly property real glassOpacity: 0.60
    readonly property real hoverOpacity: 0.10
    readonly property real panelOpacity: 0.86

    readonly property int animFast: 150
    readonly property int animNormal: 260
}
