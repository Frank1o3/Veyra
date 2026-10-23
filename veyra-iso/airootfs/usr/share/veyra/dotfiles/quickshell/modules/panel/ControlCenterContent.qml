import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import qs.config
import qs.config.components
import qs.services

ColumnLayout {
    id: root
    spacing: Appearance.sectionSpacing

    // ============================================================
    // Backing state
    // ============================================================

    property bool wifiOn: false
    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    property int memPercent: 0
    property int cpuTemp: 0
    property string clockText: Qt.formatDateTime(new Date(), "dddd, MMM d · hh:mm AP")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.clockText = Qt.formatDateTime(new Date(), "dddd, MMM d · hh:mm AP")
    }

    Process {
        id: wifiStatus
        command: ["nmcli", "radio", "wifi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.wifiOn = this.text.trim() === "enabled"
        }
    }
    Process { id: wifiSet }

    Process {
        id: memProc
        command: ["sh", "-c", "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const total = Number(lines[0].match(/\d+/)[0]);
                const avail = Number(lines[1].match(/\d+/)[0]);
                root.memPercent = Math.round((1 - avail / total) * 100);
            }
        }
    }

    Process {
        id: tempProc
        command: ["cat", "/sys/class/hwmon/hwmon2/temp1_input"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.cpuTemp = Math.round(Number(this.text.trim()) / 1000)
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (!GameMode.active) {
                memProc.running = true;
                tempProc.running = true;
            }
        }
    }

    // ============================================================
    // Header
    // ============================================================

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: "Control Center"
                color: Colors.foreground
                font.family: Appearance.fontFamily
                font.pixelSize: 20
                font.bold: true
            }
            Text {
                text: root.clockText
                color: Colors.color(7)
                font.family: Appearance.fontFamily
                font.pixelSize: 12
                opacity: 0.8
            }
        }

        Rectangle {
            radius: 999
            color: GameMode.active ? Qt.rgba(0.96, 0.76, 0.86, 0.15) : Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            border.color: GameMode.active ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            implicitWidth: statusText.implicitWidth + 20
            implicitHeight: 28

            Text {
                id: statusText
                anchors.centerIn: parent
                text: GameMode.active ? "󰊴  Game mode" : (Notifications.dnd ? "󰂛  Focus" : "● Ready")
                color: GameMode.active ? Colors.color(4) : Colors.foreground
                font.family: Appearance.fontFamily
                font.pixelSize: 11
                font.bold: true
                opacity: 0.9
            }
        }
    }

    // ============================================================
    // Quick Settings – 2x2 toggle grid
    // ============================================================

    Rectangle {
        Layout.fillWidth: true
        radius: Appearance.cardRadius
        color: Qt.rgba(1, 1, 1, 0.045)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
        implicitHeight: quickCol.implicitHeight + Appearance.cardPadding * 2

        ColumnLayout {
            id: quickCol
            anchors.fill: parent
            anchors.margins: Appearance.cardPadding
            spacing: 12

            SectionLabel { icon: "󰐥"; text: "Quick Settings" }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                QuickToggle {
                    Layout.fillWidth: true
                    icon: "󰤨"
                    label: "Wi-Fi"
                    active: root.wifiOn
                    subLabel: root.wifiOn ? "Enabled" : "Disabled"
                    onClicked: {
                        root.wifiOn = !root.wifiOn;
                        wifiSet.command = ["nmcli", "radio", "wifi", root.wifiOn ? "on" : "off"];
                        wifiSet.running = true;
                    }
                }

                QuickToggle {
                    Layout.fillWidth: true
                    icon: "󰂯"
                    label: "Bluetooth"
                    active: root.btAdapter?.enabled ?? false
                    subLabel: (root.btAdapter?.enabled ?? false)
                        ? (root.btAdapter.devices.values.filter(d => d.connected).length + " connected")
                        : "Disabled"
                    onClicked: {
                        if (root.btAdapter)
                            root.btAdapter.enabled = !root.btAdapter.enabled;
                    }
                }

                QuickToggle {
                    Layout.fillWidth: true
                    icon: "󰂛"
                    label: "Do Not Disturb"
                    active: Notifications.dnd
                    subLabel: Notifications.dnd ? "On" : "Off"
                    onClicked: Notifications.toggleDnd()
                }

                QuickToggle {
                    Layout.fillWidth: true
                    icon: "󰊴"
                    label: "Game Mode"
                    active: GameMode.active
                    interactive: false
                    subLabel: GameMode.active ? "Active" : "Idle"
                }
            }

            // Paired Bluetooth devices
            ColumnLayout {
                Layout.fillWidth: true
                visible: (root.btAdapter?.enabled ?? false) && root.btAdapter.devices.values.length > 0
                spacing: 6
                Layout.topMargin: 2

                Repeater {
                    model: root.btAdapter ? root.btAdapter.devices.values : []

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.04)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: modelData.connected ? "󰂱" : "󰂯"
                                color: modelData.connected ? Colors.color(4) : Colors.color(8)
                                font.pixelSize: Appearance.fontSize + 1
                            }
                            Text {
                                text: modelData.name
                                color: Colors.foreground
                                font.family: Appearance.fontFamily
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            GlassButton {
                                text: modelData.connected ? "Disconnect" : "Connect"
                                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                            }
                        }
                    }
                }
            }

            // Game mode banner
            Rectangle {
                Layout.fillWidth: true
                visible: GameMode.active
                radius: 10
                color: Qt.rgba(0.96, 0.76, 0.86, 0.10)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)
                implicitHeight: gmRow.implicitHeight + 16

                RowLayout {
                    id: gmRow
                    anchors.fill: parent
                    anchors.margins: 10
                    Text {
                        text: "󰊴  Game Mode active — stats paused, only critical alerts shown"
                        color: Colors.foreground
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.fontSize
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        opacity: 0.8
                    }
                }
            }
        }
    }

    // ============================================================
    // System – at-a-glance health
    // ============================================================

    Rectangle {
        Layout.fillWidth: true
        radius: Appearance.cardRadius
        color: Qt.rgba(1, 1, 1, 0.045)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
        implicitHeight: sysCol.implicitHeight + Appearance.cardPadding * 2

        ColumnLayout {
            id: sysCol
            anchors.fill: parent
            anchors.margins: Appearance.cardPadding
            spacing: 12

            SectionLabel { icon: "󰍛"; text: "System" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { label: "CPU", value: SysMonitor.cpuUsage + "%", accent: SysMonitor.cpuUsage >= 85 ? "#f38ba8" : (SysMonitor.cpuUsage >= 60 ? "#f9e2af" : Colors.color(1)), icon: "󰍛" },
                        { label: "RAM", value: root.memPercent + "%", accent: root.memPercent >= 85 ? "#f38ba8" : Colors.color(4), icon: "󰘚" },
                        { label: "Temp", value: root.cpuTemp, accent: root.cpuTemp >= 85 ? "#f38ba8" : (root.cpuTemp >= 70 ? "#f9e2af" : Colors.color(2)), icon: "󰔄" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.035)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.04)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: modelData.icon + " " + modelData.value
                                color: modelData.accent
                                font.family: Appearance.fontFamily
                                font.pixelSize: 18
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: modelData.label
                                color: Colors.color(7)
                                font.family: Appearance.fontFamily
                                font.pixelSize: 10
                                opacity: 0.7
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // Quick Controls – volume / brightness
    // ============================================================

    Rectangle {
        Layout.fillWidth: true
        radius: Appearance.cardRadius
        color: Qt.rgba(1, 1, 1, 0.045)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
        implicitHeight: ctrlCol.implicitHeight + Appearance.cardPadding * 2

        ColumnLayout {
            id: ctrlCol
            anchors.fill: parent
            anchors.margins: Appearance.cardPadding
            spacing: 14

            SectionLabel { icon: "󰕾"; text: "Quick Controls" }

            readonly property PwNode sink: Pipewire.defaultAudioSink
            PwObjectTracker {
                objects: [ctrlCol.sink]
            }

            GlassSlider {
                Layout.fillWidth: true
                icon: "󰕾"
                from: 0
                to: 1
                value: ctrlCol.sink?.audio?.volume ?? 0
                onMoved: v => {
                    if (ctrlCol.sink?.audio)
                        ctrlCol.sink.audio.volume = v;
                }
            }

            GlassSlider {
                id: blSlider
                Layout.fillWidth: true
                icon: "󰃟"
                from: 1
                to: 100
                value: 50
                onMoved: v => {
                    setBrightness.command = ["brightnessctl", "set", Math.round(v) + "%"];
                    setBrightness.running = true;
                }

                Process {
                    id: getBrightness
                    command: ["brightnessctl", "-m"]
                    running: true
                    stdout: StdioCollector {
                        onStreamFinished: {
                            const match = this.text.match(/,(\d+)%,/);
                            if (match)
                                blSlider.value = Number(match[1]);
                        }
                    }
                }
                Process { id: setBrightness }
            }
        }
    }

    // ============================================================
    // Media
    // ============================================================

    Rectangle {
        Layout.fillWidth: true
        visible: Mpris.players.values.length > 0
        radius: Appearance.cardRadius
        color: Qt.rgba(1, 1, 1, 0.045)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
        implicitHeight: mediaCol.implicitHeight + Appearance.cardPadding * 2

        ColumnLayout {
            id: mediaCol
            anchors.fill: parent
            anchors.margins: Appearance.cardPadding
            spacing: 12

            SectionLabel { icon: "󰎈"; text: "Now Playing" }

            property var player: Mpris.players.values[0] ?? null

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Album art placeholder (could be extended later)
                Rectangle {
                    width: 60
                    height: 60
                    radius: 8
                    color: Qt.rgba(1,1,1,0.06)
                    visible: false
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: mediaCol.player ? mediaCol.player.trackTitle : ""
                        color: Colors.foreground
                        font.family: Appearance.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: mediaCol.player ? mediaCol.player.trackArtist : ""
                        color: Colors.color(7)
                        font.family: Appearance.fontFamily
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        opacity: 0.8
                    }

                    RowLayout {
                        spacing: 8
                        Layout.topMargin: 6

                        GlassButton {
                            icon: "󰒮"
                            onClicked: mediaCol.player?.previous()
                        }
                        GlassButton {
                            icon: mediaCol.player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                            accent: true
                            onClicked: mediaCol.player?.togglePlaying()
                        }
                        GlassButton {
                            icon: "󰒭"
                            onClicked: mediaCol.player?.next()
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // Notifications
    // ============================================================

    Rectangle {
        Layout.fillWidth: true
        radius: Appearance.cardRadius
        color: Qt.rgba(1, 1, 1, 0.045)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
        implicitHeight: notifCol.implicitHeight + Appearance.cardPadding * 2

        ColumnLayout {
            id: notifCol
            anchors.fill: parent
            anchors.margins: Appearance.cardPadding
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                SectionLabel {
                    icon: "󰂚"
                    text: Notifications.count > 0 ? ("Notifications · " + Notifications.count) : "Notifications"
                    Layout.fillWidth: true
                }
                GlassButton {
                    visible: notifList.count > 0
                    icon: "󰆴"
                    text: "Clear All"
                    onClicked: Notifications.clearAll()
                }
            }

            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(360, contentHeight)
                clip: true
                spacing: 8
                model: Notifications.list

                delegate: Rectangle {
                    required property var modelData
                    width: notifList.width
                    height: contentCol.implicitHeight + 20
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.04)

                    Rectangle {
                        width: 3
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        radius: 2
                        color: modelData.urgency === NotificationUrgency.Critical ? "#f38ba8" : Colors.color(4)
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: 12
                        anchors.leftMargin: 16
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.appName
                                color: Colors.color(7)
                                font.pixelSize: 11
                                font.family: Appearance.fontFamily
                                Layout.fillWidth: true
                                opacity: 0.8
                            }
                            GlassButton {
                                icon: "✕"
                                onClicked: Notifications.dismiss(modelData)
                            }
                        }
                        Text {
                            text: modelData.summary
                            color: Colors.foreground
                            font.bold: true
                            font.family: Appearance.fontFamily
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: modelData.body.length > 0
                            text: modelData.body
                            color: Colors.foreground
                            opacity: 0.7
                            font.family: Appearance.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: notifList.count === 0
                    text: "No notifications"
                    color: Colors.color(8)
                    font.family: Appearance.fontFamily
                    opacity: 0.6
                }
            }
        }
    }
}