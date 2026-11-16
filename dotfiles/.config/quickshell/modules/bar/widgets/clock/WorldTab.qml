pragma ComponentBehavior: Bound

import QtQuick
import qs.Theme
import qs.components
import qs.services

// World clocks tab. Zone names are validated before they reach the settings
// file so a typo cannot leave the list in a state that renders as "--:--".
Column {
    id: root

    width: parent ? parent.width : 0
    spacing: 6

    readonly property int rowH: 28
    readonly property int maxRows: 4
    readonly property int listHeight: Math.min(Math.max(1, Settings.worldZones.length), root.maxRows) * root.rowH

    function focusField(): void {
        zoneField.forceActiveFocus();
    }

    function addZone(): void {
        const zone = zoneField.text.trim();
        if (!/^[A-Za-z0-9_+\-\/]{2,48}$/.test(zone))
            return;
        if (Settings.worldZones.indexOf(zone) !== -1 || Settings.worldZones.length >= 8) {
            zoneField.text = "";
            return;
        }
        Settings.worldZones = Settings.worldZones.concat([zone]);
        zoneField.text = "";
    }

    Row {
        width: parent.width

        RText {
            width: parent.width - localTime.width
            text: "WORLD CLOCKS"
            color: Theme.textDim
            font.pixelSize: Theme.fontSmall
        }

        RText {
            id: localTime

            text: WorldClocks.localTime.length > 0 ? "LOCAL " + WorldClocks.localTime : ""
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }
    }

    Item {
        width: parent.width
        height: root.listHeight

        RText {
            visible: Settings.worldZones.length === 0
            anchors.centerIn: parent
            text: "NO ZONES"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }

        ListView {
            anchors.fill: parent
            visible: Settings.worldZones.length > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Settings.worldZones

            delegate: Item {
                id: zoneRow

                required property string modelData

                width: ListView.view.width
                height: root.rowH

                Rectangle {
                    anchors.fill: parent
                    color: zoneHover.hovered ? Theme.surfaceHigh : "transparent"
                }

                HoverHandler {
                    id: zoneHover
                }

                RText {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.right: zoneTime.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: WorldClocks.key(zoneRow.modelData)
                    color: Theme.text
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                RText {
                    id: zoneTime

                    anchors.right: zoneRemove.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const offset = WorldClocks.offsetFor(zoneRow.modelData);
                        const suffix = offset > 0 ? " +1D" : offset < 0 ? " -1D" : "";
                        return WorldClocks.timeFor(zoneRow.modelData) + suffix;
                    }
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSmall
                }

                TextButton {
                    id: zoneRemove

                    width: 22
                    height: 20
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    label: "X"
                    danger: true
                    onClicked: Settings.worldZones = Settings.worldZones.filter(z => z !== zoneRow.modelData)
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 30
        color: Theme.surfaceHigh
        border.width: 1
        border.color: zoneField.activeFocus ? Theme.highlight : Theme.borderHigh

        RText {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: zoneField.text.length === 0
            text: "AREA/CITY"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }

        TextInput {
            id: zoneField

            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.textHigh
            font.family: Theme.family
            font.pixelSize: Theme.fontSmall
            selectionColor: Theme.inverseBg
            selectedTextColor: Theme.inverseText
            clip: true

            onAccepted: root.addZone()
        }
    }

    RText {
        width: parent.width
        text: "TIMEZONE NAME, E.G. EUROPE/PARIS"
        color: Theme.textMuted
        font.pixelSize: Theme.fontExtraSmall
        wrapMode: Text.Wrap
    }
}
