import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.settings

// bar: Caelestia-inspired horizontal top bar, adapted to Slowy. A clean rounded strip with a
// center notch gap for the clock/Slowy. Workspaces, title, tray, mode and power keep Slowy behavior.
PanelWindow {
    id: root

    signal markClicked
    signal trayClicked
    signal powerClicked

    anchors { top: true; left: true; right: true }
    implicitHeight: Math.ceil(48 * Theme.s)
    color: "transparent"
    WlrLayershell.namespace: "slowy-bar"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property int active: Hyprland.focusedWorkspace?.id ?? 0
    readonly property int count: Math.min(10, Math.max(6, active, ...Hyprland.workspaces.values.filter(w => w.toplevels.values.length).map(w => w.id)))
    readonly property var top: ToplevelManager.activeToplevel
    readonly property var bat: UPower.displayDevice
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var net: wifi?.networks.values.find(n => n.connected) ?? null

    function go(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`); }

    Stage {
        id: stage

        readonly property int barH: 40
        readonly property int pad: 14
        readonly property real leftW: leftRow.implicitWidth + pad * 2
        readonly property real rightW: rightRow.implicitWidth + pad * 2

        WheelHandler { onWheel: e => root.go(e.angleDelta.y > 0 ? "-1" : "+1") }

        // background provided by Frame.qml for a unified monitor bezel

        // ---- left: mark, workspaces, active window ----
        Row {
            id: leftRow
            x: 22
            y: 4
            height: stage.barH
            spacing: 12

            // mark
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28; radius: 14
                color: markHov.hovered ? Theme.s2 : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.t } }
                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: Sys.live ? Theme.red : Theme.fg
                }
                HoverHandler { id: markHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.markClicked() }
            }

            // workspaces: Caelestia-inspired pills
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                width: wsRow.implicitWidth + 16
                radius: 15
                color: Theme.s1
                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: root.count
                        Item {
                            id: ws
                            required property int index
                            readonly property int n: index + 1
                            readonly property bool occ: (Hyprland.workspaces.values.find(w => w.id === n)?.toplevels.values.length ?? 0) > 0
                            readonly property bool on: root.active === n
                            readonly property bool nums: Theme.state.barWs === "number"
                            anchors.verticalCenter: parent.verticalCenter
                            width: nums ? 22 : (on ? 28 : 10)
                            height: nums ? 22 : 10

                            Rectangle {
                                anchors.fill: parent
                                radius: nums ? 11 : 5
                                color: ws.nums
                                    ? (ws.on ? Theme.fade(Theme.fg, 0.22) : Theme.fade(Theme.fg, ws.occ ? 0.12 : 0.06))
                                    : (ws.on ? Theme.fg : ws.occ ? Theme.fade(Theme.fg, 0.55) : Theme.fade(Theme.fg, 0.2))
                                Behavior on color { ColorAnimation { duration: Theme.t } }
                            }
                            Behavior on width { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

                            Lb {
                                id: wsLbl
                                visible: ws.nums
                                anchors.centerIn: parent
                                family: Theme.state.barFont
                                text: ws.n
                                px: 10
                                color: ws.on ? Theme.fg : ws.occ ? Theme.fade(Theme.fg, 0.8) : Theme.fade(Theme.fg, 0.45)
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.go(ws.n) }
                        }
                    }
                }
            }

            Lb { family: Theme.state.barFont;
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 260)
                visible: Theme.state.barTitle && (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) > 0
                elide: Text.ElideRight
                text: root.top ? `${root.top.appId.split(".").pop()} · ${root.top.title}` : ""
                px: 10
                color: Theme.fade(Theme.fg, 0.7)
            }
        }

        // ---- right: tray in Theme.state.bar order ----
        Row {
            id: rightRow
            x: stage.width - width - 22
            y: 4
            height: stage.barH
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                width: trayRow.implicitWidth + 20
                radius: 15
                color: Theme.s1
                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 14
                    Repeater {
                        model: Theme.state.bar
                        Loader {
                            id: part
                            required property string modelData
                            readonly property bool quick: modelData !== "mode" && modelData !== "power"
                            anchors.verticalCenter: parent.verticalCenter
                            sourceComponent: root.parts[modelData] ?? null
                            visible: !!sourceComponent && (modelData !== "battery" || root.bat.isLaptopBattery)
                            TapHandler { enabled: part.quick; onTapped: root.trayClicked() }
                            HoverHandler { enabled: part.quick; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
    }

    readonly property var parts: ({ layout: layoutC, wifi: wifiC, bluetooth: btC, sound: soundC, notes: notesC, battery: batC, mode: modeC, power: powerC })
    Component { id: layoutC; Lb { family: Theme.state.barFont; text: Sys.layout; px: 10 } }
    Component {
        id: wifiC
        Rectangle {
            id: wp
            readonly property string ssid: !Networking.wifiEnabled ? "Off" : (root.net?.name ?? "Wi-Fi")
            implicitWidth: iconSeg.width + Math.min(name.implicitWidth, 96) + 18
            implicitHeight: 26
            radius: 13
            color: Theme.s2
            clip: true
            Rectangle {
                id: iconSeg
                width: 28; height: 26; radius: 13
                color: Theme.yellow
                Icon { anchors.centerIn: parent; text: Networking.wifiEnabled ? "\u{F05A9}" : "\u{F05AA}"; font.pixelSize: 13; color: Theme.bg }
            }
            Text {
                id: name
                anchors { left: iconSeg.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: wp.ssid
                font { family: Theme.ui; pixelSize: 12; weight: Font.Medium }
                color: Theme.fg
                elide: Text.ElideRight
            }
        }
    }
    Component {
        id: btC
        Icon {
            text: Bluetooth.defaultAdapter?.enabled ? "\u{F00AF}" : "\u{F00B2}"
            color: Bluetooth.devices.values.some(d => d.connected) ? Theme.fg : Theme.grey
        }
    }
    Component {
        id: soundC
        Icon {
            text: Sys.muted ? "\u{F075F}" : "\u{F057E}"
            WheelHandler { onWheel: e => Sys.setVol(Sys.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
        }
    }
    Component {
        id: notesC
        Icon {
            text: Theme.state.dnd ? "\u{F009B}" : "\u{F009A}"
            color: Notes.list.length ? Theme.fg : Theme.grey
        }
    }
    // battery: bolt while charging, charge grows left to right, fill pulses while charging
    Component {
        id: batC
        Row {
            id: batc
            HoverHandler { onHoveredChanged: { root.batHot = hovered; root.peek(batc); } Component.onDestruction: root.batHot = false }
            spacing: 6
            readonly property bool ac: !UPower.onBattery
            readonly property bool charging: root.bat.state === UPowerDeviceState.Charging
            // pulse at 20 frames/s, like the orb in home/Back: an animation would drive the bar on every vsync (120 Hz) for all
            // charging hours. Cosine with a 2.2 s period, the same two InOutSine segments of 1.1 s
            property real phase: 0
            readonly property real pulse: charging ? 0.675 + 0.325 * Math.cos(phase * Math.PI / 1.1) : 1
            Timer { running: batc.charging; interval: 50; repeat: true; onTriggered: batc.phase = (batc.phase + 0.05) % 2.2; onRunningChanged: batc.phase = 0 }
            Icon { visible: batc.ac; anchors.verticalCenter: parent.verticalCenter; text: "\u{F140B}"; font.pixelSize: 14 }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 14
                radius: 7
                color: "transparent"
                border { width: 1.5; color: Theme.grey }
                Rectangle {
                    x: 3
                    height: parent.height - 6
                    width: (parent.width - 6) * root.bat.percentage
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 4
                    color: root.batLow ? Theme.red : Theme.fg
                    opacity: batc.pulse
                }
            }
            Lb { family: Theme.state.barFont; anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.bat.percentage * 100); px: 10 }
        }
    }
    // power mode as ticks (Rules.modes): ultra shows one, performance shows all; click selects the next,
    // hovering (also over the battery) shows a card with choices
    Component {
        id: modeC
        Item {
            id: ticks
            width: 40
            height: 22
            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: Rules.modeCount
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 3
                        height: 5 + index * 3
                        radius: 1.5
                        color: index <= Rules.mode ? Theme.fg : Theme.s3
                    }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: { root.tickHot = hovered; root.peek(ticks); } Component.onDestruction: root.tickHot = false }
            TapHandler { onTapped: Rules.setMode((Rules.mode + 1) % Rules.modeCount) }
        }
    }
    Component {
        id: powerC
        Icon {
            text: "\u{F0425}"
            color: pwr.hovered ? Theme.fg : Theme.grey
            HoverHandler { id: pwr; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.powerClicked() }
        }
    }

    // ---- battery and power mode: hovering the battery or ticks shows a card below the bar, centered on the
    // hovered item. Charge in Doto, status, scale; below, modes as circles with ticks: click selects, the item under the
    // cursor shows what it does. Leaving both the bar and the card fades it out ----
    property bool batHot: false
    property bool tickHot: false
    readonly property bool powHot: batHot || tickHot || popHov.hovered
    readonly property bool batLow: UPower.onBattery && root.bat.percentage < 0.15
    // the card is centered on the hovered item; it does not jump while visible
    property real popX: 0
    function peek(it) { if (!pop.visible) popX = it.mapToItem(stage, it.width / 2, 0).x; }
    property bool powOpen: false
    property int powPeek: -1
    onPowHotChanged: powHot ? powOpenT.restart() : powCloseT.restart()
    Timer { id: powOpenT; interval: 180; onTriggered: if (root.powHot) root.powOpen = true }
    Timer { id: powCloseT; interval: 300; onTriggered: if (!root.powHot) root.powOpen = false }
    function hm(sec) { const m = Math.round(sec / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`; }
    readonly property string batState: root.bat.state === UPowerDeviceState.Charging
        ? "charging" + (root.bat.timeToFull ? ` · full in ${hm(root.bat.timeToFull)}` : "")
        : !UPower.onBattery ? "on ac · full"
        : "on battery" + (root.bat.timeToEmpty ? ` · ${hm(root.bat.timeToEmpty)} left` : "")

    PopupWindow {
        id: pop
        property real t: root.powOpen ? 1 : 0
        Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        visible: t > 0
        // below the bar, centered on the hovered item; grows downward
        anchor.item: stage
        anchor.rect: Qt.rect(root.popX - (pop.implicitWidth / Theme.s) / 2, stage.height + 8, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        implicitWidth: Math.ceil(440 * Theme.s)
        implicitHeight: Math.ceil(card.height * Theme.s)
        color: "transparent"

        Stage {
            Rectangle {
                id: card
                width: 440
                height: body.height + 52
                radius: 36
                color: Theme.bg
                border { width: 1; color: Theme.s2 }
                opacity: pop.t
                transform: Translate { y: -16 * (1 - pop.t) }
                HoverHandler { id: popHov }

                Column {
                    id: body
                    x: 26
                    y: 26
                    width: parent.width - 52
                    spacing: 18

                    Row {
                        spacing: 14
                        Num { text: Math.round(root.bat.percentage * 100); font.pixelSize: 72 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Lb { family: Theme.state.barFont; text: "% battery"; color: Theme.fg }
                            Lb { family: Theme.state.barFont; text: root.batState }
                        }
                    }
                    Seg { width: parent.width; height: 6; n: 24; f: root.bat.percentage; on: root.batLow ? Theme.red : Theme.fg }

                    Lb { family: Theme.state.barFont; topPadding: 6; text: "power mode" }
                    Row {
                        spacing: (body.width - Rules.modeCount * 80) / Math.max(1, Rules.modeCount - 1)
                        Repeater {
                            model: Rules.modeCount
                            Column {
                                id: mo
                                required property int index
                                readonly property bool on: Rules.mode === index
                                spacing: 10
                                Rectangle {
                                    width: 80
                                    height: 80
                                    radius: 40
                                    color: mo.on ? Theme.fg : moHov.hovered ? Theme.s3 : Theme.s2
                                    Behavior on color { ColorAnimation { duration: Theme.t } }
                                    // ticks: how many are lit indicates the level
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                required property int index
                                                anchors.bottom: parent.bottom
                                                width: 5
                                                height: 8 + index * 6
                                                radius: 2.5
                                                color: index <= mo.index ? (mo.on ? Theme.ink : Theme.fg) : (mo.on ? Theme.mute : Theme.s3)
                                            }
                                        }
                                    }
                                    HoverHandler {
                                        id: moHov
                                        cursorShape: Qt.PointingHandCursor
                                        onHoveredChanged: if (hovered) root.powPeek = mo.index; else if (root.powPeek === mo.index) root.powPeek = -1
                                    }
                                    TapHandler { onTapped: Rules.setMode(mo.index) }
                                }
                                Lb { family: Theme.state.barFont; anchors.horizontalCenter: parent.horizontalCenter; text: mo.index === 3 ? "max" : Rules.modes[mo.index].name; color: mo.on ? Theme.fg : Theme.grey }
                            }
                        }
                    }
                    Lb { family: Theme.state.barFont;
                        readonly property int i: root.powPeek >= 0 ? root.powPeek : Rules.mode
                        width: parent.width
                        elide: Text.ElideRight
                        text: `${Rules.modes[i].what} · ${i === 0 ? Rules.rates[0] : Rules.refreshHz} hz`
                    }
                }
            }
        }
    }
}
