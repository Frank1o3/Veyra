import QtQuick 2.15
import QtQuick.Layouts 1.15
import "modules"

Item {
    Background {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 40

        Clock {
            Layout.alignment: Qt.AlignHCenter
        }

        LoginPanel {
            Layout.alignment: Qt.AlignHCenter
        }
    }

    PowerControls {
        anchors.fill: parent
    }
}