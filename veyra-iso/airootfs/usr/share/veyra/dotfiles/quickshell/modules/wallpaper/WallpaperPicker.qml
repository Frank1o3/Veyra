import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.config.components

Scope {
    id: root

    property bool open: false
    property bool mapped: false
    property var wallpapers: []

    function show() {
        listProc.running = true;
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
        target: "wallpaper"
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
        id: listProc
        command: ["python3", `${Quickshell.env("HOME")}/.config/quickshell/scripts/list-wallpapers.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.wallpapers = JSON.parse(this.text);
                } catch (e) {
                    root.wallpapers = [];
                }
            }
        }
    }

    Process {
        id: applyProc

        property string path: ""

        command: ["sh", Quickshell.env("HOME") + "/.config/hypr/scripts/set-wallpaper.sh", path]
    }

    function apply(path) {
        applyProc.path = path;
        applyProc.running = true;
        root.hide();
    }

    PanelWindow {
        id: win
        visible: root.mapped
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:wallpaper"

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

        onVisibleChanged: if (visible)
            searchNothing()
        function searchNothing() {
        } // placeholder for future search field focus

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()

            GlassCard {
                id: card
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.7, 900)
                height: Math.min(parent.height * 0.75, 640)
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
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "🖼  Choose Wallpaper"
                            color: Colors.foreground
                            font.family: Appearance.fontFamily
                            font.pixelSize: 18
                            font.bold: true
                            Layout.fillWidth: true
                            font.weight: Font.Bold
                        }
                        Button {
                            text: "✕"
                            flat: true
                            onClicked: root.hide()
                        }
                    }

                    GridView {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: 210
                        cellHeight: 130
                        model: root.wallpapers

                        delegate: Item {
                            id: cell
                            required property var modelData
                            width: grid.cellWidth - 10
                            height: grid.cellHeight - 10
                            property bool hovered: hoverArea.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: "transparent"
                                clip: true
                                border.width: cell.hovered ? 2 : 1
                                border.color: cell.hovered ? Colors.color(4) : Colors.color(8)
                                scale: cell.hovered ? 1.03 : 1.0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Appearance.animFast
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Appearance.animFast
                                    }
                                }

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: "file://" + cell.modelData.path
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 26
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    Text {
                                        anchors.centerIn: parent
                                        text: cell.modelData.name
                                        color: "#ffffff"
                                        font.family: Appearance.fontFamily
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        width: parent.width - 12
                                        horizontalAlignment: Text.AlignHCenter
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.apply(cell.modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }
}
