import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import "panels"

// 16-Bit Workstation Multi-Zone Comms & Banner Daemon (SNES / Mega Man X style comms boxes + Theme-bound pixel cast).
Scope {
    id: root
    property var activeToasts: []
    property int synthSeq: 90000
    property bool _warnedBat: false; property bool _warnedTemp: false
    readonly property string statePath: Quickshell.env("HOME") + "/.config/superfedora/notifications.json"
    readonly property string castDir: Quickshell.env("HOME") + "/.config/superfedora/cast/"
    readonly property var batDev: UPower.displayDevice; readonly property bool batPresent: batDev !== null && batDev.isLaptopBattery
    readonly property int batPct: batPresent ? Math.round(batDev.percentage <= 1 ? batDev.percentage * 100 : batDev.percentage) : 100
    readonly property bool batCharging: batPresent && (batDev.state === UPowerDeviceState.Charging || batDev.state === UPowerDeviceState.FullyCharged)

    FileView { id: stateFile; path: root.statePath }
    WorkstationBanner { id: bannerOverlay }

    function loadState(): void {
        stateFile.reload(); const raw = stateFile.text().trim(); if (!raw) return;
        try { const d = JSON.parse(raw); if (typeof d.dnd === "boolean") Status.dnd = d.dnd; if (Array.isArray(d.history)) { Status.notifHistory = d.history.slice(0, 50); Status.notifUnread = Status.notifHistory.length; } } catch (e) {}
    }
    function saveState(): void {
        const payload = JSON.stringify({ dnd: Status.dnd, history: Status.notifHistory });
        Quickshell.execDetached(["python3", "-c", "import os,sys; p=os.path.expanduser('~/.config/superfedora/notifications.json'); os.makedirs(os.path.dirname(p), exist_ok=True); open(p,'w').write(sys.argv[1])", payload]);
    }
    function findLive(nid) { for (const n of server.trackedNotifications.values) if (n.id === nid) return n; return null; }
    function hideToast(nid): void { root.activeToasts = root.activeToasts.filter(t => t.id !== nid); }
    function dismissById(nid): void {
        root.hideToast(nid); Status.notifHistory = Status.notifHistory.filter(item => item.id !== nid);
        Status.notifUnread = Status.notifHistory.length; const live = root.findLive(nid); if (live) live.dismiss(); root.saveState();
    }
    function clearAll(): void {
        root.activeToasts = []; Status.notifHistory = []; Status.notifUnread = 0;
        for (const n of server.trackedNotifications.values.slice()) n.dismiss(); root.saveState();
    }
    function setDnd(val: bool): void { Status.dnd = val; if (val) root.activeToasts = root.activeToasts.filter(t => t.urgency === "critical"); root.saveState(); }
    function invokeAction(nid, actIdx): void { const live = root.findLive(nid); if (live && live.actions && live.actions[actIdx]) live.actions[actIdx].invoke(); root.hideToast(nid); }

    function classifyCast(appName, summary, body, urg) {
        const app = String(appName || "").toLowerCase(), head = (app + " " + String(summary || "")).toLowerCase();
        if (urg === "critical" || /(polkit|firewall|security|critical|alert|auth|pam)/.test(head)) return { role: "security", roleTitle: "SEC ALERT", zone: "top-center" };
        if (/(openclaw|\bagy\b|antigravity|claude|ollama|\bpi\b|chatgpt|codex|grok|vibe|mcode|quake-ai|ai agent)/.test(head)) return { role: "ai", roleTitle: "AI AGENT", zone: "bottom-center" };
        if (/(tailscale|wireguard|\bvpn\b|navigator|mesh|route|dns)/.test(head)) return { role: "navigator", roleTitle: "NAVIGATOR", zone: "top-right" };
        if (/(healer|medic|thermal|battery|scrub|smart|health)/.test(head)) return { role: "medic", roleTitle: "SYS MEDIC", zone: "top-center" };
        if (/(snapper|snapshot|checkpoint|rollback|vault|archivist|btrfs)/.test(head)) return { role: "archivist", roleTitle: "ARCHIVIST", zone: "top-right" };
        if (/(commander|fleet|tactical|mission|mode|profile)/.test(head)) return { role: "commander", roleTitle: "COMMANDER", zone: "top-center" };
        if (/(pipewire|synth|audio|sfx|sound|volume|speaker|mic)/.test(head)) return { role: "synth", roleTitle: "AUDIO SYNTH", zone: "bottom-center" };
        if (/(firefox|discord|slack|spotify|chrome|chromium|brave|thunderbird|telegram|signal|steam|nautilus)/.test(app)) return { role: "app", roleTitle: "APP COMMS", zone: "top-right" };
        if (/(forge|\bdnf\b|cargo|\bgcc\b|\bmake\b|cmake|rustup|flatpak|update|compiler|build)/.test(head)) return { role: "builder", roleTitle: "BUILDER", zone: "top-right" };
        return { role: "engineer", roleTitle: "SYS ENG", zone: "top-right" };
    }

    function pushItem(raw): void {
        const c = raw.role ? { role: raw.role, roleTitle: raw.roleTitle || raw.role.toUpperCase(), zone: raw.zone || "top-right" } : root.classifyCast(raw.appName, raw.summary, raw.body, raw.urgency);
        const item = {
            id: raw.id, appName: raw.appName || "System", appIcon: raw.appIcon || "", image: raw.image || "",
            summary: raw.summary || "Workstation Comms", body: String(raw.body || "").replace(/<[^>]*>/g, ""),
            urgency: raw.urgency || "normal", role: c.role, roleTitle: c.roleTitle, zone: c.zone,
            time: Qt.formatDateTime(new Date(), "HH:mm"), timeout: raw.timeout || 5500, actions: raw.actions || []
        };
        Status.notifHistory = [item].concat(Status.notifHistory.filter(x => x.id !== item.id)).slice(0, 50);
        Status.notifUnread = Status.notifHistory.length; root.saveState();
        if (item.urgency === "critical") root.triggerBanner("warning", item.summary);
        if ((!Status.dnd || item.urgency === "critical") && !Status.sessionLocked) root.activeToasts = [item].concat(root.activeToasts.filter(t => t.id !== item.id)).slice(0, 6);
    }

    function triggerBanner(kind, sub): void {
        const k = String(kind || "ready").toLowerCase(); bannerOverlay.trigger(k, sub || "");
        Status.playSfx(k === "warning" || k === "warn" ? "alert" : (k === "ready" ? "startup" : "confirm"));
    }

    function triggerCastTest(target): void {
        const r = String(target || "all").toLowerCase();
        const samples = {
            ai:        { role: "ai",        roleTitle: "AI AGENT",    zone: "bottom-center", appName: "AGY // OPENCLAW",  summary: "Neural Harness Link Active",   body: "Context indexed. Ready for code synthesis and workstation automation.", urgency: "normal", timeout: 6000 },
            security:  { role: "security",  roleTitle: "SEC ALERT",   zone: "top-center",    appName: "POLKIT // GUARD",  summary: "Privilege Escalation Check",   body: "Critical telemetry & policy guard monitoring active on root subvolume.", urgency: "critical", timeout: 6500 },
            builder:   { role: "builder",   roleTitle: "BUILDER",     zone: "top-right",     appName: "SF FORGE",         summary: "Native Target Compiled",       body: "Built with -O3 -march=native -flto=auto and linked via mold.", urgency: "normal", timeout: 6000 },
            engineer:  { role: "engineer",  roleTitle: "SYS ENG",     zone: "top-right",     appName: "SUPERFEDORA",      summary: "Workstation Stack Verified",   body: "All 10 modules and systemd session targets synchronized.", urgency: "normal", timeout: 6000 },
            app:       { role: "app",       roleTitle: "APP COMMS",   zone: "top-right",     appName: "FIREFOX",          summary: "External App Transmission",    body: "Incoming desktop application relay framed in 16-bit scanline bezel.", urgency: "normal", timeout: 6000 },
            navigator: { role: "navigator", roleTitle: "NAVIGATOR",   zone: "top-right",     appName: "NET // TAILSCALE", summary: "Mesh Route Synchronized",      body: "Tailscale WireGuard tunnel & low-latency DNS routing locked.", urgency: "normal", timeout: 6000 },
            medic:     { role: "medic",     roleTitle: "SYS MEDIC",   zone: "top-center",    appName: "BTRFS // HEALER",  summary: "Subvolume Health Scrub",       body: "Thermal, SMART, and Btrfs scrub diagnostics verified with zero errors.", urgency: "normal", timeout: 6000 },
            archivist: { role: "archivist", roleTitle: "ARCHIVIST",   zone: "top-right",     appName: "SNAPPER // VAULT", summary: "Immutable Snapshot Sealed",    body: "Timeline checkpoint indexed into cold storage and GRUB boot menu.", urgency: "normal", timeout: 6000 },
            commander: { role: "commander", roleTitle: "COMMANDER",   zone: "top-center",    appName: "FLEET // OPS",     summary: "Tactical Override Active",     body: "Workstation mission parameters locked across all active workspaces.", urgency: "normal", timeout: 6000 },
            synth:     { role: "synth",     roleTitle: "AUDIO SYNTH", zone: "bottom-center", appName: "PIPEWIRE // DSP",  summary: "16-Bit PCM Synth Locked",      body: "Low-latency PipeWire quantum and 16-bit WAV audio cues online.", urgency: "normal", timeout: 6000 }
        };
        if (r === "all") { for (const k of Object.keys(samples)) { root.synthSeq += 1; root.pushItem(Object.assign({ id: root.synthSeq }, samples[k])); } }
        else if (samples[r]) { root.synthSeq += 1; root.pushItem(Object.assign({ id: root.synthSeq }, samples[r])); Status.playSfx(r === "security" ? "alert" : "confirm"); }
    }

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            if (root.batPresent && !root.batCharging && root.batPct > 0 && root.batPct <= 10) { if (!root._warnedBat) { root._warnedBat = true; root.triggerBanner("warning", "BATTERY CRITICAL: " + root.batPct + "% REMAINING"); } }
            else if (root.batCharging || root.batPct > 12) root._warnedBat = false;
            if (Status.tempC >= 90) { if (!root._warnedTemp) { root._warnedTemp = true; root.triggerBanner("warning", "THERMAL SPIKE DETECTED: " + Status.tempC + " C"); } }
            else if (Status.tempC < 85) root._warnedTemp = false;
        }
    }

    Component.onCompleted: {
        root.loadState();
        Status.notifAction = function(act, arg1, arg2) {
            if (act === "toggleDnd") root.setDnd(!Status.dnd); else if (act === "setDnd") root.setDnd(Boolean(arg1));
            else if (act === "clearAll") root.clearAll(); else if (act === "dismiss") root.dismissById(arg1);
            else if (act === "hideToast") root.hideToast(arg1); else if (act === "invoke") root.invokeAction(arg1, arg2);
            else if (act === "reload") root.loadState(); else if (act === "banner") root.triggerBanner(arg1, arg2);
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
        function banner(kind: string): void { root.triggerBanner(kind, ""); }
        function cast(role: string): void { root.triggerCastTest(role); }
    }

    NotificationServer {
        id: server; keepOnReload: true; bodySupported: true; bodyMarkupSupported: true; actionsSupported: true; imageSupported: true; persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            const urg = n.urgency === NotificationUrgency.Critical ? "critical" : (n.urgency === NotificationUrgency.Low ? "low" : "normal");
            const acts = []; if (n.actions) for (let i = 0; i < n.actions.length; i++) acts.push({ idx: i, text: n.actions[i].text });
            root.pushItem({ id: n.id, appName: n.appName || "System", appIcon: n.appIcon || "", image: n.image || "", summary: n.summary || "Notification", body: n.body || "", urgency: urg, timeout: n.expireTimeout > 0 ? n.expireTimeout : 5500, actions: acts });
        }
    }

    // Multi-Zone 16-Bit Comms Windows: top-center (Security), top-right (Builder/Engineer/App), bottom-center (AI Agent)
    Variants {
        model: [{ zoneId: "top-center", w: 440 }, { zoneId: "top-right", w: 410 }, { zoneId: "bottom-center", w: 540 }]
        PanelWindow {
            id: zoneWin; required property var modelData
            readonly property string zid: modelData.zoneId
            readonly property var zoneToasts: root.activeToasts.filter(t => t.zone === zoneWin.zid)
            visible: zoneWin.zoneToasts.length > 0 && !Status.sessionLocked
            screen: Quickshell.screens[0]; color: "transparent"; exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "superfedora-notifications"; WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: zoneWin.zid !== "bottom-center"; bottom: zoneWin.zid === "bottom-center"; right: zoneWin.zid === "top-right" }
            margins { top: zoneWin.zid === "top-center" ? ((bannerOverlay.active && bannerOverlay.kind === "warning") ? Theme.barHeight + 162 : Theme.barHeight + 10) : (Theme.barHeight + 8); bottom: 68; right: 10 }
            implicitWidth: zoneWin.modelData.w; implicitHeight: zoneCol.implicitHeight

            ColumnLayout {
                id: zoneCol; width: parent.width; spacing: 8
                Repeater {
                    model: zoneWin.zoneToasts
                    Rectangle {
                        id: card; required property var modelData
                        readonly property bool hasBody: String(modelData.body || "") !== ""
                        readonly property string fullBody: String(modelData.body || modelData.summary || "")
                        readonly property bool hasAppIcon: modelData.role === "app" && (modelData.image !== "" || modelData.appIcon !== "")
                        property int visibleChars: 0; property bool talkOpen: false
                        readonly property bool typing: card.visibleChars < card.fullBody.length
                        readonly property color roleColor: modelData.role === "security" ? Theme.danger : (modelData.role === "builder" ? Theme.ok : (modelData.role === "ai" ? Theme.primary : (modelData.role === "engineer" ? Theme.accent : Theme.magenta)))

                        Layout.fillWidth: true; implicitHeight: Math.max(86, contentRow.implicitHeight + 20)
                        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.96); radius: Theme.radius; border.width: 2; border.color: card.roleColor
                        Rectangle { anchors { fill: parent; margins: 3 } color: "transparent"; radius: Theme.radiusSm; border.width: 1; border.color: Theme.border }

                        Timer { running: card.modelData.urgency !== "critical"; interval: card.modelData.timeout || 5500; onTriggered: root.hideToast(card.modelData.id) }
                        Timer {
                            running: card.typing; interval: 25; repeat: true; triggeredOnStart: true
                            onTriggered: { card.visibleChars = Math.min(card.fullBody.length, card.visibleChars + Math.max(1, Math.ceil(card.fullBody.length / 12))); card.talkOpen = card.typing ? !card.talkOpen : false; portraitCanvas.requestPaint(); }
                        }
                        Connections {
                            target: Theme
                            function onModeChanged() { portraitCanvas.requestPaint(); }
                            function onBgChanged() { portraitCanvas.requestPaint(); }
                            function onBlueChanged() { portraitCanvas.requestPaint(); }
                            function onCyanChanged() { portraitCanvas.requestPaint(); }
                        }

                        RowLayout {
                            id: contentRow; anchors { fill: parent; margins: 10 } spacing: 12
                            Rectangle {
                                id: portraitFrame; Layout.preferredWidth: 64; Layout.preferredHeight: 64; Layout.alignment: Qt.AlignTop
                                color: Theme.bgAlt; radius: Theme.radiusSm; border.width: 2; border.color: card.roleColor
                                Rectangle { anchors { fill: parent; margins: 2 } color: "transparent"; border.width: 1; border.color: Theme.border }
                                Image { id: castImg; property bool tryPng: false; anchors { fill: parent; margins: 4 } fillMode: Image.PreserveAspectFit; smooth: false; source: card.hasAppIcon ? "" : ("file://" + root.castDir + (card.modelData.role || "engineer") + (tryPng ? ".png" : ".svg")); visible: !card.hasAppIcon && status === Image.Ready; onStatusChanged: { if (status === Image.Error && !tryPng) tryPng = true; portraitCanvas.requestPaint(); } }
                                IconImage { readonly property string appSrc: card.modelData.image || card.modelData.appIcon; visible: card.hasAppIcon; anchors { fill: parent; margins: 8 } implicitSize: 48; source: appSrc.startsWith("/") ? "file://" + appSrc : (appSrc !== "" ? Quickshell.iconPath(appSrc, true) : "") }
                                Canvas {
                                    id: portraitCanvas; anchors { fill: parent; margins: 4 }
                                    onPaint: {
                                        const ctx = getContext("2d"), u = width / 16.0, rl = card.modelData.role || "engineer";
                                        const px = (x, y, w, h, c) => { ctx.fillStyle = c.toString(); ctx.fillRect(Math.round(x * u), Math.round(y * u), Math.ceil(w * u), Math.ceil(h * u)); };
                                        ctx.clearRect(0, 0, width, height);
                                        if (!card.hasAppIcon && !(castImg.tryPng && castImg.status === Image.Ready)) {
                                            px(0, 0, 16, 16, Theme.bg);
                                            if (rl === "ai") { px(7, 0, 2, 2, Theme.primary); px(3, 2, 10, 2, card.roleColor); px(1, 5, 1, 4, Theme.primary); px(14, 5, 1, 4, Theme.primary); }
                                            else if (rl === "security") { px(3, 1, 10, 2, card.roleColor); px(7, 1, 2, 3, Theme.warning); px(1, 5, 1, 4, card.roleColor); px(14, 5, 1, 4, card.roleColor); }
                                            else if (rl === "builder") { px(4, 1, 8, 2, Theme.warning); px(2, 2, 12, 3, card.roleColor); px(6, 1, 4, 3, Theme.primary); }
                                            else if (rl === "app") { px(3, 1, 10, 1, card.roleColor); px(2, 2, 12, 10, Theme.border); px(3, 3, 10, 8, Theme.bgAlt); px(6, 12, 4, 2, Theme.border); px(4, 14, 8, 1, card.roleColor); }
                                            else { px(4, 1, 8, 1, Theme.primary); px(3, 2, 10, 2, card.roleColor); px(2, 4, 12, 1, Theme.primary); px(1, 6, 2, 3, card.roleColor); px(13, 6, 2, 3, Theme.primary); }
                                            if (rl !== "app") { px(3, 4, 10, 8, Theme.border); px(3, 12, 10, 3, Theme.bgAlt); px(6, 13, 4, 1, card.roleColor); }
                                            px(4, 5, 8, 3, Theme.bg); px(4, 9, 8, 2, Theme.bg);
                                            const ec = card.talkOpen ? Theme.fg : (rl === "security" ? Theme.warning : Theme.primary);
                                            px(5, 6, 2, 1, ec); px(9, 6, 2, 1, ec); px(5, 9, 6, card.talkOpen ? 2 : 1, card.talkOpen ? Theme.fg : card.roleColor);
                                        } else if (!card.hasAppIcon && card.talkOpen) {
                                            px(5, 6, 2, 1, Theme.fg); px(9, 6, 2, 1, Theme.fg); px(5, 9, 6, 2, card.roleColor);
                                        }
                                        ctx.fillStyle = Qt.rgba(0, 0, 0, 0.22).toString();
                                        for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 6
                                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: "[ " + (card.modelData.roleTitle || "SYS ENG") + " // " + String(card.modelData.appName || "SYSTEM").toUpperCase() + " ]"; color: card.roleColor; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                                    Text { text: card.modelData.time; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.bold: true }
                                    Rectangle { width: ackTxt.implicitWidth + 10; height: 18; radius: Theme.radiusSm; color: ackM.containsMouse ? card.roleColor : Theme.bgAlt; border.width: 1; border.color: card.roleColor; Text { id: ackTxt; anchors.centerIn: parent; text: "[ACK]"; color: ackM.containsMouse ? Theme.bg : card.roleColor; font.family: Theme.font; font.pixelSize: 10; font.bold: true } MouseArea { id: ackM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissById(card.modelData.id) } }
                                }
                                Text { Layout.fillWidth: true; text: card.hasBody ? card.modelData.summary : (card.fullBody.slice(0, card.visibleChars) + (card.typing ? "█" : "")); color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; visible: card.hasBody; text: card.fullBody.slice(0, card.visibleChars) + (card.typing ? "█" : ""); color: Theme.fgDim; font.family: Theme.font; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 3 }
                                Row {
                                    visible: (card.modelData.actions || []).length > 0; spacing: 6
                                    Repeater {
                                        model: card.modelData.actions || []
                                        Rectangle { required property var modelData; width: actText.implicitWidth + 14; height: 20; radius: Theme.radiusSm; color: actMouse.containsMouse ? card.roleColor : Theme.bgAlt; border.width: 1; border.color: card.roleColor; Text { id: actText; anchors.centerIn: parent; text: parent.modelData.text; color: actMouse.containsMouse ? Theme.bg : card.roleColor; font.family: Theme.font; font.pixelSize: 10; font.bold: true } MouseArea { id: actMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.invokeAction(card.modelData.id, parent.modelData.idx) } }
                                    }
                                }
                            }
                        }
                        MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: mouse => { if (mouse.button === Qt.RightButton) root.dismissById(card.modelData.id); else root.hideToast(card.modelData.id); } }
                    }
                }
            }
        }
    }
}
