pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import qs.services

Singleton {
    id: root

    property bool dnd: false
    readonly property var list: server.trackedNotifications
    readonly property int count: list ? list.values.length : 0

    signal popup(var notification)

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true;

            // In Game Mode, only urgent/critical notifications interrupt you.
            const suppressedByGameMode = GameMode.active && notification.urgency !== NotificationUrgency.Critical;

            if (!root.dnd && !suppressedByGameMode) {
                root.popup(notification);
            }
        }
    }

    function dismiss(notification) {
        notification.dismiss();
    }

    function clearAll() {
        const items = server.trackedNotifications.values.slice();
        items.forEach(n => n.dismiss());
    }

    function toggleDnd() {
        root.dnd = !root.dnd;
    }
}
