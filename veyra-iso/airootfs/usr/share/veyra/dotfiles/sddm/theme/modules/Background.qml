import QtQuick 2.15
import Qt5Compat.GraphicalEffects

import ".."

Item {
    id: root

    Image {
        id: wallpaper

        anchors.fill: parent

        source: config.background ? Qt.resolvedUrl("../" + config.background) : Qt.resolvedUrl("../backgrounds/default.jpg")

        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true

        visible: false
    }

    // Qt5 replacement for MultiEffect's blur — QtQuick.Effects doesn't exist
    // in the greeter, so the compatibility FastBlur keeps the wallpaper soft.
    FastBlur {
        anchors.fill: wallpaper
        source: wallpaper
        radius: 64
        transparentBorder: false
    }

    // Dimming previously came from MultiEffect's `brightness: -0.08`.
    // A plain overlay does the same job without an extra shader pass.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.40
    }

    // Slightly darker lower edge, so the power controls stay legible.
    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "#00000015"
            }

            GradientStop {
                position: 0.55
                color: "#00000022"
            }

            GradientStop {
                position: 1.0
                color: "#00000090"
            }
        }
    }

    // Very subtle tint veil behind the login UI, matches Theme.bg.
    Rectangle {
        anchors.fill: parent

        color: Theme.bg
        opacity: 0.08
    }
}
