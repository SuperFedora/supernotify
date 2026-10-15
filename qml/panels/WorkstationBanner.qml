import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."

// 16-Bit Workstation Animated Center-Screen Banners:
//   R E A D Y | W A R N I N G | U P D A T E   C O M P L E T E | C H E C K P O I N T   S A V E D
PanelWindow {
    id: bannerWin
    property string kind: ""
    property string subtitle: ""
    property int phase: 0

    readonly property bool active: bannerWin.kind !== "" && !Status.sessionLocked
    visible: bannerWin.active; screen: Quickshell.screens[0]; color: "transparent"
    WlrLayershell.namespace: "superfedora-banner"; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None; exclusionMode: ExclusionMode.Ignore
    anchors.top: bannerWin.kind === "warning"; margins.top: bannerWin.kind === "warning" ? (Theme.barHeight + 8) : 0
    implicitWidth: 640; implicitHeight: 148

    readonly property string pixelWord: bannerWin.kind === "warning" ? "WARNING" : (bannerWin.kind === "update" ? "UPDATE COMPLETE" : (bannerWin.kind === "checkpoint" ? "CHECKPOINT SAVED" : "READY"))
    readonly property string spacedTitle: bannerWin.kind === "warning" ? "W A R N I N G" : (bannerWin.kind === "update" ? "U P D A T E   C O M P L E T E" : (bannerWin.kind === "checkpoint" ? "C H E C K P O I N T   S A V E D" : "R E A D Y"))
    readonly property string defaultSub: bannerWin.kind === "warning" ? "CRITICAL WORKSTATION ALERT // CHECK SYSTEM TELEMETRY" : (bannerWin.kind === "update" ? "SYSTEM PACKAGES & SOURCE FORGE TARGETS SYNCHRONIZED" : (bannerWin.kind === "checkpoint" ? "BTRFS SNAPSHOT CHECKPOINT COMMITTED TO ROOT SUBVOLUME" : "SUPER FEDORA 16-BIT WORKSTATION // SESSION ONLINE"))
    readonly property color mainColor: bannerWin.kind === "warning" ? ((bannerWin.phase % 2 === 0) ? Theme.danger : Theme.warning) : (bannerWin.kind === "update" ? Theme.ok : (bannerWin.kind === "checkpoint" ? Theme.cyan : Theme.primary))
    readonly property color frameColor: bannerWin.kind === "warning" ? Theme.danger : (bannerWin.kind === "update" ? Theme.ok : (bannerWin.kind === "checkpoint" ? Theme.cyan : Theme.accent))
    readonly property color stripeColor: bannerWin.kind === "warning" ? Theme.warning : Theme.accent

    // 5x7 16-bit pixel block glyph bitmaps (each row is 5 bits, MSB left)
    readonly property var glyphs: ({
        "A": [14, 17, 17, 31, 17, 17, 17], "C": [14, 17, 16, 16, 16, 17, 14], "D": [30, 17, 17, 17, 17, 17, 30],
        "E": [31, 16, 16, 30, 16, 16, 31], "G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17],
        "I": [14,  4,  4,  4,  4,  4, 14], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
        "M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 25, 21, 19, 17, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
        "P": [30, 17, 17, 30, 16, 16, 16], "R": [30, 17, 17, 30, 20, 18, 17], "S": [15, 16, 16, 14,  1,  1, 30],
        "T": [31,  4,  4,  4,  4,  4,  4], "U": [17, 17, 17, 17, 17, 17, 14], "V": [17, 17, 17, 17, 17, 10,  4],
        "W": [17, 17, 17, 21, 21, 27, 17], "Y": [17, 17, 10,  4,  4,  4,  4], " ": [ 0,  0,  0,  0,  0,  0,  0]
    })

    function paintHazard(ctx, w, h, rev) {
        ctx.clearRect(0, 0, w, h); ctx.fillStyle = Theme.bgAlt.toString(); ctx.fillRect(0, 0, w, h);
        const step = 16, off = rev ? (step - ((bannerWin.phase * 4) % step)) : ((bannerWin.phase * 4) % step);
        for (let x = -step; x < w + step; x += step) {
            ctx.fillStyle = ((Math.floor((x + step) / step) % 2) === 0) ? bannerWin.frameColor.toString() : bannerWin.stripeColor.toString();
            ctx.beginPath(); ctx.moveTo(x + off, 0); ctx.lineTo(x + off + 8, 0); ctx.lineTo(x + off + 2, h); ctx.lineTo(x + off - 6, h); ctx.closePath(); ctx.fill();
        }
    }

    function trigger(k, sub) {
        const norm = String(k || "ready").toLowerCase();
        bannerWin.kind = (norm === "warn" || norm === "warning") ? "warning"
            : (norm === "update" || norm === "forge") ? "update"
            : (norm === "checkpoint" || norm === "snapshot" || norm === "btrfs") ? "checkpoint" : "ready";
        bannerWin.subtitle = String(sub || ""); bannerWin.phase = 0;
        hideTimer.interval = bannerWin.kind === "ready" ? 950 : (bannerWin.kind === "warning" ? 2400 : 1850);
        hideTimer.restart(); dropAnim.restart();
        topHazard.requestPaint(); botHazard.requestPaint(); pixelCanvas.requestPaint();
    }

    Timer { id: hideTimer; interval: 950; onTriggered: bannerWin.kind = "" }
    Timer {
        running: bannerWin.active; interval: 50; repeat: true
        onTriggered: { bannerWin.phase = (bannerWin.phase + 1) % 64; topHazard.requestPaint(); botHazard.requestPaint(); pixelCanvas.requestPaint(); }
    }
    Connections {
        target: Theme
        function onModeChanged() { topHazard.requestPaint(); botHazard.requestPaint(); pixelCanvas.requestPaint(); }
        function onBgChanged() { topHazard.requestPaint(); botHazard.requestPaint(); pixelCanvas.requestPaint(); }
        function onBlueChanged() { topHazard.requestPaint(); botHazard.requestPaint(); pixelCanvas.requestPaint(); }
        function onCyanChanged() { topHazard.requestPaint(); botHazard.requestPaint(); pixelCanvas.requestPaint(); }
    }

    NumberAnimation { id: dropAnim; target: bannerBox; property: "y"; from: -24; to: 0; duration: 120; easing.type: Easing.OutQuad }

    Rectangle {
        id: bannerBox; width: parent.width; height: parent.height
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97); radius: Theme.radius; border.width: 3; border.color: bannerWin.frameColor
        Rectangle { anchors { fill: parent; margins: 4 } color: "transparent"; radius: Theme.radiusSm; border.width: 1; border.color: bannerWin.stripeColor }

        ColumnLayout {
            anchors { fill: parent; margins: 8 } spacing: 6
            Canvas { id: topHazard; Layout.fillWidth: true; Layout.preferredHeight: 12; onPaint: bannerWin.paintHazard(getContext("2d"), width, height, false) }
            Canvas {
                id: pixelCanvas; Layout.fillWidth: true; Layout.preferredHeight: 46
                onPaint: {
                    const ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                    const word = bannerWin.pixelWord, px = word.length > 10 ? 4 : 6, charW = 5 * px + px;
                    const startX = Math.floor((width - (word.length * charW - px)) / 2), startY = Math.floor((height - 7 * px) / 2);
                    const waveIdx = bannerWin.phase % Math.max(1, word.length + 4);
                    for (let i = 0; i < word.length; i++) {
                        const rows = bannerWin.glyphs[word[i]] || bannerWin.glyphs[" "], cx = startX + i * charW;
                        const gleam = (i === waveIdx || i + 1 === waveIdx);
                        for (let r = 0; r < 7; r++) {
                            const bits = rows[r];
                            for (let c = 0; c < 5; c++) {
                                if ((bits >> (4 - c)) & 1) {
                                    const x = cx + c * px, y = startY + r * px;
                                    ctx.fillStyle = Theme.border.toString(); ctx.fillRect(x + 2, y + 2, px, px);
                                    ctx.fillStyle = (gleam ? Theme.fg : bannerWin.mainColor).toString(); ctx.fillRect(x, y, px, px);
                                    if (r === 0 || !((rows[r - 1] >> (4 - c)) & 1)) { ctx.fillStyle = Theme.fg.toString(); ctx.fillRect(x, y, px, Math.max(1, Math.floor(px / 3))); }
                                }
                            }
                        }
                    }
                    const scanY = (bannerWin.phase * 3) % Math.max(1, Math.floor(height));
                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.12).toString(); ctx.fillRect(0, scanY, width, 2);
                }
            }
            Text { Layout.alignment: Qt.AlignHCenter; text: "▸  " + bannerWin.spacedTitle + "  ◂"; color: bannerWin.mainColor; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true }
            Text { Layout.alignment: Qt.AlignHCenter; text: "[ " + (bannerWin.subtitle !== "" ? bannerWin.subtitle.toUpperCase() : bannerWin.defaultSub) + " ]"; color: Theme.fgDim; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; font.bold: true; elide: Text.ElideRight }
            Canvas { id: botHazard; Layout.fillWidth: true; Layout.preferredHeight: 12; onPaint: bannerWin.paintHazard(getContext("2d"), width, height, true) }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bannerWin.kind = "" }
    }
}
