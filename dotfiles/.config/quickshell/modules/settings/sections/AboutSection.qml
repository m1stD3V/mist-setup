import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services
import "../controls" as Controls

Column {
    id: root

    width: parent ? parent.width : 0
    spacing: 12

    Controls.SettingSection {
        width: parent.width
        title: "SYSTEM"

        Controls.SettingInfo {
            width: parent.width
            label: "HOSTNAME"
            value: Host.hostname || "-"
        }

        Controls.SettingInfo {
            width: parent.width
            label: "DISTRIBUTION"
            value: Host.distro || "-"
        }

        Controls.SettingInfo {
            width: parent.width
            label: "KERNEL"
            value: Host.kernel || "-"
        }

        Controls.SettingInfo {
            width: parent.width
            label: "UPTIME"
            value: Host.formatUptime(Host.uptime)
        }

        Controls.SettingInfo {
            width: parent.width
            label: "CPU"
            value: Host.cpuCores + " CORES  ·  " + Math.round(Host.cpu * 100) + "%"
        }

        Controls.SettingInfo {
            width: parent.width
            label: "MEMORY"
            value: Host.memUsedGB.toFixed(1) + " / " + Host.memTotalGB.toFixed(1) + " GB"
        }

        Controls.SettingInfo {
            visible: Host.batteryPresent
            width: parent.width
            label: "BATTERY"
            value: Math.round(Host.batteryPct * 100) + "%" + (Host.batteryCharging ? "  CHARGING" : "")
        }
    }

    Controls.SettingSection {
        width: parent.width
        title: "SHELL"

        Controls.SettingInfo {
            width: parent.width
            label: "CONFIGURATION"
            value: Quickshell.shellPath("")
        }

        Controls.SettingInfo {
            width: parent.width
            label: "SETTINGS FILE"
            value: Settings.savePath
        }
    }
}
