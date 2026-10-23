import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import Quickshell
import Quickshell.Services.SystemTray

import qs.config

RowLayout {
    id: root

    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem

            required property var modelData

            implicitWidth: 20
            implicitHeight: 20

            // StatusNotifierItem tooltip text (e.g. RVPN's connected/disconnected
            // status). The item only publishes this over D-Bus -- Quickshell, as
            // the tray host, is responsible for actually displaying it on hover.
            readonly property string tooltipText: {
                const titleText = trayItem.modelData.tooltipTitle ?? "";
                const descriptionText = trayItem.modelData.tooltipDescription ?? "";

                if (titleText.length > 0 && descriptionText.length > 0)
                    return titleText + "\n" + descriptionText;
                if (titleText.length > 0)
                    return titleText;
                if (descriptionText.length > 0)
                    return descriptionText;

                // Fall back to the app name so items that never set a
                // tooltip (unlike RVPN) still show something identifying.
                return trayItem.modelData.title ?? "";
            }

            ToolTip.visible: hoverArea.containsMouse && trayItem.tooltipText.length > 0
            ToolTip.text: trayItem.tooltipText
            ToolTip.delay: 400
            ToolTip.timeout: 5000

            Rectangle {
                anchors.fill: parent
                radius: 6

                color: hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animFast
                    }
                }
            }

            Image {
                anchors.fill: parent
                anchors.margins: 2

                source: trayItem.modelData.icon

                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            QsMenuAnchor {
                id: menuAnchor

                menu: trayItem.modelData.menu

                // Associate the platform menu with the actual
                // Quickshell window containing this tray item.
                anchor.window: trayItem.QsWindow.window

                // Position the menu relative to the tray icon.
                anchor.onAnchoring: {
                    const window = trayItem.QsWindow.window;

                    const rect = window.contentItem.mapFromItem(trayItem, 0, trayItem.height, trayItem.width, trayItem.height);

                    menuAnchor.anchor.rect = rect;
                }
            }

            MouseArea {
                id: hoverArea

                anchors.fill: parent

                hoverEnabled: true

                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: mouse => {
                    const item = trayItem.modelData;

                    if (mouse.button === Qt.RightButton) {
                        if (item.hasMenu) {
                            menuAnchor.open();
                        }
                    } else if (mouse.button === Qt.LeftButton) {
                        if (item.onlyMenu && item.hasMenu) {
                            menuAnchor.open();
                        } else {
                            item.activate();
                        }
                    } else if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    }
                }
            }
        }
    }
}
