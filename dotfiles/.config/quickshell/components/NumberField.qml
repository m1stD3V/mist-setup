import QtQuick
import qs.Theme

// Two-digit numeric field with -/+ steppers, used to set H/M/S
// durations. Values can also be typed directly.
Item {
    id: root

    property string label: ""
    property int value: 0
    property int maxValue: 99

    signal submitted(int value)

    implicitWidth: 70
    implicitHeight: 40

    function pad2(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function clamp(v: int): int {
        return Math.max(0, Math.min(root.maxValue, v));
    }

    function sync(): void {
        if (!input.activeFocus)
            input.text = pad2(root.value);
    }

    function submit(): void {
        const n = parseInt(input.text);
        const v = clamp(isNaN(n) ? 0 : n);
        input.text = pad2(v);
        root.submitted(v);
    }

    function step(delta: int): void {
        const n = parseInt(input.text);
        const v = clamp((isNaN(n) ? 0 : n) + delta);
        input.text = pad2(v);
        root.submitted(v);
    }

    onValueChanged: sync()
    Component.onCompleted: sync()

    Row {
        id: stepper

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        TextButton {
            width: 18
            height: 28
            label: "-"
            onClicked: root.step(-1)
        }

        Rectangle {
            width: 30
            height: 28
            color: Theme.surfaceHigh
            border.width: 1
            border.color: input.activeFocus ? Theme.textHigh : Theme.borderHigh

            TextInput {
                id: input

                anchors.fill: parent
                anchors.margins: 2
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.family
                font.pixelSize: Theme.fontSmall
                selectionColor: Theme.inverseBg
                selectedTextColor: Theme.inverseText
                validator: IntValidator {
                    bottom: 0
                    top: root.maxValue
                }
                inputMethodHints: Qt.ImhDigitsOnly

                onEditingFinished: root.submit()
                onActiveFocusChanged: if (activeFocus)
                    selectAll()
                onTextChanged: {
                    if (!activeFocus || text.length === 0)
                        return;
                    const n = parseInt(text);
                    if (!isNaN(n))
                        root.submitted(root.clamp(n));
                }

                Keys.onUpPressed: root.step(1)
                Keys.onDownPressed: root.step(-1)
                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
            }
        }

        TextButton {
            width: 18
            height: 28
            label: "+"
            onClicked: root.step(1)
        }
    }

    RText {
        anchors.top: stepper.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        color: Theme.textMuted
        font.pixelSize: Theme.fontExtraSmall
    }
}
