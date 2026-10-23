pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpuUsage: 0
    property int igpuUsage: -1

    Process {
        id: proc
        command: [`${Quickshell.env("HOME")}/.config/quickshell/scripts/sysmon.sh`]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                try {
                    const data = JSON.parse(line);
                    root.cpuUsage = data.cpu;
                    root.igpuUsage = data.igpu;
                } catch (e) {}
            }
        }
    }
}
