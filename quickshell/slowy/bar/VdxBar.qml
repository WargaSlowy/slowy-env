import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.settings

// vdx-style bar and island in one top surface. The pill, hub and motion follow
// https://github.com/diominvd/vdx (MIT); the content is Slowy's own: workspaces,
// tray, clock, player, calendar and notifications.
PanelWindow {
    id: root

    signal trayClicked
    signal powerClicked

    // top/left/right only: with bottom anchored Hyprland ignores the exclusive zone and windows sit under the pill
    anchors { top: true; left: true; right: true }
    implicitHeight: screen?.height ?? 1080
    visible: Theme.state.barStyle === "vdx"
    color: "transparent"
    WlrLayershell.namespace: "slowy-vdx-bar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // the pill geometry is in the same unscaled px, so the reservation must match it exactly
    exclusiveZone: 8 + Theme.state.pillHeight + Theme.state.topGap

    // only the pill and, while open, the scrim take input; the rest of the window is see-through
    mask: Region {
        item: shape
        Region { item: scrim.visible ? scrim : null }
    }

    property bool expanded: false
    property bool calendarPage: false
    property bool notesPage: false
    readonly property int active: Hyprland.focusedWorkspace?.id ?? 0
    readonly property int count: Math.min(10, Math.max(6, active, ...Hyprland.workspaces.values.filter(w => w.toplevels.values.length).map(w => w.id)))
    readonly property var bat: UPower.displayDevice
    readonly property bool batWarn30: UPower.onBattery && bat.percentage <= 0.30
    onBatWarn30Changed: if (batWarn30) Quickshell.execDetached(["notify-send", "-u", "normal", "-i", "battery-caution", "Battery Low", "Baterai tersisa " + Math.round(bat.percentage * 100) + "%"])
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var net: wifi?.networks.values.find(n => n.connected) ?? null

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property int year: clock.date.getFullYear()
    readonly property int month: clock.date.getMonth()
    readonly property int first: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int days: new Date(year, month + 1, 0).getDate()
    readonly property int weeks: Math.ceil((root.first + root.days) / 7)
    readonly property string date: clock.date.toLocaleDateString(Qt.locale("en_US"), Locale.LongFormat)
    readonly property string userName: Theme.state.name || Quickshell.env("USER") || "User"
    readonly property string userInitial: root.userName.slice(0, 1).toUpperCase()
    readonly property date weekMonday: {
        const d = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate());
        d.setDate(d.getDate() - (d.getDay() + 6) % 7);
        return d;
    }
    property date shownMonth: new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
    readonly property int shownFirst: (root.shownMonth.getDay() + 6) % 7
    readonly property int shownDays: new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth() + 1, 0).getDate()
    readonly property int shownWeeks: Math.ceil((root.shownFirst + root.shownDays) / 7)

    function go(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`) }
    function todayMonth() { root.shownMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1) }
    function shiftMonth(by) { root.shownMonth = new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth() + by, 1) }
    function openCalendar() { root.todayMonth(); root.calendarPage = true; root.notesPage = false }
    function openNotes() { root.calendarPage = false; root.notesPage = true; root.expanded = true }
    function toggle() {
        root.expanded = !root.expanded;
        if (root.expanded) { root.todayMonth(); root.notesPage = false; }
        else { root.calendarPage = false; root.notesPage = false; }
    }
    function close() { root.expanded = false; root.calendarPage = false; root.notesPage = false }

    Rectangle {
        id: scrim
        anchors.fill: parent
        visible: root.expanded
        color: Theme.scrim
        opacity: 0.55
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
        id: shape
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: root.expanded ? Theme.state.hubWidth : Math.max(110, compact.implicitWidth + 28)
        height: root.expanded ? Math.min(hubRoot.implicitHeight + 24, (screen?.height ?? 1080) - 32) : Theme.state.pillHeight
        radius: root.expanded ? Math.min(Theme.state.barRadius * 1.5, width / 2) : Math.min(Theme.state.barRadius, Theme.state.pillHeight / 2)
        color: Theme.bg
        border { width: Theme.state.barBorder; color: Theme.s3 }
        clip: true
        scale: !root.expanded && hover.hovered ? 1.02 : 1
        focus: root.expanded

        // growing settles with vdx's small overshoot; folding back is a plain ease
        Behavior on width {
            NumberAnimation { duration: 320; easing.type: root.expanded ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.1 }
        }
        Behavior on height {
            NumberAnimation { duration: 320; easing.type: root.expanded ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.1 }
        }
        Behavior on radius { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        HoverHandler { id: hover }

        Keys.onPressed: e => {
            if (e.key !== Qt.Key_Escape) return;
            if (root.notesPage) root.notesPage = false;
            else if (root.calendarPage) root.calendarPage = false;
            else root.close();
            e.accepted = true;
        }

        // the resting island: the workspace cluster and the clock, each a
        // tonal tile one step above the bar's background
        Row {
            id: compact
            anchors.centerIn: parent
            height: Theme.state.pillHeight
            spacing: 12
            visible: !root.expanded

            Rectangle {
                id: wsTile
                anchors.verticalCenter: parent.verticalCenter
                width: ws.implicitWidth + 20
                height: Theme.state.pillHeight - 8
                radius: Math.min(Theme.state.barRadius, height / 2)
                color: Theme.s2

                Row {
                    id: ws
                    anchors.centerIn: parent
                    spacing: 5
                    Repeater {
                        model: root.count
                        Item {
                            id: wsItem
                            required property int index
                            readonly property int n: index + 1
                            readonly property bool occ: (Hyprland.workspaces.values.find(w => w.id === n)?.toplevels.values.length ?? 0) > 0
                            readonly property bool on: root.active === n
                            readonly property bool nums: Theme.state.barWs === "number"
                            anchors.verticalCenter: parent.verticalCenter
                            width: nums ? 20 : (on ? 24 : 8)
                            height: nums ? 20 : 8

                            Rectangle {
                                anchors.fill: parent
                                radius: nums ? 10 : 4
                                color: wsItem.nums
                                    ? (wsItem.on ? Theme.fade(Theme.fg, 0.22) : Theme.fade(Theme.fg, wsItem.occ ? 0.12 : 0.06))
                                    : (wsItem.on ? Theme.fg : Theme.fade(Theme.fg, wsItem.occ ? 0.65 : 0.22))
                                Behavior on color { ColorAnimation { duration: Theme.t } }
                            }
                            Behavior on width { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

                            Lb {
                                id: wsLbl
                                visible: wsItem.nums
                                anchors.centerIn: parent
                                family: Theme.state.barFont
                                text: wsItem.n
                                px: 9
                                color: wsItem.on ? Theme.fg : wsItem.occ ? Theme.fade(Theme.fg, 0.8) : Theme.fade(Theme.fg, 0.45)
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.go(wsItem.n) }
                        }
                    }
                }
            }

            Rectangle {
                id: clockTile
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.state.showClock ? clockText.implicitWidth + 20 : 24
                height: Theme.state.pillHeight - 8
                radius: Math.min(Theme.state.barRadius, height / 2)
                color: Theme.s2

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    // a dot keeps the hub reachable when the clock is hidden, as vdx's island still has a face
                    text: Theme.state.showClock ? Theme.hh(clock.date) + ":" + String(clock.date.getMinutes()).padStart(2, "0") + (Theme.state.clock24 ? "" : clock.date.getHours() < 12 ? " AM" : " PM") : "·"
                    font { family: Theme.ui; pixelSize: 13; weight: Font.Bold }
                    color: Theme.fg
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle() }
            }

            // the current track sits bare after the clock, with no tile behind it
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Media.playing
                text: {
                    const title = Media.player?.trackTitle ?? "";
                    const artist = Media.player?.trackArtist ?? "";
                    return artist ? `${title} · ${artist}` : title;
                }
                width: Math.min(implicitWidth, 150)
                elide: Text.ElideRight
                font { family: Theme.ui; pixelSize: 11; weight: Font.Medium }
                color: Theme.fg
            }

            // the two status faces sit on the bar itself, with no tile behind them
            Row {
                id: statusIcons
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: root.parts.notes
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.trayClicked() }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: root.openNotes()
                    }
                }
                // the newest notification's summary sits right after the bell; its width grows the bar
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notes.list.length > 0
                    text: {
                        const s = Notes.list[Notes.list.length - 1]?.summary ?? "";
                        return s.length > 10 ? s.slice(0, 10) + "..." : s;
                    }
                    font { family: Theme.ui; pixelSize: 12; weight: Font.Medium }
                    color: Theme.fg
                }
                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: root.parts.sound
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.trayClicked() }
                }
                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: root.parts.wifi
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.trayClicked() }
                }
            }
        }

        // the open island: vdx's hub blocks, Slowy's own content
        Column {
            id: hubRoot
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 12 }
            width: parent.width - 24
            spacing: 8
            opacity: root.expanded ? 1 : 0
            visible: opacity > 0
            scale: root.expanded ? 1 : 0.94
            transformOrigin: Item.Top
            transform: Translate {
                y: root.expanded ? 0 : -8
                Behavior on y {
                    SequentialAnimation {
                        PauseAnimation { duration: root.expanded ? 30 : 0 }
                        NumberAnimation { duration: 320; easing.type: root.expanded ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.1 }
                    }
                }
            }

            // the shape grows first, then the hub settles in
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.expanded ? 30 : 0 }
                    NumberAnimation { duration: 320; easing.type: root.expanded ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.1 }
                }
            }
            Behavior on scale {
                SequentialAnimation {
                    PauseAnimation { duration: root.expanded ? 30 : 0 }
                    NumberAnimation { duration: 320; easing.type: root.expanded ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.1 }
                }
            }

            // the main page: all hub blocks except the month, which swaps in on a week click
            Column {
                id: hubMain
                width: parent.width
                spacing: 8
                visible: !root.calendarPage && !root.notesPage
                height: visible ? implicitHeight : 0

                // vdx's header: identity on the left, the two settings doors on the right
                Item {
                    id: hubHeader
                    width: parent.width
                    height: 34
                    Rectangle {
                        id: avatar
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        width: 34
                        height: 34
                        radius: 6
                        color: Theme.s2
                        Lb { family: Theme.state.barFont; anchors.centerIn: parent; px: 14; color: Theme.fg; text: root.userInitial }
                    }
                    Column {
                        anchors { left: avatar.right; leftMargin: 8; right: headActions.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Lb { family: Theme.state.barFont; width: parent.width; elide: Text.ElideRight; px: 10; color: Theme.fg; text: root.userName }
                        Lb { family: Theme.state.barFont; width: parent.width; elide: Text.ElideRight; px: 8; color: Theme.grey; text: root.date }
                    }
                    Row {
                        id: headActions
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 6
                            color: Theme.s2
                            Icon { anchors.centerIn: parent; text: "\u{F0493}"; font.pixelSize: 14; color: Theme.grey }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.trayClicked() }
                        }
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 6
                            color: Theme.s2
                            Icon { anchors.centerIn: parent; text: "\u{F0425}"; font.pixelSize: 14; color: Theme.grey }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.powerClicked() }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 6

                    Lb { family: Theme.state.barFont;
                        id: dateCaption
                        px: 9
                        color: Theme.grey
                        text: root.date
                    }
                    Rectangle {
                        id: hubNoticeDot
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Theme.state.noticeDot && Notes.list.length > 0
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.red
                    }
                }

                // the week strip: vdx's seven pills, today filled; a click opens the month
                Rectangle {
                    id: weekStrip
                    width: parent.width
                    height: 52
                    radius: 6
                    color: Theme.s1
                    Row {
                        anchors { fill: parent; margins: 6 }
                        spacing: 2
                        Repeater {
                            model: 7
                            Rectangle {
                                id: dayCell
                                required property int index
                                readonly property date day: new Date(root.weekMonday.getFullYear(), root.weekMonday.getMonth(), root.weekMonday.getDate() + index)
                                readonly property bool today: index === (clock.date.getDay() + 6) % 7
                                width: (weekStrip.width - 24) / 7
                                height: parent.height
                                radius: 6
                                color: dayCell.today ? Theme.s2 : "transparent"
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Lb { family: Theme.state.barFont;
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        px: 8
                                        color: dayCell.today ? Theme.fg : Theme.grey
                                        text: "MTWTFSS".charAt(index)
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: dayCell.day.getDate()
                                        font { family: Theme.ui; pixelSize: 12; weight: dayCell.today ? Font.Bold : Font.Normal }
                                        color: dayCell.today ? Theme.fg : Theme.mute
                                    }
                                }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openCalendar() }
                }

                // the player: cover tile, track, one filled play button between the skips
                Rectangle {
                    id: playerCard
                    width: parent.width
                    height: Theme.state.hubPlayer ? 56 : 0
                    visible: Theme.state.hubPlayer
                    radius: 6
                    color: Theme.s1
                    Row {
                        anchors { fill: parent; margins: 8 }
                        spacing: 8
                        Rectangle {
                            width: 40
                            height: 40
                            radius: 6
                            color: Theme.s2
                            clip: true
                            Art { anchors.fill: parent; url: Media.player?.trackArtUrl ?? ""; step: 5 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 56 - 92
                            spacing: 2
                            Lb { family: Theme.state.barFont;
                                width: parent.width
                                elide: Text.ElideRight
                                px: 9
                                font.weight: Font.Bold
                                color: Theme.fg
                                text: Media.player ? (Media.player.trackTitle || "no track") : "no player"
                            }
                            Lb { family: Theme.state.barFont;
                                width: parent.width
                                elide: Text.ElideRight
                                px: 8
                                color: Theme.grey
                                text: Media.player ? ((Media.player.trackArtist ? Media.player.trackArtist + " · " : "") + Media.time(Media.position) + " / " + Media.time(Media.player.length ?? 0)) : ""
                            }
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "‹"
                                font { family: Theme.ui; pixelSize: 20 }
                                color: Theme.grey
                                MouseArea { anchors.fill: parent; onClicked: Media.player?.previous() }
                            }
                            Rectangle {
                                id: playPad
                                width: 32
                                height: 32
                                radius: 16
                                color: Theme.fg
                                Text {
                                    anchors.centerIn: parent
                                    text: Media.playing ? "❚❚" : "▶"
                                    font { family: Theme.ui; pixelSize: 12 }
                                    color: Theme.ink
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            const p = Media.player;
                                            if (!p) return;
                                            if (Media.playing && p.canPause) p.pause();
                                            else if (p.canPlay) p.play();
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                font { family: Theme.ui; pixelSize: 20 }
                                color: Theme.grey
                                MouseArea { anchors.fill: parent; onClicked: Media.player?.next() }
                            }
                        }
                    }
                }

                // vdx's quick sliders: one section, a row of icon, track and value each
                Rectangle {
                    id: sliderSection
                    width: parent.width
                    height: Sys.hasBri ? 84 : 46
                    radius: 6
                    color: Theme.s1
                    Column {
                        anchors { fill: parent; margins: 10 }
                        spacing: 8
                        Row {
                            id: volRow
                            width: parent.width
                            spacing: 8
                            Icon { anchors.verticalCenter: parent.verticalCenter; width: 20; horizontalAlignment: Text.AlignHCenter; text: "\u{F057E}"; font.pixelSize: 14; color: Theme.grey }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 76
                                height: 6
                                radius: 3
                                color: Theme.s2
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: parent.width * Sys.vol
                                    radius: 3
                                    color: Theme.fg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: e => Sys.setVol(Math.max(0, Math.min(1, e.x / parent.width)))
                                    onPositionChanged: e => { if (pressed) Sys.setVol(Math.max(0, Math.min(1, e.x / parent.width))) }
                                }
                                WheelHandler { onWheel: e => Sys.setVol(Sys.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
                            }
                            Lb { family: Theme.state.barFont; anchors.verticalCenter: parent.verticalCenter; width: 40; horizontalAlignment: Text.AlignRight; px: 9; color: Theme.grey; text: Math.round(Sys.vol * 100) + "%" }
                        }
                        Row {
                            id: briRow
                            visible: Sys.hasBri
                            width: parent.width
                            spacing: 8
                            Icon { anchors.verticalCenter: parent.verticalCenter; width: 20; horizontalAlignment: Text.AlignHCenter; text: "\u{F0597}"; font.pixelSize: 14; color: Theme.grey }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 76
                                height: 6
                                radius: 3
                                color: Theme.s2
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: parent.width * Sys.bri
                                    radius: 3
                                    color: Theme.fg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: e => Sys.setBri(Math.max(0, Math.min(1, e.x / parent.width)))
                                    onPositionChanged: e => { if (pressed) Sys.setBri(Math.max(0, Math.min(1, e.x / parent.width))) }
                                }
                                WheelHandler { onWheel: e => Sys.setBri(Sys.bri + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
                            }
                            Lb { family: Theme.state.barFont; anchors.verticalCenter: parent.verticalCenter; width: 40; horizontalAlignment: Text.AlignRight; px: 9; color: Theme.grey; text: Math.round(Sys.bri * 100) + "%" }
                        }
                    }
                }

                // the tray as vdx's chips: each tile holds the module's own face
                Grid {
                    id: chipGrid
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 4
                    spacing: 6
                    readonly property int chipHeight: 32
                    Repeater {
                        model: Theme.state.bar.filter(m => m !== "sound" && m !== "wifi")
                        Rectangle {
                            id: chip
                            required property string modelData
                            width: (hubRoot.width - 18) / 4
                            height: chipGrid.chipHeight
                            radius: 6
                            color: Theme.s2
                            Column {
                                anchors.centerIn: parent
                                spacing: 0
                                Loader { anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: root.parts[chip.modelData] ?? null }
                                Lb { family: Theme.state.barFont; anchors.horizontalCenter: parent.horizontalCenter; px: 7; color: Theme.grey; text: chip.modelData }
                            }
                            TapHandler { onTapped: chip.modelData === "power" ? root.powerClicked() : root.trayClicked() }
                        }
                    }
                }

                Repeater {
                    model: Notes.list.slice(-2).reverse()
                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 28
                        radius: 6
                        color: Theme.s2
                        Lb { family: Theme.state.barFont;
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            width: parent.width - 24
                            elide: Text.ElideRight
                            px: 9
                            color: Theme.grey
                            text: parent.modelData.summary ?? ""
                        }
                        TapHandler { onTapped: parent.modelData.dismiss() }
                    }
                }
            }

            // the notification page: every active notification, newest first, opened by a right click on the bell
            Column {
                id: notesPageItem
                width: parent.width
                height: visible ? implicitHeight : 0
                visible: root.notesPage
                spacing: 6

                Item {
                    width: parent.width
                    height: 32
                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Lb { family: Theme.state.barFont;
                            px: 12
                            color: Theme.grey
                            text: "‹"
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.notesPage = false }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "notifications"
                            font { family: Theme.ui; pixelSize: 15; weight: Font.Bold }
                            color: Theme.fg
                        }
                        Lb { family: Theme.state.barFont; anchors.verticalCenter: parent.verticalCenter; px: 10; color: Theme.grey; text: `· ${Notes.list.length}` }
                    }
                    Lb { family: Theme.state.barFont;
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
                        px: 9
                        color: Theme.fg
                        visible: Notes.list.length > 0
                        text: "clear all"
                        TapHandler { onTapped: Notes.clear() }
                    }
                }

                ListView {
                    width: parent.width
                    height: Math.min(contentHeight, (screen?.height ?? 1080) - 140)
                    clip: true
                    spacing: 6
                    model: Notes.list.slice().reverse()
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        required property var modelData
                        readonly property var n: modelData
                        width: ListView.view.width
                        height: cardBody.height + 20
                        radius: 6
                        color: Theme.s2
                        Column {
                            id: cardBody
                            anchors { left: parent.left; right: parent.right; margins: 10 }
                            spacing: 2
                            Lb { family: Theme.state.barFont;
                                width: parent.width
                                elide: Text.ElideRight
                                px: 8
                                color: Theme.grey
                                text: `${n.appName || "app"} · ${Notes.ago(n, clock.date.getTime())}`
                            }
                            Lb { family: Theme.state.barFont;
                                width: parent.width
                                elide: Text.ElideRight
                                px: 10
                                color: Theme.fg
                                text: n.summary ?? ""
                            }
                            Text {
                                width: parent.width
                                visible: !!n.body
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: n.body ?? ""
                                font { family: Theme.ui; pixelSize: 10 }
                                color: Theme.grey
                            }
                        }
                        TapHandler { onTapped: n.dismiss() }
                    }
                }

                Lb { family: Theme.state.barFont;
                    width: parent.width
                    visible: Notes.list.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    px: 10
                    color: Theme.grey
                    text: "no notifications"
                }
            }

            // the month as a hub page: head, then a card of weekday heads and days
            Column {
                id: monthPage
                width: parent.width
                height: visible ? implicitHeight : 0
                visible: root.calendarPage
                spacing: 6

                Item {
                    id: monthHead
                    width: parent.width
                    height: 32
                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Lb { family: Theme.state.barFont;
                            anchors.verticalCenter: parent.verticalCenter
                            px: 12
                            color: Theme.grey
                            text: "‹"
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.calendarPage = false }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDate(root.shownMonth, "MMMM")
                            font { family: Theme.ui; pixelSize: 15; weight: Font.Bold }
                            color: Theme.fg
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDate(root.shownMonth, "yyyy")
                            font { family: Theme.ui; pixelSize: 13 }
                            color: Theme.grey
                        }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Rectangle {
                            width: 52
                            height: 24
                            radius: 12
                            color: Theme.s2
                            Lb { family: Theme.state.barFont; anchors.centerIn: parent; px: 8; color: Theme.fg; text: "Today" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.todayMonth() }
                        }
                        Lb { family: Theme.state.barFont;
                            anchors.verticalCenter: parent.verticalCenter
                            px: 12
                            color: Theme.grey
                            text: "‹"
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.shiftMonth(-1) }
                        }
                        Lb { family: Theme.state.barFont;
                            anchors.verticalCenter: parent.verticalCenter
                            px: 12
                            color: Theme.grey
                            text: "›"
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.shiftMonth(1) }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    Repeater {
                        model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                        Lb { family: Theme.state.barFont;
                            required property string modelData
                            width: (monthPage.width - 12) / 7
                            horizontalAlignment: Text.AlignHCenter
                            px: 9
                            color: Theme.mute
                            text: modelData
                        }
                    }
                }

                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 7
                    rows: root.shownWeeks
                    spacing: 2
                    Repeater {
                        model: root.shownFirst + root.shownDays
                        Rectangle {
                            required property int index
                            readonly property bool isToday: root.shownMonth.getFullYear() === clock.date.getFullYear() && root.shownMonth.getMonth() === clock.date.getMonth() && index - root.shownFirst + 1 === clock.date.getDate()
                            width: (monthPage.width - 12) / 7
                            height: 26
                            radius: 6
                            color: isToday ? Theme.s2 : "transparent"
                            Text {
                                anchors.centerIn: parent
                                visible: index >= root.shownFirst
                                text: index >= root.shownFirst ? index - root.shownFirst + 1 : ""
                                font { family: Theme.ui; pixelSize: 11 }
                                color: parent.isToday ? Theme.fg : Theme.grey
                            }
                        }
                    }
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => root.go(e.angleDelta.y > 0 ? "-1" : "+1")
    }

    readonly property var parts: ({
        layout: layoutC, wifi: wifiC, bluetooth: btC, sound: soundC,
        notes: notesC, battery: batC, mode: modeC, power: powerC
    })
    Component { id: layoutC; Lb { family: Theme.state.barFont; text: Sys.layout; px: 9; color: Theme.grey } }
    Component {
        id: wifiC
        Item {
            implicitWidth: wp.implicitWidth + 8
            implicitHeight: wp.implicitHeight
            Rectangle {
                id: wp
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
                    width: 26
                    radius: 13
                    topRightRadius: 0
                    bottomRightRadius: 0
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
    }
    Component {
        id: btC
        Icon {
            text: Bluetooth.defaultAdapter?.enabled ? "\u{F00AF}" : "\u{F00B2}"
            font.pixelSize: 14 + Theme.state.barIconGrow
            color: Bluetooth.devices.values.some(d => d.connected) ? Theme.fg : Theme.grey
        }
    }
    Component {
        id: soundC
        Item {
            id: vpill
            implicitWidth: sp.implicitWidth + 8
            implicitHeight: sp.implicitHeight
            width: implicitWidth
            height: implicitHeight
            property bool hot: false
            HoverHandler { onHoveredChanged: vpill.hot = hovered }
            Rectangle {
                id: sp
                anchors.centerIn: parent
                readonly property string label: Sys.muted ? "Mute" : Math.round(Sys.vol * 100) + "%"
                implicitWidth: sIcon.width + (vpill.hot ? 72 : Math.min(sName.implicitWidth, 52)) + 18
                implicitHeight: 26
                radius: 13
                color: Theme.s2
                clip: true
                Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: sIcon
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 26
                    radius: 13
                    topRightRadius: 0
                    bottomRightRadius: 0
                    color: "#67b0e8"
                    Icon { anchors.centerIn: parent; text: Sys.muted ? "\u{F075F}" : "\u{F057E}"; font.pixelSize: 13; color: Theme.bg }
                }

                Text {
                    id: sName
                    anchors { left: sIcon.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: sp.label
                    font { family: Theme.ui; pixelSize: 12; weight: Font.Medium }
                    color: Theme.fg
                    opacity: vpill.hot ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                Rectangle {
                    anchors { left: sIcon.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    height: 6
                    radius: 3
                    color: Theme.s3
                    opacity: vpill.hot ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Sys.vol))
                        height: parent.height
                        radius: 3
                        color: Sys.muted ? Theme.grey : "#67b0e8"
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }
                }
            }
            WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: e => Sys.setVol(Sys.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
        }
    }
    Component {
        id: notesC
        Icon {
            text: Theme.state.dnd ? "\u{F009B}" : "\u{F009A}"
            font.pixelSize: 14 + Theme.state.barIconGrow
            color: Notes.list.length ? Theme.fg : Theme.grey
        }
    }
    Component {
        id: batC
        Row {
            spacing: 4
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 4
                color: !UPower.onBattery ? Theme.green : Theme.s3
                Icon { anchors.centerIn: parent; text: "\u{F140B}"; font.pixelSize: 11; color: !UPower.onBattery ? Theme.bg : Theme.fg }
            }
            Lb { family: Theme.state.barFont;
                anchors.verticalCenter: parent.verticalCenter
                px: 9
                color: UPower.onBattery && root.bat.percentage < 0.15 ? Theme.red : Theme.grey
                text: Math.round(root.bat.percentage * 100) + "%"
            }
        }
    }
    Component {
        id: modeC
        Row {
            spacing: 2
            Repeater {
                model: Rules.modeCount
                Rectangle {
                    required property int index
                    width: 3
                    height: 5 + index * 3
                    radius: 1.5
                    color: index <= Rules.mode ? Theme.fg : Theme.s3
                }
            }
        }
    }
    Component {
        id: powerC
        Icon { text: "\u{F0425}"; font.pixelSize: 14 + Theme.state.barIconGrow; color: Theme.grey }
    }
}
