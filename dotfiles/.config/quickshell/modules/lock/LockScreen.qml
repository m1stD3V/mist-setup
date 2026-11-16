pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.components
import qs.services

// Secure Wayland session lock. WlSessionLock creates one surface per screen and
// grabs input through ext-session-lock-v1, so the desktop underneath cannot be
// interacted with until PAM accepts the password.
WlSessionLock {
    id: lock

    locked: Lock.locked

    Connections {
        function onLockStateChanged(): void {
            // WlSessionLock can decline a lock (unsupported compositor or an
            // already active lock); keep the service honest about it.
            Lock.syncFromCompositor(lock.locked);
        }

        target: lock
    }

    WlSessionLockSurface {
        id: surface

        color: Theme.bg

        Item {
            id: page

            anchors.fill: parent

            readonly property real frameScale: Math.min(1.4, Math.min(width / 1280, height / 800))
            readonly property int hour12: {
                const h = Time.hours % 12;
                return h === 0 ? 12 : h;
            }
            readonly property string hourText: Settings.clock24h ? Time.format("HH") : (hour12 < 10 ? "0" + hour12 : "" + hour12)

            function mask(length: int): string {
                let out = "";
                for (let i = 0; i < length; i++)
                    out += "*";
                return out;
            }

            function submit(): void {
                if (Lock.authenticating)
                    return;
                const password = passwordInput.text;
                if (password.length === 0)
                    return;
                passwordInput.text = "";
                Lock.authenticate(password);
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
            }

            // faint phosphor scanlines
            Canvas {
                id: scanlines

                anchors.fill: parent
                opacity: 0.5

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.035)";
                    ctx.lineWidth = 1;
                    for (let y = 0; y < height; y += 4) {
                        ctx.beginPath();
                        ctx.moveTo(0, y + 0.5);
                        ctx.lineTo(width, y + 0.5);
                        ctx.stroke();
                    }
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // outer frame
            Rectangle {
                anchors.fill: parent
                anchors.margins: 20
                color: "transparent"
                border.width: 1
                border.color: Theme.border
            }

            RText {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 30
                text: "MIST-86 // SESSION LOCK"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }

            RText {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 30
                text: lock.secure ? "SECURE" : "LOCKING"
                color: lock.secure ? Theme.textDim : (Theme.blink ? Theme.textHigh : Theme.textMuted)
                font.pixelSize: Theme.fontSmall
            }

            RText {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 30
                text: "USER " + Lock.user.toUpperCase()
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }

            RText {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 30
                text: "PAM // EXT-SESSION-LOCK"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }

            Column {
                id: center

                anchors.centerIn: parent
                spacing: 10
                scale: page.frameScale
                transformOrigin: Item.Center

                RText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.hourText + ":" + Time.format("mm")
                    color: Theme.textHigh
                    font.pixelSize: Math.round(Theme.fontHuge * 3)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    RText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Time.dateStr
                        color: Theme.textDim
                        font.pixelSize: Theme.fontMedium
                        font.letterSpacing: 1
                    }

                    RText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "//"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontMedium
                        opacity: Theme.blink ? 1 : 0.2
                    }

                    RText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Time.format("ss")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontMedium
                    }
                }

                Item {
                    width: 1
                    height: 14
                }

                Box {
                    width: 480
                    height: 280
                    title: "AUTHENTICATION"
                    titleBarH: 24
                    titlePixelSize: Theme.fontSmall + 2

                    Column {
                        anchors.fill: parent
                        spacing: 10

                        Item {
                            width: parent.width
                            height: 24

                            RText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "USER"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall + 2
                            }

                            RText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: Lock.user.toUpperCase()
                                color: Theme.text
                                font.pixelSize: Theme.fontSmall + 2
                            }
                        }

                        Item {
                            width: parent.width
                            height: 20

                            RText {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                text: "PASSWORD"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall + 2
                            }

                            RText {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                text: "RETURN TO SUBMIT"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                            }
                        }

                        Rectangle {
                            id: field

                            width: parent.width
                            height: 48
                            color: Theme.surface
                            border.width: 1
                            border.color: passwordInput.activeFocus ? Theme.highlight : Theme.borderHigh
                            // long passwords must never paint past the field
                            clip: true

                            RText {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: ">"
                                color: Theme.textDim
                                font.pixelSize: Theme.fontLarge
                            }

                            RText {
                                anchors.left: parent.left
                                anchors.leftMargin: 34
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: passwordInput.text.length === 0
                                text: "TYPE PASSWORD"
                                color: Theme.textMuted
                                opacity: Theme.blink ? 1 : 0.35
                                font.pixelSize: Theme.fontSmall + 2
                                elide: Text.ElideRight
                            }

                            RText {
                                id: maskText

                                anchors.left: parent.left
                                anchors.leftMargin: 34
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: passwordInput.text.length > 0
                                text: page.mask(passwordInput.text.length)
                                color: Theme.textHigh
                                font.pixelSize: Theme.fontLarge
                                font.letterSpacing: 2
                                // keep the newest characters visible without overflow
                                elide: Text.ElideLeft
                            }

                            // Block caret drawn by us: the native one ignores the
                            // field's bounds, so it is disabled below and this one
                            // is clamped inside the input.
                            Rectangle {
                                id: caret

                                readonly property real maskEnd: Math.min(maskText.implicitWidth, maskText.width)

                                x: Math.round(Math.min(maskText.x + maskEnd + 3, field.width - width - 12))
                                y: Math.round((field.height - height) / 2)
                                width: Math.round(Theme.fontLarge * 0.5)
                                height: Math.round(Theme.fontLarge * 0.9)
                                color: Theme.textHigh
                                // no caret over the placeholder hint; it blinks by itself
                                visible: passwordInput.activeFocus && Theme.blink && passwordInput.text.length > 0 && !Lock.authenticating
                            }

                            TextInput {
                                id: passwordInput

                                anchors.fill: parent
                                leftPadding: 34
                                rightPadding: 12
                                color: "transparent"
                                selectionColor: "transparent"
                                selectedTextColor: "transparent"
                                cursorVisible: false
                                cursorDelegate: Item {}
                                echoMode: TextInput.NoEcho
                                font.family: Theme.family
                                font.pixelSize: Theme.fontLarge
                                focus: true

                                onAccepted: page.submit()

                                Keys.onEscapePressed: event => {
                                    text = "";
                                    event.accepted = true;
                                }
                            }

                            TapHandler {
                                onTapped: passwordInput.forceActiveFocus()
                            }
                        }

                        Item {
                            width: parent.width
                            height: 24

                            RText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                text: {
                                    if (Lock.authenticating)
                                        return Theme.blink ? "AUTHENTICATING..." : "AUTHENTICATING";
                                    if (Lock.error.length > 0)
                                        return Lock.error;
                                    return "READY";
                                }
                                color: Lock.error.length > 0 && !Lock.authenticating ? Theme.highlight : Theme.textDim
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }
                        }

                        Item {
                            width: parent.width
                            height: 1

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.border
                            }
                        }

                        RText {
                            width: parent.width
                            text: "INPUT IS GRABBED BY THE SESSION LOCK"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontExtraSmall + 3
                        }
                    }
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                passwordInput.text = "";
                passwordInput.forceActiveFocus();
            }
        }

        Connections {
            function onLockedChanged(): void {
                if (Lock.locked) {
                    passwordInput.text = "";
                    passwordInput.forceActiveFocus();
                }
            }

            function onErrorChanged(): void {
                if (Lock.error.length > 0)
                    passwordInput.text = "";
            }

            target: Lock
        }
    }
}
