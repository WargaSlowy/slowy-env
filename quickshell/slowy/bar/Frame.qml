import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// unified monitor frame with bottom deck emerging from the bezel.
PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "slowy-frame"
    WlrLayershell.layer: deckOpen ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    mask: Region {
        y: root.deckOpen ? 0 : root.height - 2
        width: root.width
        height: root.deckOpen ? root.height : (Theme.state.deckHover && root.deckIds.length > 0 ? 2 : 0)
    }

    readonly property real top: Math.ceil(44 * Theme.s)
    readonly property int b: Math.max(8, Math.round(8 * Theme.s))
    readonly property int r: 18

    property bool deckOpen: false
    property real dt: deckOpen ? 1 : 0
    Behavior on dt { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    readonly property var deckIds: Theme.state.deck.filter(id => Theme.decks.includes(id))
    readonly property int deckH: 232

    Binding { target: Sys; property: "deckOpen"; value: root.deckOpen }
    Binding { target: SysStats; property: "perf"; value: root.deckOpen }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")
    function hm(d) { return Qt.formatTime(d, Theme.state.clock24 ? "hh:mm" : "h:mm ap"); }
    function week(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    property var net: []
    Timer { running: root.deckOpen; interval: 2000; repeat: true; onTriggered: root.net = root.net.concat([[SysStats.rx, SysStats.tx]]).slice(-20) }

    Timer { id: dwell; interval: 150; onTriggered: root.deckOpen = true }
    Timer { id: leave; interval: 300; onTriggered: root.deckOpen = false }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 18
            shadowColor: Qt.alpha("#000000", 0.45)
            shadowBlur: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.bg
                strokeColor: "transparent"
                strokeWidth: 0
                fillRule: ShapePath.OddEvenFill
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: {
                        const w = root.width, h = root.height;
                        const b = root.b, r = root.r, top = root.top;
                        const ir = Math.max(0, r - b);
                        const or_ = r;
                        let p = `M 0 0 L ${w} 0 L ${w} ${h - or_} Q ${w} ${h} ${w - or_} ${h} L ${or_} ${h} Q 0 ${h} 0 ${h - or_} Z`;
                        p += ` M ${b + ir} ${top} L ${w - b - ir} ${top} Q ${w - b} ${top} ${w - b} ${top + ir}`;
                        p += ` L ${w - b} ${h - b - ir} Q ${w - b} ${h - b} ${w - b - ir} ${h - b}`;
                        p += ` L ${b + ir} ${h - b} Q ${b} ${h - b} ${b} ${h - b - ir}`;
                        p += ` L ${b} ${top + ir} Q ${b} ${top} ${b + ir} ${top} Z`;
                        return p;
                    }
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.s2
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.FlatCap
                PathSvg {
                    path: {
                        const w = root.width, h = root.height;
                        const b = root.b, r = root.r, top = root.top;
                        const ir = Math.max(0, r - b);
                        return `M ${b} ${top + ir} Q ${b} ${top} ${b + ir} ${top} L ${w - b - ir} ${top} Q ${w - b} ${top} ${w - b} ${top + ir} L ${w - b} ${h - b - ir} Q ${w - b} ${h - b} ${w - b - ir} ${h - b} L ${b + ir} ${h - b} Q ${b} ${h - b} ${b} ${h - b - ir} Z`;
                    }
                }
            }
        }
    }

    Stage {
        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    leave.stop();
                    if (!root.deckOpen && Theme.state.deckHover) dwell.restart();
                } else {
                    dwell.stop();
                    if (root.deckOpen) leave.restart();
                }
            }
        }

        Item {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.height / Theme.s) - panel.height + (1 - root.dt) * (panel.height - panel.fb)
            width: row.width + 52
            height: root.deckH + 52
            opacity: root.dt
            scale: 0.96 + 0.04 * root.dt
            transformOrigin: Item.Bottom
            readonly property int fb: Math.max(8, Math.round(8 * Theme.s))

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: Theme.bg
                    strokeColor: "transparent"
                    strokeWidth: 0
                    joinStyle: ShapePath.RoundJoin
                    PathSvg {
                        path: {
                            const w = panel.width, h = panel.height, r = 40;
                            return `M 0 ${h} L 0 ${r} Q 0 0 ${r} 0 L ${w - r} 0 Q ${w} 0 ${w} ${r} L ${w} ${h} Z`;
                        }
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Theme.s2
                    strokeWidth: 1
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.FlatCap
                    PathSvg {
                        path: {
                            const w = panel.width, h = panel.height, r = 40, b = panel.fb;
                            return `M 0 ${h - b} L 0 ${r} Q 0 0 ${r} 0 L ${w - r} 0 Q ${w} 0 ${w} ${r} L ${w} ${h - b}`;
                        }
                    }
                }
            }

            Row {
                id: row
                x: 26
                y: 26
                spacing: 16
                Repeater {
                    model: root.deckIds
                    Row {
                        id: cell
                        required property string modelData
                        required property int index
                        spacing: 16
                        Image {
                            visible: cell.index > 0
                            width: 4
                            height: root.deckH
                            fillMode: Image.TileVertically
                            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="4" height="10"><circle cx="2" cy="5" r="1.5" fill="#${Theme.hex(Theme.s3)}"/></svg>`)
                        }
                        Loader { sourceComponent: ({ clock: clockC, weather: weatherC, perf: perfC, net: netC, media: mediaC })[cell.modelData] }
                    }
                }
            }
        }
    }

    component Gauge: Column {
        id: g
        property real f
        property bool on
        property string label
        spacing: 8
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88
            height: 88
            Ring { anchors.fill: parent; n: 32; dot: 4; f: g.on ? g.f : 0 }
            Num { anchors.centerIn: parent; text: Math.round(g.f * 100); font.pixelSize: 30 }
        }
        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: g.label; px: 10 }
    }
    component Speed: Row {
        id: sp
        property string icon
        property real b
        readonly property var v: SysStats.rate(b).split(" ")
        spacing: 8
        Icon { anchors.verticalCenter: parent.verticalCenter; text: sp.icon; font.pixelSize: 18 }
        Num { anchors.verticalCenter: parent.verticalCenter; text: sp.v[0]; font.pixelSize: 44 }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: sp.v[1]; px: 11 }
    }
    component DeckMeta: Row {
        id: m
        property string icon
        property string text
        spacing: 8
        Icon { anchors.verticalCenter: parent.verticalCenter; text: m.icon; font.pixelSize: 16 }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: m.text; px: 11 }
    }

    Component {
        id: clockC
        Column {
            width: 216
            Lb { text: root.en.dayName(clock.date.getDay()) + (Theme.state.clock24 ? "" : clock.date.getHours() < 12 ? " · am" : " · pm") }
            Num {
                topPadding: lead + 10
                text: Theme.state.clock24 ? Qt.formatTime(clock.date, "hh:mm") : (clock.date.getHours() % 12 || 12) + Qt.formatTime(clock.date, ":mm")
                font.pixelSize: 72
            }
            Lb { topPadding: 12; text: `${root.en.toString(clock.date, "d MMMM")} · week ${root.week(clock.date)}` }
            Item { width: 1; height: 24 }
            Seg { width: parent.width; height: 6; n: 24; f: Weather.sun ? (clock.date - Weather.sun.rise) / (Weather.sun.set - Weather.sun.rise) : 0 }
            Item {
                width: parent.width
                height: 28
                DeckMeta { y: 12; icon: "\u{F059C}"; text: Weather.sun ? root.hm(Weather.sun.rise) : "--:--" }
                DeckMeta { y: 12; anchors.right: parent.right; icon: "\u{F059B}"; text: Weather.sun ? root.hm(Weather.sun.set) : "--:--" }
            }
        }
    }

    Component {
        id: weatherC
        Column {
            width: 188
            Lb { width: parent.width; elide: Text.ElideRight; text: Weather.ok ? Weather.name(Weather.now.code) : "no sky" }
            Item { width: 1; height: 10 }
            Row {
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.slowy(Weather.now?.code ?? 3, Weather.now?.day)
                    font.pixelSize: 48
                    layer.enabled: true
                    layer.effect: Dm { step: 3 }
                }
                Num { anchors.verticalCenter: parent.verticalCenter; text: Weather.ok ? Math.round(Weather.now.temp) + "°" : "--"; font.pixelSize: 54 }
            }
            Lb { topPadding: 8; visible: Weather.ok; text: `feels ${Math.round(Weather.now?.feels)}° · ${Math.round(Weather.now?.wind)} m/s`; px: 11 }
            Item { width: 1; height: 18 }
            Row {
                spacing: 8
                Repeater {
                    model: Weather.days.slice(1, 5)
                    Column {
                        required property var modelData
                        required property int index
                        width: 41
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: root.en.dayName((clock.date.getDay() + index + 1) % 7, Locale.ShortFormat); px: 10 }
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 6; text: Weather.slowy(modelData.code, true); font.pixelSize: 24; layer.enabled: true; layer.effect: Dm { step: 2 } }
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 6; text: Math.round(modelData.max) + "°"; px: 11; color: Theme.fg }
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.min) + "°"; px: 11 }
                    }
                }
            }
        }
    }

    Component {
        id: perfC
        Column {
            width: 300
            Row {
                spacing: 18
                Gauge { on: root.deckOpen; f: SysStats.cpu; label: `cpu · ${Math.round(SysStats.cpuTemp)}°` }
                Gauge { on: root.deckOpen; f: SysStats.mem; label: `mem · ${SysStats.memUsed.toFixed(1)}g` }
                Gauge { on: root.deckOpen; f: SysStats.gpu; label: `gpu · ${Math.round(SysStats.gpuTemp)}°` }
            }
            Item { width: 1; height: 18 }
            Row {
                spacing: 14
                Column {
                    width: 160
                    spacing: 4
                    Lb { bottomPadding: 2; text: "processes"; px: 10 }
                    Repeater {
                        model: SysStats.procs
                        Row {
                            required property var modelData
                            spacing: 6
                            Lb { width: 78; elide: Text.ElideRight; text: modelData[0]; px: 10; color: Theme.fg }
                            Lb { width: 34; horizontalAlignment: Text.AlignRight; text: Math.round(modelData[1]) + "%"; px: 10 }
                            Seg { anchors.verticalCenter: parent.verticalCenter; width: 36; height: 5; n: 6; spacing: 3; f: modelData[1] / 100 }
                        }
                    }
                }
                Column {
                    width: 126
                    spacing: 6
                    Lb { text: `cores · ${SysStats.cpuFreq.toFixed(1)} ghz`; px: 10 }
                    Grid {
                        id: cores
                        readonly property int n: Math.max(1, SysStats.cores.length)
                        readonly property real d: (width - (n - 1) * spacing) / n
                        width: parent.width
                        columns: n
                        spacing: 3
                        Repeater {
                            model: cores.n * 8
                            Rectangle {
                                required property int index
                                readonly property int up: 8 - Math.floor(index / cores.n)
                                readonly property int lvl: Math.round(1 + 7 * (SysStats.cores[index % cores.n] ?? 0))
                                width: cores.d
                                height: cores.d
                                radius: cores.d / 2
                                color: up === lvl ? Theme.fg : up < lvl ? Theme.grey : Theme.s2
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: netC
        Column {
            width: 176
            Lb { width: parent.width; elide: Text.ElideRight; text: "net · " + (SysStats.iface || "offline") }
            Item { width: 1; height: 10 }
            Speed { icon: "\u{F0045}"; b: SysStats.rx }
            Item { width: 1; height: 8 }
            Speed { icon: "\u{F005D}"; b: SysStats.tx }
            Item { width: 1; height: 18 }
            Grid {
                id: hist
                readonly property real peak: Math.max(10240, ...root.net.map(p => Math.max(p[0], p[1])))
                readonly property real d: (width - 19 * spacing) / 20
                width: parent.width
                columns: 20
                spacing: 3
                Repeater {
                    model: 20 * 10
                    Rectangle {
                        required property int index
                        readonly property int r: Math.floor(index / 20)
                        readonly property bool tx: r >= 5
                        readonly property var p: root.net[index % 20 - 20 + root.net.length] ?? [0, 0]
                        readonly property bool lit: (tx ? r - 4 : 5 - r) <= Math.ceil(5 * (tx ? p[1] : p[0]) / hist.peak)
                        width: hist.d
                        height: hist.d
                        radius: hist.d / 2
                        color: lit ? (tx ? Theme.grey : Theme.fg) : Theme.s2
                    }
                }
            }
        }
    }

    Component {
        id: mediaC
        Column {
            width: 240
            Lb { width: parent.width; elide: Text.ElideRight; text: Media.player?.identity ?? "silence" }
            Item { width: 1; height: 12 }
            Row {
                spacing: 14
                Item {
                    id: art
                    width: 84
                    height: 84
                    property real turn: 0
                    Timer { running: root.deckOpen && Media.playing; interval: 33; repeat: true; onTriggered: art.turn = (art.turn + 360 / 14 / 30) % 360 }
                    Art { anchors.fill: parent; rotation: art.turn; url: Media.player?.trackArtUrl ?? ""; step: 5 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 142
                    Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; text: Media.player?.trackTitle || "Nothing on"; font { family: Theme.ui; pixelSize: 17; weight: Font.DemiBold } color: Theme.fg }
                    Text { width: parent.width; elide: Text.ElideRight; text: Media.player?.trackArtist ?? ""; font { family: Theme.ui; pixelSize: 13 } color: Theme.grey }
                }
            }
            Item { width: 1; height: 16 }
            Seg { width: parent.width; height: 6; n: 20; f: Media.player?.lengthSupported && Media.player.length > 0 ? Media.position / Media.player.length : 0 }
            Item {
                width: parent.width
                height: 26
                visible: !!Media.player
                Lb { y: 8; text: Media.time(Media.position); px: 11 }
                Lb { y: 8; anchors.right: parent.right; visible: !!Media.player?.lengthSupported; text: Media.time(Media.player?.length); px: 11 }
            }
            Item { width: 1; height: 8 }
            Controls { anchors.horizontalCenter: parent.horizontalCenter; size: 20; play: 48 }
        }
    }

}
