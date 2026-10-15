import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."

// GNOME/COSMIC Notification Center pane embedded inside the center Calendar popover with 10-Role Cast Testbench.
ColumnLayout {
    id: root
    spacing: 8

    // Header: Title + Unread Count | Clear All
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Text { Layout.fillWidth: true; text: "NOTIFICATIONS" + (Status.notifUnread > 0 ? " (" + Status.notifUnread + ")" : ""); color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true }
        Rectangle {
            visible: Status.notifHistory.length > 0; width: clearTxt.implicitWidth + 14; height: 22; radius: Theme.radiusSm
            color: clearM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: clearM.containsMouse ? Theme.red : Theme.border
            Text { id: clearTxt; anchors.centerIn: parent; text: "Clear All"; color: clearM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
            MouseArea { id: clearM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.notifAction) Status.notifAction("clearAll"); } }
        }
    }

    // Empty state when no notifications are queued
    Rectangle {
        visible: Status.notifHistory.length === 0; Layout.fillWidth: true; implicitHeight: 164; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
        ColumnLayout {
            anchors.centerIn: parent; spacing: 6
            Text { Layout.alignment: Qt.AlignHCenter; text: Status.dnd ? "󰂛" : "󰂚"; color: Status.dnd ? Theme.yellow : Theme.muted; font.family: Theme.font; font.pixelSize: 26 }
            Text { Layout.alignment: Qt.AlignHCenter; text: Status.dnd ? "Do Not Disturb Enabled" : "No Unread Notifications"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
            Text { Layout.alignment: Qt.AlignHCenter; text: Status.dnd ? "Popups are silenced; alerts log here" : "10-Role 16-bit Cast alerts appear here"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
        }
    }

    // Scrollable Notification History List
    Flickable {
        visible: Status.notifHistory.length > 0
        Layout.fillWidth: true; implicitHeight: Math.min(260, listCol.implicitHeight)
        contentWidth: width; contentHeight: listCol.implicitHeight; clip: true

        ColumnLayout {
            id: listCol; width: parent.width; spacing: 6

            Repeater {
                model: Status.notifHistory

                Rectangle {
                    id: itemCard
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: cardInner.implicitHeight + 16; radius: Theme.radiusSm
                    color: cardHover.containsMouse ? Theme.bgHover : Theme.bgAlt
                    border.width: 1; border.color: modelData.urgency === "critical" ? Theme.red : Theme.border

                    RowLayout {
                        id: cardInner; anchors.fill: parent; anchors.margins: 8; spacing: 8

                        IconImage {
                            readonly property string src: itemCard.modelData.image || itemCard.modelData.appIcon || ""
                            visible: src !== ""; implicitSize: 28; Layout.alignment: Qt.AlignTop
                            source: src.startsWith("/") ? "file://" + src : (src !== "" ? Quickshell.iconPath(src, true) : "")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2

                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text {
                                    Layout.fillWidth: true; text: itemCard.modelData.summary || "Notification"
                                    color: itemCard.modelData.urgency === "critical" ? Theme.red : Theme.fg
                                    font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; elide: Text.ElideRight
                                }
                                Text {
                                    text: itemCard.modelData.time || ""; color: Theme.muted
                                    font.family: Theme.font; font.pixelSize: Theme.fontSize - 3
                                }
                                Text {
                                    text: "[ACK]"; color: delM.containsMouse ? Theme.red : Theme.cyan
                                    font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                                    MouseArea {
                                        id: delM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (Status.notifAction) Status.notifAction("dismiss", itemCard.modelData.id); }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true; visible: text !== ""; text: itemCard.modelData.body || ""
                                color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2
                                wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; textFormat: Text.StyledText
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text {
                                    Layout.fillWidth: true
                                    text: "[ " + (itemCard.modelData.roleTitle || "SYS ENG") + " // " + String(itemCard.modelData.appName || "SYSTEM").toUpperCase() + " ]"
                                    color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; elide: Text.ElideRight
                                }
                                Repeater {
                                    model: itemCard.modelData.actions || []
                                    Rectangle {
                                        required property var modelData
                                        width: actLbl.implicitWidth + 12; height: 20; radius: Theme.radiusSm
                                        color: actBtnM.containsMouse ? Theme.blue : Theme.bg
                                        border.width: 1; border.color: Theme.blue
                                        Text {
                                            id: actLbl; anchors.centerIn: parent; text: parent.modelData.text
                                            color: actBtnM.containsMouse ? Theme.bg : Theme.cyan
                                            font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                                        }
                                        MouseArea {
                                            id: actBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { if (Status.notifAction) Status.notifAction("invoke", itemCard.modelData.id, parent.modelData.idx); }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: cardHover; anchors.fill: parent; z: -1; hoverEnabled: true
                        onClicked: { if (Status.notifAction) Status.notifAction("dismiss", itemCard.modelData.id); }
                    }
                }
            }
        }
    }

    // 16-Bit Workstation Banner & 10-Role Animated Cast Comms Testbench
    Rectangle {
        Layout.fillWidth: true; implicitHeight: testCol.implicitHeight + 14; radius: Theme.radiusSm
        color: Theme.bgAlt; border.width: 1; border.color: Theme.border
        ColumnLayout {
            id: testCol; anchors { fill: parent; margins: 7 } spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "16-BIT BANNERS & 10-CAST COMMS"; color: Theme.cyan; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                Text {
                    text: "[ALL 10]"; color: allM.containsMouse ? Theme.fg : Theme.primary; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true
                    MouseArea { id: allM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.notifAction) Status.notifAction("cast", "all"); } }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 4
                Repeater {
                    model: [
                        { l: "READY", act: "banner", v: "ready", c: Theme.primary },
                        { l: "WARN",  act: "banner", v: "warning", c: Theme.danger },
                        { l: "UPD",   act: "banner", v: "update", c: Theme.ok },
                        { l: "CHKPT", act: "banner", v: "checkpoint", c: Theme.cyan }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 20; radius: Theme.radiusSm
                        color: tbM.containsMouse ? modelData.c : Theme.bg; border.width: 1; border.color: modelData.c
                        Text { anchors.centerIn: parent; text: "[" + parent.modelData.l + "]"; color: tbM.containsMouse ? Theme.bg : parent.modelData.c; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                        MouseArea { id: tbM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.notifAction) Status.notifAction(parent.modelData.act, parent.modelData.v); } }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 4
                Repeater {
                    model: [
                        { l: "AI",    v: "ai",        c: Theme.primary },
                        { l: "SEC",   v: "security",  c: Theme.danger },
                        { l: "FORGE", v: "builder",   c: Theme.ok },
                        { l: "ENG",   v: "engineer",  c: Theme.accent },
                        { l: "NAV",   v: "navigator", c: Theme.cyan }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 20; radius: Theme.radiusSm
                        color: tcM1.containsMouse ? modelData.c : Theme.bg; border.width: 1; border.color: modelData.c
                        Text { anchors.centerIn: parent; text: "[" + parent.modelData.l + "]"; color: tcM1.containsMouse ? Theme.bg : parent.modelData.c; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                        MouseArea { id: tcM1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.notifAction) Status.notifAction("cast", parent.modelData.v); } }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 4
                Repeater {
                    model: [
                        { l: "MEDIC", v: "medic",     c: Theme.ok },
                        { l: "ARCH",  v: "archivist", c: Theme.warning },
                        { l: "CMD",   v: "commander", c: Theme.magenta },
                        { l: "SYNTH", v: "synth",     c: Theme.cyan },
                        { l: "APP",   v: "app",       c: Theme.magenta }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 20; radius: Theme.radiusSm
                        color: tcM2.containsMouse ? modelData.c : Theme.bg; border.width: 1; border.color: modelData.c
                        Text { anchors.centerIn: parent; text: "[" + parent.modelData.l + "]"; color: tcM2.containsMouse ? Theme.bg : parent.modelData.c; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true }
                        MouseArea { id: tcM2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.notifAction) Status.notifAction("cast", parent.modelData.v); } }
                    }
                }
            }
        }
    }

    // Footer: GNOME/COSMIC Do Not Disturb Switch
    Rectangle {
        Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm
        color: dndM.containsMouse ? Theme.bgHover : Theme.bgAlt
        border.width: 1; border.color: Status.dnd ? Theme.yellow : Theme.border

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
            Text {
                text: Status.dnd ? "󰂛" : "󰂚"; color: Status.dnd ? Theme.yellow : Theme.blue
                font.family: Theme.font; font.pixelSize: Theme.fontSize + 1
            }
            Text {
                Layout.fillWidth: true; text: "Do Not Disturb"; color: Theme.fg
                font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true
            }
            Text {
                text: Status.dnd ? "[*] ON" : "[ ] OFF"; color: Status.dnd ? Theme.yellow : Theme.muted
                font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
            }
        }

        MouseArea {
            id: dndM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { if (Status.notifAction) Status.notifAction("toggleDnd"); }
        }
    }
}
