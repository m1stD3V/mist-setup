pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property alias server: server

    property bool dnd: false
    property int unread: 0
    property var history: []

    readonly property bool criticalActive: server.trackedNotifications.values.some(n => n.urgency === NotificationUrgency.Critical)

    function pushHistory(n: Notification): void {
        history = [{
                "app": (n.appName ?? "").toUpperCase(),
                "summary": n.summary ?? "",
                "body": n.body ?? "",
                "urgent": n.urgency === NotificationUrgency.Critical,
                "time": Qt.formatDateTime(new Date(), "hh:mm")
            }].concat(history).slice(0, 12);
        unread++;
    }

    function clearHistory(): void {
        history = [];
        unread = 0;
    }

    function dismissAt(index: int): void {
        history = history.filter((_, i) => i !== index);
    }

    function clearUnread(): void {
        unread = 0;
    }

    NotificationServer {
        id: server

        bodySupported: true
        bodyMarkupSupported: false
        bodyImagesSupported: false
        bodyHyperlinksSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        persistenceSupported: false
        keepOnReload: false

        onNotification: notification => {
            notification.tracked = true;
            root.pushHistory(notification);
        }
    }
}
