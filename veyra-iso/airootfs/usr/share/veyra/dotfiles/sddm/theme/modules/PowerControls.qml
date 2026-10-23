import QtQuick 2.15
import QtQuick.Layouts 1.15

import ".."
import "../components"

Item {
    id: root

    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 10

        PowerButton {
            visible: sddm.canSuspend
            icon: "󰤄"
            label: "Sleep"
            onClicked: sddm.suspend()
        }

        PowerButton {
            visible: sddm.canReboot
            icon: "󰜉"
            label: "Reboot"
            onClicked: sddm.reboot()
        }

        PowerButton {
            visible: sddm.canPowerOff
            icon: "󰐥"
            label: "Shutdown"
            onClicked: sddm.powerOff()
        }
    }
}
