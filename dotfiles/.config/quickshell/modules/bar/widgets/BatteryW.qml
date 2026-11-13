import QtQuick
import qs.Theme
import qs.components
import qs.services

Row {
    id: root

    visible: Host.batteryPresent
    spacing: Theme.spacingSm

    Meter {
        anchors.verticalCenter: parent.verticalCenter
        label: "PWR"
        value: Host.batteryPct
        segments: 6
        showPct: false
    }

    RText {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(Host.batteryPct * 100) + "%" + (Host.batteryCharging ? "+" : "")
        color: Theme.textDim
        font.pixelSize: Theme.fontExtraSmall + 2
    }
}
