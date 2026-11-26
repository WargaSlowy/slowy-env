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

// bar: Caelestia-inspired bar adapted to Slowy. Horizontal (top) or vertical (left).
// Workspaces, title/apps, tray, mode and power keep Slowy behavior.
PanelWindow {
    id: root

    signal markClicked
    signal trayClicked
    signal powerClicked

    readonly property bool vert: Theme.state.barOrient === "vertical"
    readonly property bool bottom: !vert && Theme.state.barY === "bottom"
    anchors.top: !bottom
    anchors.left: true
    anchors.right: !vert
    anchors.bottom: vert || bottom
    implicitHeight: vert ? 0 : Math.ceil(48 * Theme.s)
    implicitWidth: vert ? Math.ceil(48 * Theme.s) : 0
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

        WheelHandler { onWheel: e => root.go(e.angleDelta.y > 0 ? "-1" : "+1") }

        // ---- horizontal layout ----
        Item {
            anchors.fill: parent
            visible: !root.vert

            Row {
                id: leftRow
                x: 22
                y: 4
                height: 40
                spacing: 12

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 14
                    color: markHov.hovered ? Theme.s2 : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.t } }
                    Image { anchors.centerIn: parent; source: "../assets/icon_start.png"; sourceSize: Qt.size(22, 22); width: 22; height: 22; fillMode: Image.PreserveAspectFit }
                    Rectangle { anchors { right: parent.right; top: parent.top } width: 6; height: 6; radius: 3; color: Theme.red; visible: Sys.live }
                    HoverHandler { id: markHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.markClicked() }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    width: wsRowH.implicitWidth + 16
                    radius: 15
                    color: Theme.s1
                    Row {
                        id: wsRowH
                        anchors.centerIn: parent
                        spacing: 6
                        Repeater {
                            model: root.count
                            Item {
                                id: wsH
                                required property int index
                                readonly property int n: index + 1
                                readonly property bool occ: (Hyprland.workspaces.values.find(w => w.id === n)?.toplevels.values.length ?? 0) > 0
                                readonly property bool on: root.active === n
                                readonly property bool nums: Theme.state.barWs === "number"
                                anchors.verticalCenter: parent.verticalCenter
                                width: nums ? (on ? 42 : 22) : (on ? 40 : 10)
                                height: nums ? 22 : 10
                                Rectangle {
                                    anchors.fill: parent
                                    radius: wsH.nums ? 11 : 5
                                    color: wsH.nums ? (wsH.on ? Theme.fade(Theme.fg, 0.22) : Theme.fade(Theme.fg, wsH.occ ? 0.12 : 0.06))
                                                    : (wsH.on ? Theme.fg : wsH.occ ? Theme.fade(Theme.fg, 0.55) : Theme.fade(Theme.fg, 0.2))
                                    Behavior on color { ColorAnimation { duration: Theme.t } }
                                }
                                Behavior on width { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                                Lb { visible: wsH.nums; anchors.centerIn: parent; family: Theme.state.barFont; text: wsH.n; px: 10; color: wsH.on ? Theme.fg : wsH.occ ? Theme.fade(Theme.fg, 0.8) : Theme.fade(Theme.fg, 0.45) }
                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onHoveredChanged: {
                                        if (hovered && wsH.occ) { root.wsPeek(wsH, wsH.n); root.wsPreviewHot = true; }
                                        else if (!hovered) root.wsPreviewHot = false;
                                    }
                                }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.go(wsH.n) }
                            }
                        }
                    }
                }

                Lb {
                    family: Theme.state.barFont
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 260)
                    visible: Theme.state.barTitle && (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) > 0
                    elide: Text.ElideRight
                    text: root.top ? `${root.top.appId.split(".").pop()} · ${root.top.title}` : ""
                    px: 10
                    color: Theme.fade(Theme.fg, 0.7)
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: leftRow.verticalCenter
                height: 30
                visible: appRowH.implicitWidth > 0
                width: appRowH.implicitWidth + 20
                radius: 15
                color: Theme.s1
                Row {
                    id: appRowH
                    anchors.centerIn: parent
                    spacing: 8
                    Repeater {
                        model: Hyprland.focusedWorkspace?.toplevels.values ?? []
                        Item {
                            required property var modelData
                            readonly property string cls: modelData.lastIpcObject?.class ?? ""
                            readonly property string icon: { const e = DesktopEntries.heuristicLookup(cls); return e?.icon ? Quickshell.iconPath(e.icon, true) : ""; }
                            width: 18; height: 18
                            Image { anchors.fill: parent; visible: status === Image.Ready; source: parent.icon; sourceSize: Qt.size(18, 18); asynchronous: true }
                            Icon { anchors.centerIn: parent; visible: !parent.icon; text: "\u{F003B}"; font.pixelSize: 14; color: Theme.grey }
                        }
                    }
                }
            }

            Row {
                id: rightRow
                x: stage.width - width - 22
                y: 4
                height: 40
                spacing: 6

                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: Theme.state.bar.includes("wifi") ? root.parts.wifi : null
                    visible: !!sourceComponent
                    TapHandler { onTapped: root.trayClicked() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: Theme.state.bar.includes("sound") ? root.parts.sound : null
                    visible: !!sourceComponent
                    TapHandler { onTapped: root.trayClicked() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    visible: trayRowH.implicitWidth > 0
                    width: trayRowH.implicitWidth + 20
                    radius: 15
                    color: Theme.s1
                    Row {
                        id: trayRowH
                        anchors.centerIn: parent
                        spacing: 14
                        Repeater {
                            model: Theme.state.bar
                            Loader {
                                id: partH
                                required property string modelData
                                readonly property bool quick: modelData !== "mode" && modelData !== "power"
                                anchors.verticalCenter: parent.verticalCenter
                                sourceComponent: (modelData !== "wifi" && modelData !== "sound" && modelData !== "power") ? (root.parts[modelData] ?? null) : null
                                visible: !!sourceComponent && (modelData !== "battery" || root.bat.isLaptopBattery)
                                TapHandler { enabled: partH.quick; onTapped: root.trayClicked() }
                                HoverHandler { enabled: partH.quick; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: Theme.state.bar.includes("power") ? root.parts.power : null
                    visible: !!sourceComponent
                }
            }
        }

        // ---- vertical layout (left) ----
        Item {
            anchors.fill: parent
            visible: root.vert

            Column {
                x: 10
                y: 10
                spacing: 10
                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: markHovV.hovered ? Theme.s2 : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.t } }
                    Image { anchors.centerIn: parent; source: "../assets/icon_start.png"; sourceSize: Qt.size(22, 22); width: 22; height: 22; fillMode: Image.PreserveAspectFit }
                    Rectangle { anchors { right: parent.right; top: parent.top } width: 6; height: 6; radius: 3; color: Theme.red; visible: Sys.live }
                    HoverHandler { id: markHovV; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.markClicked() }
                }

                Rectangle {
                    width: 30
                    height: wsColV.implicitHeight + 12
                    radius: 15
                    color: Theme.s1
                    Column {
                        id: wsColV
                        anchors.centerIn: parent
                        spacing: 6
                        Repeater {
                            model: root.count
                            Item {
                                id: wsV
                                required property int index
                                readonly property int n: index + 1
                                readonly property bool occ: (Hyprland.workspaces.values.find(w => w.id === n)?.toplevels.values.length ?? 0) > 0
                                readonly property bool on: root.active === n
                                readonly property bool nums: Theme.state.barWs === "number"
                                width: nums ? 22 : 10
                                height: nums ? (on ? 28 : 22) : (on ? 24 : 10)
                                anchors.horizontalCenter: parent.horizontalCenter
                                Rectangle {
                                    anchors.fill: parent
                                    radius: wsV.nums ? 11 : 5
                                    color: wsV.nums ? (wsV.on ? Theme.fade(Theme.fg, 0.22) : Theme.fade(Theme.fg, wsV.occ ? 0.12 : 0.06))
                                                    : (wsV.on ? Theme.fg : wsV.occ ? Theme.fade(Theme.fg, 0.55) : Theme.fade(Theme.fg, 0.2))
                                    Behavior on color { ColorAnimation { duration: Theme.t } }
                                }
                                Behavior on height { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                                Lb { visible: wsV.nums; anchors.centerIn: parent; family: Theme.state.barFont; text: wsV.n; px: 9; color: wsV.on ? Theme.fg : wsV.occ ? Theme.fade(Theme.fg, 0.8) : Theme.fade(Theme.fg, 0.45) }
                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onHoveredChanged: {
                                        if (hovered && wsV.occ) { root.wsPeek(wsV, wsV.n); root.wsPreviewHot = true; }
                                        else if (!hovered) root.wsPreviewHot = false;
                                    }
                                }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.go(wsV.n) }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                visible: appColV.implicitHeight > 0
                height: appColV.implicitHeight + 16
                radius: 15
                color: Theme.s1
                Column {
                    id: appColV
                    anchors.centerIn: parent
                    spacing: 8
                    Repeater {
                        model: Hyprland.focusedWorkspace?.toplevels.values ?? []
                        Item {
                            required property var modelData
                            readonly property string cls: modelData.lastIpcObject?.class ?? ""
                            readonly property string icon: { const e = DesktopEntries.heuristicLookup(cls); return e?.icon ? Quickshell.iconPath(e.icon, true) : ""; }
                            width: 18; height: 18
                            Image { anchors.fill: parent; visible: status === Image.Ready; source: parent.icon; sourceSize: Qt.size(18, 18); asynchronous: true }
                            Icon { anchors.centerIn: parent; visible: !parent.icon; text: "\u{F003B}"; font.pixelSize: 14; color: Theme.grey }
                        }
                    }
                }
            }

            Column {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
                spacing: 8

                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: Theme.state.bar.includes("wifi") ? root.parts.wifi : null
                    visible: !!sourceComponent
                    TapHandler { onTapped: root.trayClicked() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: Theme.state.bar.includes("sound") ? root.parts.sound : null
                    visible: !!sourceComponent
                    TapHandler { onTapped: root.trayClicked() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 30
                    visible: trayColV.implicitHeight > 0
                    height: trayColV.implicitHeight + 16
                    radius: 15
                    color: Theme.s1
                    Column {
                        id: trayColV
                        anchors.centerIn: parent
                        spacing: 10
                        Repeater {
                            model: Theme.state.bar
                            Loader {
                                id: partV
                                required property string modelData
                                readonly property bool quick: modelData !== "mode" && modelData !== "power"
                                anchors.horizontalCenter: parent.horizontalCenter
                                sourceComponent: (modelData !== "wifi" && modelData !== "sound" && modelData !== "power") ? (root.parts[modelData] ?? null) : null
                                visible: !!sourceComponent && (modelData !== "battery" || root.bat.isLaptopBattery)
                                TapHandler { enabled: partV.quick; onTapped: root.trayClicked() }
                                HoverHandler { enabled: partV.quick; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: Theme.state.bar.includes("power") ? root.parts.power : null
                    visible: !!sourceComponent
                }
            }
        }
    }

    readonly property var parts: ({ layout: layoutC, wifi: wifiC, bluetooth: btC, sound: soundC, notes: notesC, battery: batC, mode: modeC, power: powerC })
    Component { id: layoutC; Lb { family: Theme.state.barFont; text: Sys.layout; px: 10 } }
    Component {
        id: wifiC
        Item {
            implicitWidth: root.vert ? 26 : wp.implicitWidth + 8
            implicitHeight: root.vert ? 26 : wp.implicitHeight
            Icon { visible: root.vert; anchors.centerIn: parent; text: Networking.wifiEnabled ? "\u{F05A9}" : "\u{F05AA}"; font.pixelSize: 16; color: Theme.fg }
            Rectangle {
                id: wp
                visible: !root.vert
                anchors.centerIn: parent
                readonly property string ssid: !Networking.wifiEnabled ? "Off" : (root.net?.name ?? "Wi-Fi")
                implicitWidth: iconSeg.width + Math.min(name.implicitWidth, 96) + 18
                implicitHeight: 26
                radius: 13
                color: Theme.s2
                clip: true
                Rectangle {
                    id: iconSeg
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 26; radius: 13; topRightRadius: 0; bottomRightRadius: 0; color: Theme.yellow
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
    }
    Component { id: btC; Icon { text: Bluetooth.defaultAdapter?.enabled ? "\u{F00AF}" : "\u{F00B2}"; color: Bluetooth.devices.values.some(d => d.connected) ? Theme.fg : Theme.grey } }
    Component {
        id: soundC
        Item {
            id: vpill
            implicitWidth: root.vert ? 26 : sp.implicitWidth + 8; implicitHeight: root.vert ? 26 : sp.implicitHeight
            width: implicitWidth; height: implicitHeight
            property bool hot: false
            HoverHandler { onHoveredChanged: vpill.hot = hovered }
            Icon { visible: root.vert; anchors.centerIn: parent; text: Sys.muted ? "\u{F075F}" : "\u{F057E}"; font.pixelSize: 16; color: Theme.fg }
            Rectangle {
                id: sp
                visible: !root.vert
                anchors.centerIn: parent
                readonly property string label: Sys.muted ? "Mute" : Math.round(Sys.vol * 100) + "%"
                implicitWidth: sIcon.width + (vpill.hot ? 72 : Math.min(sName.implicitWidth, 52)) + 18
                implicitHeight: 26; radius: 13; color: Theme.s2; clip: true
                Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Rectangle {
                    id: sIcon
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 26; radius: 13; topRightRadius: 0; bottomRightRadius: 0; color: "#67b0e8"
                    Icon { anchors.centerIn: parent; text: Sys.muted ? "\u{F075F}" : "\u{F057E}"; font.pixelSize: 13; color: Theme.bg }
                }
                Text {
                    id: sName
                    anchors { left: sIcon.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: sp.label
                    font { family: Theme.ui; pixelSize: 12; weight: Font.Medium }
                    color: Theme.fg
                    opacity: vpill.hot ? 0 : 1; Behavior on opacity { NumberAnimation { duration: 100 } }
                }
                Rectangle {
                    anchors { left: sIcon.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    height: 6; radius: 3; color: Theme.s3
                    opacity: vpill.hot ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } }
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, Sys.vol)); height: parent.height; radius: 3; color: Sys.muted ? Theme.grey : "#67b0e8"; Behavior on width { NumberAnimation { duration: 80 } } }
                }
            }
            WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: e => Sys.setVol(Sys.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
        }
    }
    Component { id: notesC; Icon { text: Theme.state.dnd ? "\u{F009B}" : "\u{F009A}"; color: Notes.list.length ? Theme.fg : Theme.grey } }
    Component {
        id: batC
        Item {
            id: batc
            implicitWidth: root.vert ? 26 : batRow.implicitWidth
            implicitHeight: root.vert ? 26 : batRow.implicitHeight
            HoverHandler { onHoveredChanged: { root.batHot = hovered; root.peek(batc); } Component.onDestruction: root.batHot = false }
            readonly property bool ac: !UPower.onBattery
            readonly property bool charging: root.bat.state === UPowerDeviceState.Charging
            property real phase: 0
            readonly property real pulse: charging ? 0.675 + 0.325 * Math.cos(phase * Math.PI / 1.1) : 1
            Timer { running: batc.charging; interval: 50; repeat: true; onTriggered: batc.phase = (batc.phase + 0.05) % 2.2; onRunningChanged: batc.phase = 0 }
            Icon { visible: root.vert; anchors.centerIn: parent; text: "\u{F140B}"; font.pixelSize: 16; color: batc.ac ? Theme.green : Theme.fg }
            Row {
                id: batRow
                visible: !root.vert
                spacing: 6
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; radius: 5; color: batc.ac ? Theme.green : Theme.s3; Icon { anchors.centerIn: parent; text: "\u{F140B}"; font.pixelSize: 13; color: batc.ac ? Theme.bg : Theme.fg } }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter; width: 26; height: 14; radius: 7; color: "transparent"; border { width: 1.5; color: Theme.grey }
                    Rectangle { x: 3; height: parent.height - 6; width: (parent.width - 6) * root.bat.percentage; anchors.verticalCenter: parent.verticalCenter; radius: 4; color: root.batLow ? Theme.red : Theme.fg; opacity: batc.pulse }
                }
                Lb { family: Theme.state.barFont; anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.bat.percentage * 100); px: 10 }
            }
        }
    }
    Component {
        id: modeC
        Item {
            id: ticks
            width: 40; height: 22
            Row {
                anchors.centerIn: parent; spacing: 2
                Repeater {
                    model: Rules.modeCount
                    Rectangle { required property int index; anchors.bottom: parent.bottom; width: 3; height: 5 + index * 3; radius: 1.5; color: index <= Rules.mode ? Theme.fg : Theme.s3 }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: { root.tickHot = hovered; root.peek(ticks); } Component.onDestruction: root.tickHot = false }
            TapHandler { onTapped: Rules.setMode((Rules.mode + 1) % Rules.modeCount) }
        }
    }
    Component {
        id: powerC
        Rectangle {
            width: 26; height: 26; radius: 8; color: Theme.red
            Icon { anchors.centerIn: parent; text: "\u{F0425}"; font.pixelSize: 14; color: Theme.bg }
            HoverHandler { id: pwr; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.powerClicked() }
        }
    }

    // ---- battery and power mode popup ----
    property bool batHot: false
    property bool tickHot: false
    readonly property bool powHot: batHot || tickHot || popHov.hovered

    property bool batLow: UPower.onBattery && root.bat.percentage < 0.15
    property bool batWarn30: UPower.onBattery && root.bat.percentage <= 0.30
    onBatWarn30Changed: if (batWarn30) Quickshell.execDetached(["notify-send", "-u", "normal", "-i", "battery-caution", "Battery Low", "Baterai tersisa " + Math.round(root.bat.percentage * 100) + "%"])

    property real popX: 0
    property real popY: 0
    function peek(it) { if (!pop.visible) { const p = it.mapToItem(stage, 0, 0); popX = p.x + it.width / 2; popY = p.y + it.height / 2; } }
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
        anchor.item: stage
        anchor.rect: root.vert
            ? Qt.rect(stage.width + 8, root.popY - (pop.implicitHeight / Theme.s) / 2, 1, 1)
            : (root.bottom
                ? Qt.rect(root.popX - (pop.implicitWidth / Theme.s) / 2, -(pop.implicitHeight / Theme.s) - 8, 1, 1)
                : Qt.rect(root.popX - (pop.implicitWidth / Theme.s) / 2, stage.height + 8, 1, 1))
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
                transform: Translate { x: root.vert ? -16 * (1 - pop.t) : 0; y: root.vert ? 0 : (root.bottom ? 16 * (1 - pop.t) : -16 * (1 - pop.t)) }
                HoverHandler { id: popHov }

                Column {
                    id: body
                    x: 26; y: 26
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
                                    width: 80; height: 80; radius: 40
                                    color: mo.on ? Theme.fg : moHov.hovered ? Theme.s3 : Theme.s2
                                    Behavior on color { ColorAnimation { duration: Theme.t } }
                                    Row {
                                        anchors.centerIn: parent; spacing: 4
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                required property int index
                                                anchors.bottom: parent.bottom
                                                width: 5; height: 8 + index * 6; radius: 2.5
                                                color: index <= mo.index ? (mo.on ? Theme.ink : Theme.fg) : (mo.on ? Theme.mute : Theme.s3)
                                            }
                                        }
                                    }
                                    HoverHandler { id: moHov; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.powPeek = mo.index; else if (root.powPeek === mo.index) root.powPeek = -1 }
                                    TapHandler { onTapped: Rules.setMode(mo.index) }
                                }
                                Lb { family: Theme.state.barFont; anchors.horizontalCenter: parent.horizontalCenter; text: mo.index === 3 ? "max" : Rules.modes[mo.index].name; color: mo.on ? Theme.fg : Theme.grey }
                            }
                        }
                    }
                    Lb { family: Theme.state.barFont; readonly property int i: root.powPeek >= 0 ? root.powPeek : Rules.mode; width: parent.width; elide: Text.ElideRight; text: `${Rules.modes[i].what} · ${i === 0 ? Rules.rates[0] : Rules.refreshHz} hz` }
                }
            }
        }
    }

    // workspace preview
    property int wsPreviewN: -1
    property real wsPreviewX: 0
    property real wsPreviewY: 0
    property bool wsPreviewHot: false
    readonly property bool wsPopHot: wsPreviewHot || wsPopHov.hovered
    property bool wsPreviewOpen: false
    readonly property var wsPreviewWins: (Hyprland.workspaces.values.find(w => w.id === wsPreviewN)?.toplevels.values ?? [])
    onWsPopHotChanged: wsPopHot ? wsOpenT.restart() : wsCloseT.restart()
    Timer { id: wsOpenT; interval: 180; onTriggered: if (root.wsPopHot) root.wsPreviewOpen = true }
    Timer { id: wsCloseT; interval: 250; onTriggered: if (!root.wsPopHot) { root.wsPreviewOpen = false; root.wsPreviewN = -1; } }
    function wsPeek(it, n) { if (!wsPop.visible || root.wsPreviewN !== n) { const p = it.mapToItem(stage, 0, 0); root.wsPreviewN = n; root.wsPreviewX = p.x + it.width / 2; root.wsPreviewY = p.y + it.height / 2; } }

    PopupWindow {
        id: wsPop
        property real t: root.wsPreviewOpen ? 1 : 0
        Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        visible: t > 0
        anchor.item: stage
        anchor.rect: root.vert
            ? Qt.rect(stage.width + 8, root.wsPreviewY - (wsPop.implicitHeight / Theme.s) / 2, 1, 1)
            : (root.bottom
                ? Qt.rect(root.wsPreviewX - (wsPop.implicitWidth / Theme.s) / 2, -(wsPop.implicitHeight / Theme.s) - 8, 1, 1)
                : Qt.rect(root.wsPreviewX - (wsPop.implicitWidth / Theme.s) / 2, stage.height + 8, 1, 1))
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        implicitWidth: Math.ceil(320 * Theme.s)
        implicitHeight: Math.ceil(wsCard.height * Theme.s)
        color: "transparent"

        Stage {
            Rectangle {
                id: wsCard
                width: 320
                height: wsCol.height + 32
                radius: 20
                color: Theme.bg
                border { width: 1; color: Theme.s2 }
                opacity: wsPop.t
                transform: Translate { x: root.vert ? -12 * (1 - wsPop.t) : 0; y: root.vert ? 0 : (root.bottom ? 12 * (1 - wsPop.t) : -12 * (1 - wsPop.t)) }
                HoverHandler { id: wsPopHov }

                Column {
                    id: wsCol
                    x: 16; y: 16
                    width: parent.width - 32
                    spacing: 8
                    Repeater {
                        model: root.wsPreviewWins
                        Rectangle {
                            required property var modelData
                            width: wsCol.width
                            height: 30
                            radius: 8
                            color: rowHov.hovered ? Theme.s2 : "transparent"
                            readonly property string cls: modelData.lastIpcObject?.class ?? ""
                            readonly property string icon: { const e = DesktopEntries.heuristicLookup(cls); return e?.icon ? Quickshell.iconPath(e.icon, true) : ""; }
                            HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    const tl = parent.modelData;
                                    root.wsPreviewOpen = false;
                                    root.wsPreviewN = -1;
                                    const ws = tl.workspace?.id ?? tl.lastIpcObject?.workspace?.id;
                                    if (ws !== undefined) Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`);
                                    if (tl.activate) tl.activate();
                                    else Hyprland.dispatch(`focuswindow address:${tl.address}`);
                                }
                            }
                            Row {
                                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                spacing: 10
                                Image { anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; visible: status === Image.Ready; source: parent.parent.icon; sourceSize: Qt.size(18, 18); asynchronous: true }
                                Icon { anchors.verticalCenter: parent.verticalCenter; visible: !parent.parent.icon; text: "\u{F003B}"; font.pixelSize: 14; color: Theme.grey }
                                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28; elide: Text.ElideRight; text: (parent.parent.modelData.title || parent.parent.cls || "window"); font { family: Theme.ui; pixelSize: 13 } color: Theme.fg }
                            }
                        }
                    }
                }
            }
        }
    }
}
