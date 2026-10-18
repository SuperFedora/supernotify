import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."

// Full-Screen Mega Man X Style WARNING Overlay
PanelWindow {
    id: bannerWin
    property string kind: ""
    property int phase: 0
    property bool screensaverActive: false

    readonly property bool active: bannerWin.kind !== "" && !Status.sessionLocked && !bannerWin.screensaverActive
    visible: bannerWin.active
    screen: Quickshell.screens[0]
    color: "transparent"
    WlrLayershell.namespace: "superfedora-warning"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    // Mega Man X rhythmic strobe: alternates bright crimson and deep red every phase tick
    readonly property bool flashHigh: (bannerWin.phase % 2) === 0
    readonly property color alertRed: Theme.danger
    readonly property color alertBright: "#ff3b5c"
    readonly property color alertDim: Qt.rgba(Theme.danger.r * 0.45, Theme.danger.g * 0.15, Theme.danger.b * 0.2, 0.95)
    readonly property color activeColor: bannerWin.flashHigh ? bannerWin.alertBright : bannerWin.alertRed

    // 5x7 16-bit blocky pixel glyph bitmaps for W A R N I N G (each row is 5 bits, MSB left)
    readonly property var glyphs: ({
        "W": [17, 17, 17, 21, 21, 27, 17],
        "A": [14, 17, 17, 31, 17, 17, 17],
        "R": [30, 17, 17, 30, 20, 18, 17],
        "N": [17, 25, 21, 19, 17, 17, 17],
        "I": [14,  4,  4,  4,  4,  4, 14],
        "G": [14, 17, 16, 23, 17, 17, 15],
        " ": [ 0,  0,  0,  0,  0,  0,  0]
    })

    function trigger(k) {
        const norm = String(k || "warning").toLowerCase();
        if (norm !== "warn" && norm !== "warning" && norm !== "critical" && norm !== "alert") {
            return;
        }
        bannerWin.kind = "warning";
        bannerWin.phase = 0;
        hideTimer.restart();
        pixelCanvas.requestPaint();
    }

    Timer {
        id: hideTimer
        interval: 2800
        onTriggered: bannerWin.kind = ""
    }

    Timer {
        running: bannerWin.active
        interval: 180
        repeat: true
        onTriggered: {
            bannerWin.phase = (bannerWin.phase + 1) % 32;
            pixelCanvas.requestPaint();
        }
    }

    // Full-screen darkened backdrop with subtle crimson pulse
    Rectangle {
        anchors.fill: parent
        color: bannerWin.flashHigh
            ? Qt.rgba(0.14, 0.01, 0.03, 0.86)
            : Qt.rgba(0.03, 0.01, 0.02, 0.82)

        // Center-screen full-width Mega Man X WARNING band
        Rectangle {
            id: centerBand
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 236
            color: Qt.rgba(Theme.bg.r * 0.4, Theme.bg.g * 0.2, Theme.bg.b * 0.25, 0.96)

            // Top Mega Man X horizontal caution bar
            Rectangle {
                id: topBar
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 16
                color: bannerWin.activeColor
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 3
                    color: bannerWin.flashHigh ? Theme.warning : Theme.bg
                }
            }

            // Inner top thin rule line
            Rectangle {
                anchors { top: topBar.bottom; topMargin: 6; left: parent.left; right: parent.right }
                height: 2
                color: bannerWin.flashHigh ? bannerWin.alertRed : bannerWin.alertDim
            }

            // Center content: Strictly Giant pixel WARNING
            Canvas {
                id: pixelCanvas
                anchors.centerIn: parent
                width: parent.width
                height: 112
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const word = "WARNING";
                    const px = 15;
                    const charW = 5 * px + px * 2;
                    const totalW = word.length * charW - px * 2;
                    const startX = Math.floor((width - totalW) / 2);
                    const startY = Math.floor((height - 7 * px) / 2);
                    const mainCol = (bannerWin.flashHigh ? bannerWin.alertBright : bannerWin.alertDim).toString();
                    const shadowCol = Qt.rgba(0, 0, 0, 0.85).toString();
                    const edgeCol = (bannerWin.flashHigh ? "#ffffff" : bannerWin.alertRed).toString();

                    for (let i = 0; i < word.length; i++) {
                        const rows = bannerWin.glyphs[word[i]] || bannerWin.glyphs[" "];
                        const cx = startX + i * charW;
                        for (let r = 0; r < 7; r++) {
                            const bits = rows[r];
                            for (let c = 0; c < 5; c++) {
                                if ((bits >> (4 - c)) & 1) {
                                    const x = cx + c * px;
                                    const y = startY + r * px;
                                    ctx.fillStyle = shadowCol;
                                    ctx.fillRect(x + 4, y + 4, px, px);
                                    ctx.fillStyle = mainCol;
                                    ctx.fillRect(x, y, px, px);
                                    if (r === 0 || !((rows[r - 1] >> (4 - c)) & 1)) {
                                        ctx.fillStyle = edgeCol;
                                        ctx.fillRect(x, y, px, 3);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Inner bottom thin rule line
            Rectangle {
                anchors { bottom: botBar.top; bottomMargin: 6; left: parent.left; right: parent.right }
                height: 2
                color: bannerWin.flashHigh ? bannerWin.alertRed : bannerWin.alertDim
            }

            // Bottom Mega Man X horizontal caution bar
            Rectangle {
                id: botBar
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 16
                color: bannerWin.activeColor
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 3
                    color: bannerWin.flashHigh ? Theme.warning : Theme.bg
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: bannerWin.kind = ""
        }
    }
}
