
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Notifications
import qs.config
import qs.services

Scope {
    id: root

    Connections {
        target: Notifications

        function onPopup(notification) {
            toastComponent.createObject(col, {
                notification: notification
            });
        }
    }

    PanelWindow {
        id: win

        visible: col.children.length > 0
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:toasts"

        anchors {
            top: true
            right: true
        }

        implicitWidth: 340
        implicitHeight: col.implicitHeight + 24

        Column {
            id: col

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12

            width: 316
            spacing: 8
        }
    }

    Component {
        id: toastComponent

        Rectangle {
            id: toast

            required property var notification

            property bool entered: false
            property bool closing: false

            width: parent ? parent.width : 316
            implicitHeight: toastCol.implicitHeight + 24

            radius: 16
            color: Colors.background

            border.color: notification.urgency === NotificationUrgency.Critical
                ? "#f38ba8"
                : Colors.color(4)

            border.width: notification.urgency === NotificationUrgency.Critical
                ? 2
                : 1

            opacity: !entered ? 0 : (closing ? 0 : 0.97)
            scale: !entered ? 0.9 : (closing ? 0.85 : 1.0)

            layer.enabled: true

            layer.effect: DropShadow {
                transparentBorder: true
                radius: Appearance.shadowRadiusSmall
                samples: Appearance.shadowRadiusSmall * 2 + 1
                verticalOffset: Appearance.shadowOffsetSmall
                color: Appearance.shadowColorAmbient
            }

            transform: Translate {
                x: toast.entered && !toast.closing ? 0 : 24

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.animNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animNormal
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.02
                }
            }

            Component.onCompleted: entered = true

            function close() {
                if (closing)
                    return;

                closing = true;
                destroyTimer.start();
            }

            function defaultDuration() {
                switch (notification.urgency) {
                case NotificationUrgency.Critical:
                    return 10000;
                case NotificationUrgency.Low:
                    return 2500;
                default:
                    return 5000;
                }
            }

            Timer {
                id: destroyTimer

                interval: Appearance.animNormal

                onTriggered: toast.destroy()
            }

            Timer {
                interval: toast.notification.expireTimeout > 0
                    ? toast.notification.expireTimeout
                    : toast.defaultDuration()

                running: true

                onTriggered: toast.close()
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1

                height: parent.height * Appearance.glassHighlightHeightRatio
                radius: parent.radius

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(
                            1,
                            1,
                            1,
                            Appearance.glassHighlightOpacity
                        )
                    }

                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(1, 1, 1, 0)
                    }
                }
            }

            ColumnLayout {
                id: toastCol

                anchors.fill: parent
                anchors.margins: 12

                spacing: 6

                Text {
                    text: toast.notification.appName

                    color: Colors.color(7)
                    font.pixelSize: 11
                    font.family: Appearance.fontFamily
                    font.weight: Font.Bold

                    Layout.fillWidth: true
                }

                Text {
                    text: toast.notification.summary

                    color: Colors.foreground
                    font.bold: true
                    font.family: Appearance.fontFamily
                    font.weight: Font.Bold

                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Text {
                    visible: toast.notification.body.length > 0

                    text: toast.notification.body

                    color: Colors.foreground
                    opacity: 0.85
                    font.family: Appearance.fontFamily
                    font.weight: Font.Bold

                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                // Notification action buttons.
                RowLayout {
                    visible: toast.notification.actions.length > 0

                    spacing: 6

                    Layout.fillWidth: true

                    Repeater {
                        model: toast.notification.actions

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 34

                            radius: 9
                            color: Colors.color(4)

                            Text {
                                anchors.centerIn: parent

                                text: modelData.text

                                color: Colors.foreground
                                font.family: Appearance.fontFamily
                                font.bold: true
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    modelData.invoke();
                                    toast.close();
                                }

                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            // Dismiss the toast when clicking outside its action buttons.
            MouseArea {
                anchors.fill: parent

                z: -1

                onClicked: toast.close()
            }
        }
    }
}