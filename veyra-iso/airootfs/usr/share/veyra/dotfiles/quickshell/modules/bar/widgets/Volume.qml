import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config

Text {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property real volume: sink?.audio?.volume ?? 0

    color: Colors.color(6)
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    font.weight: Font.Bold
    text: (muted ? "󰝟" : "󰕾") + " " + Math.round(volume * 100) + "%"

    PwObjectTracker {
        objects: [root.sink]
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && root.sink?.audio) {
                root.sink.audio.muted = !root.sink.audio.muted;
            }
        }
        onWheel: wheel => {
            if (!root.sink?.audio)
                return;
            const step = 0.05;
            const delta = wheel.angleDelta.y > 0 ? step : -step;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + delta));
        }
    }
}
