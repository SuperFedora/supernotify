import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// 16-Bit SNES Animated On-Screen Display (OSD) for Volume, Mute & Brightness changes.
Scope {
    id: root
    property bool shown: false
    property string mode: "volume" // "volume" | "brightness"
    property int pulsePhase: 0

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioReady: sink !== null && sink.audio !== null
    readonly property real vol: audioReady ? sink.audio.volume : Status.spkVol
    readonly property bool muted: audioReady ? sink.audio.muted : Status.spkMuted
    readonly property real bri: Status.brightness
    readonly property real activeVal: root.mode === "brightness" ? root.bri : root.vol

    property bool _armed: false
    onVolChanged: if (root.audioReady) show("volume")
    onMutedChanged: if (root.audioReady) show("volume")
    onBriChanged: show("brightness")

    function show(kind) {
        if (!_armed) return;
        root.mode = kind || "volume";
        root.shown = true;
        root.pulsePhase = 0;
        Status.playSfx("volume");
        hide.restart();
    }

    Timer { interval: 1500; running: true; onTriggered: root._armed = true }
    Timer { id: hide; interval: 1350; onTriggered: root.shown = false }
    Timer { running: root.shown; interval: 90; repeat: true; onTriggered: root.pulsePhase = (root.pulsePhase + 1) % 16 }

    IpcHandler {
        target: "osd"
        function volume(): void { root._armed = true; root.show("volume"); }
        function brightness(): void { root._armed = true; root.show("brightness"); }
    }

    PanelWindow {
        visible: root.shown
        screen: Quickshell.screens[0]
        color: "transparent"
        anchors.bottom: true
        margins.bottom: 84
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 296
        implicitHeight: 54

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius
            border.width: 2
            border.color: root.mode === "brightness" ? Theme.yellow : Theme.blue

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: root.mode === "brightness"
                        ? (root.bri >= 0.66 ? "󰃠" : root.bri >= 0.33 ? "󰃟" : "󰃞")
                        : (root.muted ? "󰝟" : root.vol >= 0.66 ? "󰕾" : root.vol >= 0.33 ? "󰖀" : "󰕿")
                    color: root.mode === "brightness" ? Theme.yellow : (root.muted ? Theme.muted : Theme.cyan)
                    font.family: Theme.font
                    font.pixelSize: 20
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.mode === "brightness" ? "DISPLAY LUMEN // SYNTH" : (root.muted ? "AUDIO MUTED // SYNTH" : "MASTER AUDIO // SYNTH")
                            color: Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: 10
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(root.activeVal * 100) + "%"
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Repeater {
                            model: 16
                            Rectangle {
                                required property int index
                                Layout.fillWidth: true
                                height: (lit && index === root.pulsePhase) ? 10 : 8
                                radius: Theme.radiusSm > 0 ? 2 : 0
                                readonly property bool lit: (index + 1) / 16.0 <= root.activeVal + 0.02
                                color: !lit ? Theme.bgAlt : (index === root.pulsePhase ? Theme.fg : (root.mode === "brightness" ? Theme.yellow : (root.muted ? Theme.muted : (index >= 13 ? Theme.cyan : Theme.blue))))
                            }
                        }
                    }
                }
            }
        }
    }
}
