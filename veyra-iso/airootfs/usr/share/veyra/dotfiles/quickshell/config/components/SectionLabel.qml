import QtQuick
import qs.config

Row {
    id: root
    property string icon: ""
    property string text: ""
    spacing: 6

    Text {
        visible: root.icon.length > 0
        text: root.icon
        color: Colors.color(4)
        font.family: Appearance.fontFamily
        font.pixelSize: 12
    }
    Text {
        text: root.text
        color: Colors.color(7)
        font.family: Appearance.fontFamily
        font.pixelSize: 11
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
    }
}