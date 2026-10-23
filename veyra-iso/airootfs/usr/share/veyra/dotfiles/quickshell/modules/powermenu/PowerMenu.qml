import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.config.components
import qs.config

Scope {
    id: root

    property bool open: false
    property bool mapped: false

    function show() {
        mapped = true;
        open = true;
    }
    function hide() {
        open = false;
        closeTimer.start();
    }
    function toggle() {
        open ? hide() : show();
    }

    Timer {
        id: closeTimer
        interval: 220
        onTriggered: root.mapped = false
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.show();
        }
        function close(): void {
            root.hide();
        }
    }

    Process {
        id: notifyProc
    }
    Process {
        id: actionProc
    }

    function runAction(cmd, notifyTitle, notifyBody) {
        notifyProc.command = ["notify-send", "-t", "2000", notifyTitle, notifyBody];
        notifyProc.running = true;
        actionProc.command = ["sh", "-c", cmd];
        actionProc.running = true;
        root.hide();
    }

    PanelWindow {
        id: win
        visible: root.mapped
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:powermenu"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        HyprlandFocusGrab {
            windows: [win]
            active: root.open
            onCleared: root.hide()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()

            GlassCard {
                id: card
                anchors.centerIn: parent
                width: 380
                height: 300
                cardRadius: Appearance.radiusLarge
                surfaceOpacity: Appearance.panelOpacity
                shadowRadius: Appearance.shadowRadiusMedium
                shadowOffset: Appearance.shadowOffsetMedium

                opacity: root.open ? 1 : 0
                transformOrigin: Item.Center
                scale: root.open ? 1 : 0.9

                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.05
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }

                MouseArea {
                    anchors.fill: parent
                } // eat clicks so the card doesn't close itself

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    Text {
                        text: "⏻  Power Menu"
                        color: Colors.foreground
                        font.family: Appearance.fontFamily
                        font.pixelSize: 18
                        font.bold: true
                        font.weight: Font.Bold
                    }

                    GridLayout {
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        GlassButton {
                            Layout.fillWidth: true
                            icon: "󰌾"
                            text: "Lock"
                            onClicked: root.runAction("hyprlock || swaylock || loginctl lock-session", "Locking", "Screen locked")
                        }
                        GlassButton {
                            Layout.fillWidth: true
                            icon: "󰤄"
                            text: "Sleep"
                            onClicked: root.runAction("systemctl suspend", "Sleeping", "System suspending")
                        }
                        GlassButton {
                            Layout.fillWidth: true
                            icon: "󰋊"
                            text: "Hibernate"
                            onClicked: root.runAction("systemctl hibernate", "Hibernating", "System hibernating")
                        }
                        GlassButton {
                            Layout.fillWidth: true
                            icon: "󰜉"
                            text: "Reboot"
                            onClicked: root.runAction("systemctl reboot", "Rebooting", "System restarting")
                        }
                        GlassButton {
                            Layout.fillWidth: true
                            icon: "󰐥"
                            text: "Shutdown"
                            accent: true
                            onClicked: root.runAction("systemctl poweroff", "Shutting down", "System powering off")
                        }
                        GlassButton {
                            Layout.fillWidth: true
                            icon: "󰍃"
                            text: "Sign Out"
                            onClicked: root.runAction(
                                "loginctl terminate-user \"$USER\"",
                                "Signing out",
                                "Ending Hyprland session..."
                            )
                        }
                    }
                }
            }
        }
    }
}
