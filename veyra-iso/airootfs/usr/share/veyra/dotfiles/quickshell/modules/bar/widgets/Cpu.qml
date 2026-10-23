import QtQuick
import qs.config
import qs.services

Text {
    id: root
    readonly property int usage: SysMonitor.cpuUsage

    color: usage >= 85 ? "#f38ba8" : (usage >= 60 ? "#f9e2af" : Colors.color(1))
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    font.weight: Font.Bold
    text: "󰍛 " + usage + "%"

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
        }
    }
}
