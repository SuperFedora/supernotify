import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import "panels"

// Minimal Theme-Matched Notification Daemon (Top-Right under Status Icons + Full-Screen Mega Man X WARNING).
Scope {
    id: root
    property var activeToasts: []
    property bool centerOpen: false
    property bool screensaverActive: false
    property int synthSeq: Math.floor(Date.now() / 100)
    property bool _warnedBat: false; property bool _warnedTemp: false
    readonly property string statePath: Quickshell.env("HOME") + "/.config/superfedora/notifications.json"
    readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 100
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    FileView {
        id: stateFile; path: root.statePath
        onLoaded: {
            const raw = stateFile.text().trim(); if (!raw) return;
            try { const d = JSON.parse(raw); if (typeof d.dnd === "boolean") Status.dnd = d.dnd; if (Array.isArray(d.history)) { Status.notifHistory = d.history.slice(0, 50); Status.notifUnread = Status.notifHistory.length; } } catch (e) {}
        }
    }
    WorkstationBanner { id: bannerOverlay; screensaverActive: root.screensaverActive }

    Connections {
        target: Hyprland
        function onRawEvent(ev): void {
            const n = String(ev.name || ""), d = String(ev.data || "");
            if (n === "openlayer" && d.includes("idlescreen")) { root.screensaverActive = true; root.activeToasts = []; }
            else if (n === "closelayer" && d.includes("idlescreen")) root.screensaverActive = false;
        }
    }

    function loadState(): void { stateFile.reload(); }
    function saveState(): void {
        const payload = JSON.stringify({ dnd: Status.dnd, history: Status.notifHistory });
        Quickshell.execDetached(["python3", "-c", "import os,sys; p=os.path.expanduser('~/.config/superfedora/notifications.json'); os.makedirs(os.path.dirname(p), exist_ok=True); t=p+'.tmp.'+str(os.getpid()); open(t,'w').write(sys.argv[1]); os.replace(t,p)", payload]);
    }
    function findLive(nid) { for (const n of server.trackedNotifications.values) if (n.id === nid) return n; return null; }
    function hideToast(nid): void { root.activeToasts = root.activeToasts.filter(t => t.id !== nid); }
    function dismissById(nid): void {
        const found = Status.notifHistory.find(item => item.id === nid);
        root.hideToast(nid); Status.notifHistory = Status.notifHistory.filter(item => item.id !== nid);
        Status.notifUnread = Status.notifHistory.length;
        const live = root.findLive(found && found.liveId !== undefined ? found.liveId : nid); if (live) live.dismiss();
        root.saveState();
    }
    function clearAll(): void {
        root.activeToasts = []; Status.notifHistory = []; Status.notifUnread = 0;
        for (const n of server.trackedNotifications.values.slice()) n.dismiss(); root.saveState();
    }
    function setDnd(val: bool): void { Status.dnd = val; if (val) root.activeToasts = root.activeToasts.filter(t => t.urgency === "critical"); root.saveState(); }
    function invokeAction(nid, actIdx): void {
        const found = Status.notifHistory.find(item => item.id === nid);
        const live = root.findLive(found && found.liveId !== undefined ? found.liveId : nid);
        if (live && live.actions && live.actions[actIdx]) live.actions[actIdx].invoke();
        root.hideToast(nid);
    }

    function pushItem(raw): void {
        root.synthSeq += 1;
        const item = {
            id: root.synthSeq, liveId: raw.id, appName: raw.appName || "", appIcon: raw.appIcon || "", image: raw.image || "",
            summary: raw.summary || "Notification", body: String(raw.body || "").replace(/<[^>]*>/g, ""),
            urgency: raw.urgency || "normal",
            time: Qt.formatDateTime(new Date(), "HH:mm"), timeout: raw.timeout || 5000, actions: raw.actions || []
        };
        Status.notifHistory = [item].concat(Status.notifHistory).slice(0, 50);
        Status.notifUnread = Status.notifHistory.length; root.saveState();
        if ((!Status.dnd || item.urgency === "critical") && !Status.sessionLocked && !root.centerOpen && !root.screensaverActive) {
            root.activeToasts = [item].concat(root.activeToasts).slice(0, 5);
        }
    }

    function triggerBanner(kind): void {
        if (root.screensaverActive || Status.sessionLocked) return;
        const k = String(kind || "warning").toLowerCase();
        if (k === "warning" || k === "warn" || k === "critical" || k === "alert") { bannerOverlay.trigger("warning"); Status.playSfx("alert"); return; }
        const map = { ready: ["READY", "System nominal & ready."], update: ["SYSTEM UPDATE", "Update status notification."], checkpoint: ["CHECKPOINT SAVED", "BTRFS snapshot state recorded."] }, m = map[k] || [k.toUpperCase() || "NOTICE", "Banner notification"];
        root.synthSeq += 1; root.pushItem({ id: root.synthSeq, appName: "SuperNotify", summary: m[0], body: m[1], urgency: "normal", timeout: 5000 }); Status.playSfx("confirm");
    }

    function triggerCastTest(target): void {
        const raw = String(target || ""), parts = raw.split("|"), r = (parts[0] || "").toLowerCase();
        if (r === "security" || r === "warning" || r === "warn") { root.triggerBanner("warning"); return; }
        root.synthSeq += 1;
        root.pushItem({
            id: root.synthSeq, appName: "SuperNotify",
            summary: parts[1] || (r ? r.toUpperCase() : "Notification"),
            body: parts[2] || "Workstation telemetry nominal.",
            urgency: "normal", timeout: 5000
        });
        Status.playSfx("confirm");
    }

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            if (root.batPresent && !root.batCharging && root.batPct > 0 && root.batPct <= 10) {
                if (!root._warnedBat) {
                    root._warnedBat = true;
                    root.synthSeq += 1;
                    root.pushItem({ id: root.synthSeq, appName: "Power", summary: "Battery Critical (" + root.batPct + "%)", body: "Plug in charger immediately.", urgency: "critical", timeout: 10000 });
                    root.triggerBanner("warning");
                }
            } else if (root.batCharging || root.batPct > 12) root._warnedBat = false;
            if (Status.tempC >= 90) {
                if (!root._warnedTemp) {
                    root._warnedTemp = true;
                    root.synthSeq += 1;
                    root.pushItem({ id: root.synthSeq, appName: "Thermal", summary: "Thermal Emergency (" + Status.tempC + " C)", body: "CPU temperature exceeded 90 C.", urgency: "critical", timeout: 10000 });
                    root.triggerBanner("warning");
                }
            } else if (Status.tempC < 85) root._warnedTemp = false;
        }
    }

    Component.onCompleted: {
        root.loadState();
        Status.notifAction = function(act, arg1, arg2) {
            if (act === "toggleDnd") root.setDnd(!Status.dnd); else if (act === "setDnd") root.setDnd(Boolean(arg1));
            else if (act === "clearAll") root.clearAll(); else if (act === "dismiss") root.dismissById(arg1);
            else if (act === "hideToast") root.hideToast(arg1); else if (act === "hideAllToasts") root.activeToasts = [];
            else if (act === "setCenterOpen") { root.centerOpen = Boolean(arg1); Status.notifDrawerOpen = Boolean(arg1); if (root.centerOpen) root.activeToasts = []; }
            else if (act === "invoke") root.invokeAction(arg1, arg2);
            else if (act === "reload") root.loadState(); else if (act === "banner") root.triggerBanner(arg1);
            else if (act === "cast") root.triggerCastTest(arg1);
        };
    }

    IpcHandler {
        target: "notifications"
        function dismiss(): void { if (root.activeToasts.length > 0) root.hideToast(root.activeToasts[0].id); else if (Status.notifHistory.length > 0) root.dismissById(Status.notifHistory[0].id); }
        function dismissAll(): void { root.clearAll(); }
        function toggleDnd(): void { root.setDnd(!Status.dnd); }
        function setDnd(mode: string): void { root.setDnd(mode === "on" || mode === "1" || mode === "true"); }
        function toggle(): void { Status.centerToggleSeq += 1; }
        function reload(): void { root.loadState(); }
        function banner(kind: string): void { root.triggerBanner(kind); }
        function bannerSub(kind: string, _sub: string): void { root.triggerBanner(kind); }
        function cast(role: string): void { root.triggerCastTest(role); }
    }

    NotificationServer {
        id: server; keepOnReload: true; bodySupported: true; bodyMarkupSupported: true; actionsSupported: true; imageSupported: true; persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            const urg = n.urgency === NotificationUrgency.Critical ? "critical" : (n.urgency === NotificationUrgency.Low ? "low" : "normal");
            const acts = []; if (n.actions) for (let i = 0; i < n.actions.length; i++) acts.push({ idx: i, text: n.actions[i].text });
            root.pushItem({ id: n.id, appName: n.appName || "", appIcon: n.appIcon || "", image: n.image || "", summary: n.summary || "Notification", body: n.body || "", urgency: urg, timeout: n.expireTimeout > 0 ? n.expireTimeout : 5000, actions: acts });
        }
    }

    // Top-Right Notification Popup Stack: top-right, directly under the bell, stacked downward
    PanelWindow {
        id: toastWin
        visible: root.activeToasts.length > 0 && !Status.sessionLocked && !root.centerOpen && !root.screensaverActive
        screen: Quickshell.screens[0]; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "superfedora-notifications"; WlrLayershell.layer: WlrLayer.Top; WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; right: true }
        margins { top: Theme.barHeight + 6; right: 8 }
        implicitWidth: 340; implicitHeight: toastCol.implicitHeight

        ColumnLayout {
            id: toastCol; width: parent.width; spacing: 6
            Repeater {
                model: root.activeToasts
                Rectangle {
                    id: card; required property var modelData
                    readonly property string iconSrc: card.modelData.image || card.modelData.appIcon || ""
                    Layout.fillWidth: true; implicitHeight: contentRow.implicitHeight + 18
                    color: Theme.bg; radius: Theme.radius; border.width: 1
                    border.color: card.modelData.urgency === "critical" ? Theme.danger : Theme.border

                    Timer { running: card.modelData.urgency !== "critical"; interval: card.modelData.timeout || 5000; onTriggered: root.hideToast(card.modelData.id) }

                    RowLayout {
                        id: contentRow; anchors { fill: parent; margins: 9 } spacing: 8
                        IconImage {
                            visible: card.iconSrc !== ""; implicitSize: 24; Layout.alignment: Qt.AlignTop
                            source: card.iconSrc.startsWith("/") ? "file://" + card.iconSrc : (card.iconSrc !== "" ? Quickshell.iconPath(card.iconSrc, true) : "")
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text {
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                    text: card.modelData.summary
                                    color: card.modelData.urgency === "critical" ? Theme.danger : Theme.fg
                                    font.family: Theme.font; font.pixelSize: Theme.fontSize - 1; font.bold: true
                                }
                                Text {
                                    text: card.modelData.time; color: Theme.muted
                                    font.family: Theme.font; font.pixelSize: Theme.fontSize - 3
                                }
                                Rectangle {
                                    width: 18; height: 18; radius: Theme.radiusSm
                                    color: closeToastM.containsMouse ? Theme.danger : "transparent"
                                    Text { anchors.centerIn: parent; text: "×"; color: closeToastM.containsMouse ? Theme.bg : Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                                    MouseArea { id: closeToastM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissById(card.modelData.id) }
                                }
                            }
                            Text {
                                Layout.fillWidth: true; visible: card.modelData.body !== ""
                                text: card.modelData.body; color: Theme.fgDim
                                font.family: Theme.font; font.pixelSize: Theme.fontSize - 2
                                wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                            }
                            Row {
                                visible: (card.modelData.actions || []).length > 0; spacing: 6
                                Repeater {
                                    model: card.modelData.actions || []
                                    Rectangle {
                                        required property var modelData
                                        width: actText.implicitWidth + 12; height: 20; radius: Theme.radiusSm
                                        color: actMouse.containsMouse ? Theme.blue : Theme.bgAlt
                                        border.width: 1; border.color: Theme.border
                                        Text {
                                            id: actText; anchors.centerIn: parent; text: parent.modelData.text
                                            color: actMouse.containsMouse ? Theme.bg : Theme.fg
                                            font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true
                                        }
                                        MouseArea {
                                            id: actMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.invokeAction(card.modelData.id, parent.modelData.idx)
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
}
