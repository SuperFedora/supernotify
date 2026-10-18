import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."

// Notification list. Standalone (chrome: true) it is the old centred popover: DND switch, More
// Notification Settings, header + Clear. panels/NotifDrawer.qml reuses it with chrome: false and
// grouped: true so the drawer owns its own header and renders the history grouped by app, and with
// actions: true so the drawer inherits the exact DND + More card style from below.
ColumnLayout {
    id: root
    signal openSettings()
    spacing: 8

    property var source: null
    property bool chrome: true
    property bool grouped: false
    // The DND + More settings cards render on their own when the drawer owns the chrome
    // (actions: true), so NotifDrawer never re-declares — and can never drift from — their style.
    property bool actions: false
    readonly property var items: root.source !== null ? root.source : Status.notifHistory
    readonly property var blank: ({ summary: "", body: "", time: "", urgency: "normal", actions: [], image: "", appIcon: "" })
    readonly property var rows: {
        const src = root.items || [], out = [];
        if (!root.grouped) { for (const n of src) out.push({ k: false, h: "", c: 0, n: n }); return out; }
        const order = [], map = {};
        for (const it of src) { const key = String(it.appName || "System").trim() || "System"; if (!map[key]) { map[key] = []; order.push(key); } map[key].push(it); }
        for (const key of order) { out.push({ k: true, h: key, c: map[key].length, n: root.blank }); for (const it of map[key]) out.push({ k: false, h: "", c: 0, n: it }); }
        return out;
    }

    // 1. First: Do Not Disturb Switch
    Rectangle {
        visible: root.chrome || root.actions
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

    // 2. Second: Inline Notification Settings & Previews (Banners, Casts, Test Toast)
    property bool showTools: false
    Rectangle {
        visible: root.chrome || root.actions; Layout.fillWidth: true; implicitHeight: 32; radius: Theme.radiusSm
        color: moreM.containsMouse ? Theme.bgHover : Theme.bgAlt; border.width: 1; border.color: root.showTools || moreM.containsMouse ? Theme.blue : Theme.border
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
            Text { text: "󰒓"; color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize }
            Text { Layout.fillWidth: true; text: "Notification alerts & previews"; color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
            Text { text: root.showTools ? "▾" : "›"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize + 2 }
        }
        MouseArea { id: moreM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showTools = !root.showTools }
    }
    Rectangle {
        visible: (root.chrome || root.actions) && root.showTools; Layout.fillWidth: true; implicitHeight: tFlow.implicitHeight + 16; radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
        Flow {
            id: tFlow; anchors.fill: parent; anchors.margins: 8; spacing: 6
            Repeater {
                model: [
                    { l: "Test Toast", c: "notify-send -a 'SuperNotify' 'Notification Test' 'Desktop toast alerts are active.'" },
                    { l: "Ready Banner", b: "ready" }, { l: "WARNING", b: "warning" }, { l: "Update Banner", b: "update" }, { l: "Checkpoint", b: "checkpoint" },
                    { l: "Cast: Security", k: "maya", m: "Security audit clear", r: "SECURITY LEAD" },
                    { l: "Cast: Architect", k: "ritsuko", m: "Kernel & services nominal", r: "CHIEF ARCHITECT" },
                    { l: "Cast: Ops", k: "misato", m: "Workstation operations green", r: "OPS DIRECTOR" }
                ]
                Rectangle {
                    required property var modelData
                    height: 22; width: tl.implicitWidth + 14; radius: Theme.radiusSm; color: tm.containsMouse ? Theme.blue : Theme.bg; border.width: 1; border.color: Theme.border
                    Text { id: tl; anchors.centerIn: parent; text: parent.modelData.l; color: tm.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { const d = parent.modelData; if (d.c) Quickshell.execDetached(["sh", "-c", d.c]); else if (d.b) Status.triggerNotif("banner", d.b); else if (d.k) Status.triggerNotif("cast", d.k + "|" + d.r + "|" + d.m); } }
                }
            }
        }
    }

    // 3. Header: Title + Unread Count | Clear
    RowLayout {
        visible: root.chrome
        Layout.fillWidth: true; spacing: 8
        Text {
            Layout.fillWidth: true
            text: "NOTIFICATIONS" + (Status.notifUnread > 0 ? " (" + Status.notifUnread + ")" : "")
            color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2; font.bold: true
        }
        Rectangle {
            visible: Status.notifHistory.length > 0; width: clearTxt.implicitWidth + 16; height: 22; radius: Theme.radiusSm
            color: clearM.containsMouse ? Theme.red : Theme.bgAlt; border.width: 1; border.color: clearM.containsMouse ? Theme.red : Theme.border
            Text { id: clearTxt; anchors.centerIn: parent; text: "Clear"; color: clearM.containsMouse ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true }
            MouseArea { id: clearM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (Status.notifAction) Status.notifAction("clearAll"); } }
        }
    }

    // Empty state when no notifications are queued
    Rectangle {
        visible: root.items.length === 0
        Layout.fillWidth: true; Layout.fillHeight: true; implicitHeight: 164
        radius: Theme.radiusSm; color: Theme.bgAlt; border.width: 1; border.color: Theme.border
        ColumnLayout {
            anchors.centerIn: parent; spacing: 6
            Text { Layout.alignment: Qt.AlignHCenter; text: Status.dnd ? "󰂛" : "󰂚"; color: Status.dnd ? Theme.yellow : Theme.muted; font.family: Theme.font; font.pixelSize: 26 }
            Text { Layout.alignment: Qt.AlignHCenter; text: Status.dnd ? "Do Not Disturb Enabled" : "No Unread Notifications"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true }
            Text { Layout.alignment: Qt.AlignHCenter; text: Status.dnd ? "Popups are silenced" : "Notifications appear here"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3 }
        }
    }

    // 4. Scrollable Notification History List all the way to the bottom of the window
    Flickable {
        id: notifFlick
        visible: root.items.length > 0
        Layout.fillWidth: true; Layout.fillHeight: true
        contentWidth: width; contentHeight: listCol.implicitHeight; clip: true
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: event => {
                const maxScroll = Math.max(0, notifFlick.contentHeight - notifFlick.height);
                const step = event.angleDelta.y > 0 ? -48 : 48;
                notifFlick.contentY = Math.max(0, Math.min(maxScroll, notifFlick.contentY + step));
            }
        }

        ColumnLayout {
            id: listCol; width: parent.width - (notifFlick.contentHeight > notifFlick.height ? 8 : 0); spacing: 6

            Repeater {
                model: root.rows

                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 3

                    // grouped mode only: app name header with its item count
                    Text {
                        visible: modelData.k
                        Layout.fillWidth: true; Layout.topMargin: 5
                        text: modelData.h.toUpperCase() + "  ·  " + modelData.c
                        color: Theme.blue; font.family: Theme.font; font.pixelSize: Theme.fontSize - 4; font.bold: true
                    }
                    Rectangle {
                    id: itemCard
                    visible: !modelData.k
                    Layout.fillWidth: true; implicitHeight: cardInner.implicitHeight + 14; radius: Theme.radiusSm
                    color: Theme.bgAlt
                    border.width: 1; border.color: modelData.n.urgency === "critical" ? Theme.red : Theme.border

                    RowLayout {
                        id: cardInner; anchors.fill: parent; anchors.margins: 7; spacing: 8

                        IconImage {
                            readonly property string src: modelData.n.image || modelData.n.appIcon || ""
                            visible: src !== ""; implicitSize: 24; Layout.alignment: Qt.AlignTop
                            source: src.startsWith("/") ? "file://" + src : (src !== "" ? Quickshell.iconPath(src, true) : "")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2

                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text {
                                    Layout.fillWidth: true; text: modelData.n.summary || "Notification"
                                    color: modelData.n.urgency === "critical" ? Theme.red : Theme.fg
                                    font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true; elide: Text.ElideRight
                                }
                                Text {
                                    text: modelData.n.time || ""; color: Theme.muted
                                    font.family: Theme.font; font.pixelSize: Theme.fontSize - 3
                                }
                                Rectangle {
                                    width: 20; height: 20; radius: Theme.radiusSm
                                    color: dismissBtnM.containsMouse ? Theme.red : "transparent"
                                    border.width: dismissBtnM.containsMouse ? 1 : 0; border.color: Theme.red
                                    Text {
                                        anchors.centerIn: parent; text: "×"
                                        color: dismissBtnM.containsMouse ? Theme.bg : Theme.fgDim
                                        font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
                                    }
                                    MouseArea {
                                        id: dismissBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (Status.notifAction) Status.notifAction("dismiss", modelData.n.id); }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true; visible: text !== ""; text: modelData.n.body || ""
                                color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2
                                wrapMode: Text.Wrap; elide: Text.ElideRight; textFormat: Text.StyledText
                            }

                            Row {
                                visible: (modelData.n.actions || []).length > 0; spacing: 6
                                Repeater {
                                    model: modelData.n.actions || []
                                    Rectangle {
                                        required property var modelData
                                        width: actLbl.implicitWidth + 12; height: 20; radius: Theme.radiusSm
                                        color: actBtnM.containsMouse ? Theme.blue : Theme.bg
                                        border.width: 1; border.color: Theme.border
                                        Text {
                                            id: actLbl; anchors.centerIn: parent; text: parent.modelData.text
                                            color: actBtnM.containsMouse ? Theme.bg : Theme.fg
                                            font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                                        }
                                        MouseArea {
                                            id: actBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { if (Status.notifAction) Status.notifAction("invoke", modelData.n.id, parent.modelData.idx); }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                }
            }
        }

        Rectangle {
            visible: notifFlick.contentHeight > notifFlick.height
            anchors.right: parent.right
            y: (notifFlick.contentY / Math.max(1, notifFlick.contentHeight - notifFlick.height)) * (notifFlick.height - height)
            width: 4
            height: Math.max(24, (notifFlick.height / Math.max(1, notifFlick.contentHeight)) * notifFlick.height)
            radius: 2
            color: Theme.muted
        }
    }
}
