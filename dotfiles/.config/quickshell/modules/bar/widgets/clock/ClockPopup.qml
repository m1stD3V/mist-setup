pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Clock popup: alarms, countdown, pomodoro, reminders and world clocks.
//
// Each tab is its own component with intrinsic height, so the popup grows to
// fit the active tab instead of the old fixed `bodyHeight` table (which clipped
// the timer and pomodoro tabs because their content was taller than the value
// picked for them).
BarPopup {
    id: root

    enum Tab {
        Alarm,
        Timer,
        Pomodoro,
        Remind,
        World
    }

    property int tab: ClockPopup.Tab.Alarm

    // reminder and timezone fields need real keyboard input
    grabKeyboard: true
    screenEdge: "right"
    title: "CLOCK"
    contentWidth: Theme.popupWidth
    open: false

    readonly property var tabModel: [{
            "label": "ALARM",
            "value": ClockPopup.Tab.Alarm
        }, {
            "label": "TIMER",
            "value": ClockPopup.Tab.Timer
        }, {
            "label": "POMODORO",
            "value": ClockPopup.Tab.Pomodoro
        }, {
            "label": "REMIND",
            "value": ClockPopup.Tab.Remind
        }, {
            "label": "WORLD",
            "value": ClockPopup.Tab.World
        }]

    // The tab Loader lives inside the content Component, so it is reachable
    // only through this handle. Callers used to read the id directly, which the
    // component boundary does not allow.
    property var tabItem: null

    function focusTabField(): void {
        if (!root.open || !root.tabItem)
            return;
        const page = root.tabItem.item;
        if (page && page.focusField)
            page.focusField();
    }

    onOpenChanged: if (open)
        Qt.callLater(root.focusTabField)

    onTabChanged: Qt.callLater(root.focusTabField)

    content: Component {
        Column {
            width: parent.width
            spacing: Theme.barSpacing

            Component.onCompleted: root.tabItem = tabLoader
            Component.onDestruction: {
                if (root.tabItem === tabLoader)
                    root.tabItem = null;
            }

            // ---- ringing alert ----
            Rectangle {
                visible: TimeTools.alertActive
                width: parent.width
                height: visible ? 28 : 0
                color: Theme.surfaceHigh
                border.width: 1
                border.color: Theme.blink ? Theme.textHigh : Theme.borderHigh

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: stopBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (TimeTools.alertKind === "alarm")
                            return "ALARM RINGING";
                        if (TimeTools.alertKind === "timer")
                            return "TIMER DONE";
                        return "POMODORO " + TimeTools.pomoLabel;
                    }
                    color: Theme.blink ? Theme.textHigh : Theme.text
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                TextButton {
                    id: stopBtn

                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    label: "STOP"
                    danger: true
                    onClicked: TimeTools.dismissAlert()
                }
            }

            // ---- tab bar ----
            Row {
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.tabModel

                    TextButton {
                        required property var modelData

                        label: modelData.label
                        active: root.tab === modelData.value
                        onClicked: root.tab = modelData.value
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.borderHigh
            }

            // ---- active tab ----
            Loader {
                id: tabLoader

                width: parent.width
                sourceComponent: {
                    switch (root.tab) {
                    case ClockPopup.Tab.Timer:
                        return timerTab;
                    case ClockPopup.Tab.Pomodoro:
                        return pomodoroTab;
                    case ClockPopup.Tab.Remind:
                        return remindersTab;
                    case ClockPopup.Tab.World:
                        return worldTab;
                    default:
                        return alarmTab;
                    }
                }
            }
        }
    }

    Component {
        id: alarmTab

        AlarmTab {}
    }

    Component {
        id: timerTab

        TimerTab {}
    }

    Component {
        id: pomodoroTab

        PomodoroTab {}
    }

    Component {
        id: remindersTab

        RemindersTab {}
    }

    Component {
        id: worldTab

        WorldTab {}
    }
}
