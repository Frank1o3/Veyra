import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects

import ".."
import "../components"

Item {
    id: root

    width: card.width
    height: card.height

    property real entrance: 0

    NumberAnimation {
        id: entranceAnim
        target: root
        property: "entrance"
        from: 0
        to: 1
        duration: Theme.animNormal + 140
        easing.type: Easing.OutCubic
    }

    Rectangle {
        id: shadowSource
        anchors.fill: card
        radius: Theme.cardRadius
        color: "black"
        visible: false
    }

    DropShadow {
        anchors.fill: shadowSource
        source: shadowSource
        radius: 28
        samples: 41
        horizontalOffset: 0
        verticalOffset: 10
        color: "#80000000"
        opacity: root.entrance
    }

    GlassCard {
        id: card

        width: 360
        height: loginCol.implicitHeight + 44

        anchors.centerIn: parent

        opacity: root.entrance
        scale: 0.92 + root.entrance * 0.08
        transformOrigin: Item.Center

        ColumnLayout {
            id: loginCol

            anchors.fill: parent
            anchors.margins: 22

            spacing: 14

            // ---------------------------------------------------
            // Greeting header
            // ---------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 42
                    height: 42
                    radius: 21
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)

                    Text {
                        anchors.centerIn: parent
                        text: "󰀄"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    Text {
                        text: "Welcome back"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        text: "Sign in to continue"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // ---------------------------------------------------
            // User
            // ---------------------------------------------------
            ComboBox {
                id: userCombo

                Layout.fillWidth: true
                implicitHeight: 44

                model: userModel
                textRole: "name"

                currentIndex: userModel.lastIndex

                font.family: Theme.fontFamily

                indicator: Text {
                    x: userCombo.width - width - 12
                    y: (userCombo.height - height) / 2
                    text: "󰄽"
                    color: userCombo.activeFocus ? Theme.accent : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }

                delegate: ItemDelegate {
                    width: userCombo.width
                    implicitHeight: 38
                    highlighted: userCombo.highlightedIndex === index

                    contentItem: Text {
                        text: model.name
                        color: parent.highlighted ? Theme.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 8
                        color: parent.highlighted ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    }
                }

                popup: Popup {
                    y: userCombo.height + 6
                    width: userCombo.width
                    implicitHeight: Math.min(contentItem.implicitHeight + 8, 220)
                    padding: 4

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: userCombo.popup.visible ? userCombo.delegateModel : null
                        currentIndex: userCombo.highlightedIndex
                        boundsBehavior: Flickable.StopAtBounds
                    }

                    background: Rectangle {
                        radius: Theme.radius
                        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.94)
                        border.width: 1
                        border.color: Theme.inputBorder
                    }
                }

                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.input
                    border.width: 1
                    border.color: userCombo.activeFocus ? Theme.accent : Theme.inputBorder

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }
                }

                contentItem: Text {
                    text: "󰀄  " + userCombo.displayText
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                    rightPadding: 30
                }
            }

            // ---------------------------------------------------
            // Password
            // ---------------------------------------------------
            TextField {
                id: passwordField

                Layout.fillWidth: true
                implicitHeight: 44

                echoMode: TextInput.Password
                placeholderText: "Password"

                font.family: Theme.fontFamily
                leftPadding: 34
                rightPadding: 10

                color: Theme.fg
                placeholderTextColor: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)

                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.input
                    border.width: 1
                    border.color: passwordField.activeFocus ? Theme.accent : Theme.inputBorder

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰌆"
                        color: passwordField.activeFocus ? Theme.accent : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }
                }

                onAccepted: login()

                focus: true
            }

            // ---------------------------------------------------
            // Session
            // ---------------------------------------------------
            ComboBox {
                id: sessionCombo

                Layout.fillWidth: true
                implicitHeight: 44

                model: sessionModel
                textRole: "name"

                currentIndex: sessionModel.lastIndex

                font.family: Theme.fontFamily

                indicator: Text {
                    x: sessionCombo.width - width - 12
                    y: (sessionCombo.height - height) / 2
                    text: "󰄽"
                    color: sessionCombo.activeFocus ? Theme.accent : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }

                delegate: ItemDelegate {
                    width: sessionCombo.width
                    implicitHeight: 38
                    highlighted: sessionCombo.highlightedIndex === index

                    contentItem: Text {
                        text: model.name
                        color: parent.highlighted ? Theme.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        leftPadding: 12
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 8
                        color: parent.highlighted ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    }
                }

                popup: Popup {
                    y: sessionCombo.height + 6
                    width: sessionCombo.width
                    implicitHeight: Math.min(contentItem.implicitHeight + 8, 220)
                    padding: 4

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: sessionCombo.popup.visible ? sessionCombo.delegateModel : null
                        currentIndex: sessionCombo.highlightedIndex
                        boundsBehavior: Flickable.StopAtBounds
                    }

                    background: Rectangle {
                        radius: Theme.radius
                        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.94)
                        border.width: 1
                        border.color: Theme.inputBorder
                    }
                }

                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.input
                    border.width: 1
                    border.color: sessionCombo.activeFocus ? Theme.accent : Theme.inputBorder

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }
                }

                contentItem: Text {
                    text: "󰇄  " + sessionCombo.displayText
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                    rightPadding: 30
                }
            }

            Text {
                id: errorLabel

                text: ""

                color: Theme.error

                font.family: Theme.fontFamily
                font.pixelSize: 12

                Layout.alignment: Qt.AlignHCenter

                visible: text.length > 0
            }

            // ---------------------------------------------------
            // Log in
            // ---------------------------------------------------
            Button {
                id: loginButton

                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 44

                text: "Log In"
                font.family: Theme.fontFamily
                font.bold: true

                background: Rectangle {
                    radius: Theme.radius
                    color: loginButton.pressed ? Qt.darker(Theme.accent, 1.15) : (loginButton.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }
                }

                contentItem: Text {
                    text: loginButton.text
                    color: Theme.bg
                    font: loginButton.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: login()
            }
        }
    }

    function login() {
        sddm.login(userCombo.currentText, passwordField.text, sessionCombo.currentIndex);
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            errorLabel.text = "Login failed — try again";

            passwordField.text = "";
            passwordField.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        entranceAnim.start();
        passwordField.forceActiveFocus();
    }
}
