import QtQuick
import qs.config
import qs.services

Text {
    id: root
    readonly property int usage: SysMonitor.igpuUsage
    color: Colors.color(1)
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    font.weight: Font.Bold
    text: "󰢮 " + (usage >= 0 ? usage + "%" : "--")
}
