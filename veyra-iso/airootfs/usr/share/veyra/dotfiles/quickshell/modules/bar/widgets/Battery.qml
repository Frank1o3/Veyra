import QtQuick
import Quickshell.Services.UPower
import qs.config

Text {
    id: root
    readonly property UPowerDevice bat: UPower.displayDevice
    readonly property int percent: Math.round((bat?.percentage ?? 0) * 100)
    readonly property bool charging: bat?.state === UPowerDeviceState.Charging

    visible: bat?.isLaptopBattery ?? false
    color: charging ? Colors.color(4) : (percent <= 15 ? "#f38ba8" : (percent <= 30 ? "#f9e2af" : Colors.color(8)))
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    font.weight: Font.Bold
    text: (charging ? "󰂄 " : "󰁹 ") + percent + "%"

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animFast
        }
    }
}
