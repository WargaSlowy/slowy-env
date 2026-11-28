import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// launcher: tap Super or Super+Space. An 860 panel in the center; the screen dims to 74%. Search pill with a red caret,
// modes as chips (Tab): apps / run / windows / calc. With no query: "recent" and all applications in a grid of 6, with an alphabet on the right.
// Appears like Charms and Clip: rises by 24 and fades. Icons are monochrome glyphs in circles; unknown ones use the icon itself in dots; the selected one is a white circle
PanelWindow {
    id: root

    property int mode: 0
    property int sel: 0
    readonly property var modes: ["apps", "run", "windows", "calc"]
    readonly property string query: root.ui === "visual" ? (vinput?.text ?? "") : input.text
    readonly property string ui: Theme.state.launcherStyle || "classic"
    readonly property int cols: ui === "compact" || ui === "visual" ? 1 : 6
    readonly property int panelW: ui === "compact" ? 560 : ui === "visual" ? 980 : 860
    readonly property string wallUrl: {
        const p = Theme.wallSrc(Theme.state.wall);
        return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : "";
    }
    property var uses: ({}) // application id -> number of launches

    // glyphs for known applications; key is a lowercase fragment of the id/name
    readonly property var glyphs: [
        ["zen", "\u{F0239}"], ["firefox", "\u{F0239}"], ["helium", "\u{F0239}"], ["chrom", "\u{F059F}"], ["kitty", "\u{F018D}"], ["foot", "\u{F018D}"],
        ["spotify", "\u{F04C7}"], ["telegram", "\u{F2C6}"], ["codium", "\u{F0A1E}"], ["code", "\u{F0A1E}"], ["steam", "\u{F04D3}"],
        ["discord", "\u{F066F}"], ["vesktop", "\u{F066F}"], ["equibop", "\u{F066F}"], ["calculator", "\u{F00EC}"], ["calendar", "\u{F00ED}"],
        ["camera", "\u{F0100}"], ["thunar", "\u{F024B}"], ["nautilus", "\u{F024B}"], ["files", "\u{F024B}"], ["gimp", "\u{F02E9}"],
        ["mail", "\u{F01EE}"], ["btop", "\u{F035B}"], ["monitor", "\u{F035B}"], ["obsidian", "\u{F082E}"], ["settings", "\u{F0493}"],
        ["pavucontrol", "\u{F057E}"], ["mpv", "\u{F040A}"], ["vlc", "\u{F040A}"], ["clash", "\u{F0483}"], ["torrent", "\u{F01DA}"]
    ]
    function slowy(key) { return glyphs.find(g => key.toLowerCase().includes(g[0]))?.[1] ?? ""; }

    // at startup DesktopEntries adds entries one by one (~160 valuesChanged): a binding would rebuild the grid for each,
    // causing seconds of freezing. Build once, when the list settles
    property var apps: []
    Timer {
        id: appsT
        interval: 300
        running: true
        onTriggered: root.apps = DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
            id: e.id, name: e.name, src: e.icon ? Quickshell.iconPath(e.icon, true) : "", slowy: root.slowy(`${e.id} ${e.name}`),
            extra: `${e.id} ${e.genericName} ${(e.keywords ?? []).join(" ")}`.toLowerCase(), run: () => e.execute()
        })).sort((a, b) => a.name.localeCompare(b.name))
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { appsT.restart(); }
    }
    // windows only while windows mode is open: otherwise any title change would rebuild the list
    readonly property var wins: !visible || mode !== 2 ? [] : Hyprland.toplevels.values.map(t => {
        const cls = t.lastIpcObject?.class ?? "";
        return { name: t.title, src: Theme.appIcon(cls, t.lastIpcObject?.initialClass, t.appId), slowy: slowy(cls), extra: cls.toLowerCase(),
                 run: () => Hyprland.dispatch(`hl.dsp.focus({ window = "address:${t.address}" })`) };
    })

    // subsequence: word start and consecutive matches rank higher. hl holds indexes of matched letters
    function match(s, q) {
        if (!q) return { score: 1, hl: [] };
        const l = s.toLowerCase(), hl = [], at = l.indexOf(q);
        if (at >= 0) { for (let k = 0; k < q.length; k++) hl.push(at + k); return { score: (at === 0 ? 100 : 50) - at, hl }; }
        let i = 0;
        for (const c of q) {
            i = l.indexOf(c, i);
            if (i < 0) return null;
            hl.push(i++);
        }
        return { score: 10, hl };
    }
    function filter(src, q) {
        const out = [];
        for (const it of src) {
            const m = match(it.name, q);
            if (m) out.push(Object.assign({}, it, { hl: m.hl, score: m.score }));
            else if (it.extra.includes(q)) out.push(Object.assign({}, it, { hl: [], score: 1 }));
        }
        return out.sort((a, b) => b.score - a.score || (uses[b.id] ?? 0) - (uses[a.id] ?? 0));
    }

    // blocks: { head, sub, items }; each cell has row/col, which the arrow keys follow
    readonly property var blocks: {
        const q = query.trim().toLowerCase();
        let b;
        if (mode === 1) b = q ? [{ head: "run", items: [{ name: query, slowy: "\u{F018D}", hl: [], run: () => Quickshell.execDetached(["sh", "-c", query]) }] }] : [];
        else if (mode === 3) b = [];
        else if (mode === 2) b = [{ head: "windows", sub: String(wins.length), items: filter(wins, q) }];
        else if (q) {
            const r = filter(apps, q);
            b = [{ head: "results", sub: String(r.length), items: r }];
        } else {
            const recent = apps.filter(a => uses[a.id]).sort((a, b) => uses[b.id] - uses[a.id]).slice(0, 6);
            b = (recent.length ? [{ head: "recent", items: recent }] : []).concat([{ head: "all apps", sub: String(apps.length), all: true, items: apps }]);
        }
        let row = 0, k = 0;
        for (const x of b) {
            x.items = x.items.map((it, i) => Object.assign({}, it, { row: row + Math.floor(i / root.cols), col: i % root.cols, k: k++ }));
            row += Math.ceil(x.items.length / root.cols);
        }
        return b;
    }
    readonly property var flat: blocks.reduce((a, x) => a.concat(x.items), [])
    readonly property var cur: flat[sel] ?? null

    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    function open() {
        input.text = "";
        if (root.ui === "visual" && vinput) vinput.text = "";
        mode = 0;
        sel = 0;
        flick.contentY = 0;
        if (vflick) vflick.contentY = 0;
        shown = true;
        (root.ui === "visual" ? vinput : input).forceActiveFocus();
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    function move(dr, dc) {
        if (!flat.length) return;
        if (dc) return sel = (sel + dc + flat.length) % flat.length;
        const c = cur, row = flat.filter(x => x.row === c.row + dr);
        if (row.length) sel = row.reduce((a, x) => Math.abs(x.col - c.col) < Math.abs(a.col - c.col) ? x : a).k;
    }
    function launch() {
        if (!shown) return; // fades over Theme.t and still catches clicks: the second click of a double click would open a second window
        if (mode === 3) {
            if (calcOut) Quickshell.execDetached(["wl-copy", calcOut]);
            return close();
        }
        const it = cur;
        if (!it) return;
        close();
        if (it.id) {
            uses = Object.assign({}, uses, { [it.id]: (uses[it.id] ?? 0) + 1 });
            usesFile.setText(JSON.stringify(uses));
        }
        it.run();
    }

    FileView {
        id: usesFile
        path: Quickshell.statePath("launcher-uses.json")
        printErrors: false
        onLoaded: try { root.uses = JSON.parse(text()); } catch (e) {}
    }

    property string calcOut: ""
    Process { id: calc; stdout: StdioCollector { onStreamFinished: root.calcOut = text.trim() } }
    onQueryChanged: {
        sel = 0;
        if (mode === 3 && query.trim()) calc.exec(["qalc", "-t", query]); // exec cancels the previous calculation
        else calcOut = "";
    }
    onModeChanged: { sel = 0; flick.contentY = 0; if (mode === 3) queryChanged(); }
    // the list shrank without a new query (a window closed in windows mode): the cursor is past the end and cur is empty
    onFlatChanged: sel = Math.max(0, Math.min(sel, flat.length - 1))

    onVisibleChanged: if (visible) (root.ui === "visual" ? vinput : input).forceActiveFocus()

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "slowy-launcher"

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: root.ui === "visual" ? (stage.height - height) / 2 + 24 * (1 - root.t) : 140 + 24 * (1 - root.t)
            width: root.panelW
            height: root.ui === "visual" ? Math.min(stage.height - 160, 560) : Math.min(stage.height - 280, 30 + 66 + 20 + body.height + 34)
            opacity: root.t
            radius: root.ui === "visual" ? 20 : 44
            color: root.ui === "visual" ? Theme.fade(Theme.bg, 0.88) : Theme.s1
            border { width: 1; color: root.ui === "visual" ? Theme.fade(Theme.fg, 0.10) : Theme.s2 }
            clip: true
            MouseArea { anchors.fill: parent }

            // search: pill, red caret, mode chips
            Rectangle {
                id: search
                visible: root.ui !== "visual"
                x: 34
                y: 30
                width: parent.width - 68
                height: 66
                radius: 33
                color: Theme.s2

                Icon { id: lens; x: 24; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Theme.grey; font.pixelSize: 22 }
                TextInput {
                    id: input
                    anchors { left: lens.right; leftMargin: 16; right: chips.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    font { family: Theme.ui; pixelSize: 22 }
                    color: Theme.fg
                    selectionColor: Theme.s3
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.red
                        Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                    }
                    Text {
                        visible: !input.text
                        x: 6
                        text: ["Search apps, files, commands", "Run a command", "Find a window", "2 + 2, 20 usd to eur…"][root.mode]
                        font: input.font
                        color: Theme.mute
                    }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Escape) root.close();
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.launch();
                        else if (e.key === Qt.Key_Tab) root.mode = (root.mode + 1) % 4;
                        else if (e.key === Qt.Key_Backtab) root.mode = (root.mode + 3) % 4;
                        else if (e.key === Qt.Key_Down) root.move(1, 0);
                        else if (e.key === Qt.Key_Up) root.move(-1, 0);
                        else if (e.key === Qt.Key_Right && (!input.text || input.cursorPosition === input.text.length) && root.flat.length) root.move(0, 1);
                        else if (e.key === Qt.Key_Left && (!input.text || input.cursorPosition === 0) && root.flat.length) root.move(0, -1);
                        else return;
                        e.accepted = true;
                    }
                }
                Row {
                    id: chips
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: root.modes
                        Rectangle {
                            required property string modelData
                            required property int index
                            width: chip.width + 32
                            height: chip.height + 20
                            radius: height / 2
                            color: root.mode === index ? Theme.fg : "transparent"
                            Lb { id: chip; anchors.centerIn: parent; text: parent.modelData; px: 11; color: root.mode === parent.index ? Theme.ink : Theme.grey }
                            TapHandler { onTapped: { root.mode = parent.index; input.forceActiveFocus(); } }
                        }
                    }
                }
            }

            Flickable {
                id: flick
                visible: root.ui !== "visual"
                anchors { left: parent.left; right: parent.right; top: search.bottom; bottom: parent.bottom; topMargin: 20; leftMargin: 34; rightMargin: 34; bottomMargin: 34 }
                contentHeight: body.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                function ensure(y, h) {
                    if (y < contentY) contentY = y;
                    else if (y + h > contentY + height) contentY = y + h - height;
                }

                Column {
                    id: body
                    width: flick.width

                    // calc: answer large, Enter copies
                    Column {
                        visible: root.mode === 3
                        topPadding: 10
                        spacing: 10
                        Lb { text: root.calcOut ? "↵ copy" : "qalc" }
                        Num { width: body.width; elide: Text.ElideRight; text: root.calcOut || "—"; font.pixelSize: 96 }
                    }

                    // by index, not by array: a new blocks value (search letter, launch, recent) does not recreate ~160 cells
                    // with icons and layers; only their data changes
                    Repeater {
                        id: blockRep
                        model: root.blocks.length

                        Column {
                            id: block
                            required property int index
                            readonly property var modelData: root.blocks[index] ?? ({ head: "", items: [] })
                            readonly property Item g: grid
                            width: body.width
                            topPadding: index ? 30 : 10 // +20 on flick top: scrolled content is clipped with a gap below the search

                            Row {
                                spacing: 14
                                bottomPadding: 18
                                // JetBrains Mono letter group: which letters are currently in view
                                Num { visible: !!block.modelData.all; anchors.baseline: blab.baseline; text: root.range; font.pixelSize: 34 }
                                Lb { id: blab; text: block.modelData.head + (block.modelData.sub ? ` · ${block.modelData.sub}` : "") }
                            }
                            Grid {
                                id: grid
                                columns: root.cols
                                rowSpacing: root.ui === "compact" ? 4 : 22
                                Repeater {
                                    model: block.modelData.items.length
                                    Cell { items: block.modelData.items }
                                }
                            }
                        }
                    }
                }
            }

            // alphabet on the right: letters in view are white; click jumps to the first entry for that letter
            Column {
                visible: root.mode === 0 && !root.query && !!root.allGrid && root.ui !== "compact" && root.ui !== "visual"
                anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 130 }
                spacing: 3
                Repeater {
                    model: [..."ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
                    Text {
                        required property string modelData
                        width: 12
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font { family: Theme.mono; pixelSize: 10 }
                        color: root.range.includes(modelData) ? Theme.fg : Theme.mute
                        TapHandler { onTapped: root.jump(parent.modelData) }
                    }
                }
            }

            // visual style: wallpaper left, search + apps right
            Row {
                visible: root.ui === "visual"
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                Item {
                    id: wallPane
                    width: Math.round(parent.width * 0.38)
                    height: parent.height
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.wallUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize: Qt.size(width, height)
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.10) }
                            GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.35) }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height
                    color: Theme.fade(Theme.fg, 0.08)
                }

                Item {
                    width: parent.width - wallPane.width - 1
                    height: parent.height

                    Column {
                        anchors { fill: parent; margins: 24 }
                        spacing: 14

                        Row {
                            width: parent.width
                            spacing: 8
                            Text {
                                id: vprompt
                                text: root.modes[root.mode]
                                font { family: Theme.mono; pixelSize: 16 }
                                color: Theme.grey
                            }
                            Text {
                                id: vcaret
                                text: "»"
                                font { family: Theme.mono; pixelSize: 16 }
                                color: Theme.red
                            }
                            TextInput {
                                id: vinput
                                width: parent.width - vprompt.implicitWidth - vcaret.implicitWidth - 16
                                font { family: Theme.mono; pixelSize: 16 }
                                color: Theme.fg
                                selectionColor: Theme.s3
                                clip: true
                                cursorDelegate: Rectangle { width: 2; color: Theme.red; Timer { running: vinput.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity } }
                                Keys.onPressed: e => {
                                    if (e.key === Qt.Key_Escape) root.close();
                                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.launch();
                                    else if (e.key === Qt.Key_Tab) root.mode = (root.mode + 1) % 4;
                                    else if (e.key === Qt.Key_Backtab) root.mode = (root.mode + 3) % 4;
                                    else if (e.key === Qt.Key_Down) root.move(1, 0);
                                    else if (e.key === Qt.Key_Up) root.move(-1, 0);
                                    else return;
                                    e.accepted = true;
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: Theme.fade(Theme.fg, 0.08) }

                        Flickable {
                            id: vflick
                            width: parent.width
                            height: parent.height - vinput.height - 1 - 28
                            contentHeight: vcol.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: vcol
                                width: vflick.width
                                spacing: 2
                                Text {
                                    visible: root.mode === 3
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: root.calcOut || "type expression..."
                                    font { family: Theme.mono; pixelSize: 22 }
                                    color: root.calcOut ? Theme.fg : Theme.grey
                                }
                                Repeater {
                                    model: root.mode === 3 ? 0 : root.flat.length
                                    Rectangle {
                                        id: vcell
                                        required property int index
                                        readonly property var it: root.flat[index] ?? ({ name: "", hl: [] })
                                        readonly property bool on: root.sel === it.k
                                        width: vcol.width
                                        height: 40
                                        radius: 10
                                        color: on ? Theme.fade(Theme.fg, 0.10) : "transparent"
                                        onOnChanged: if (on) { const y = mapToItem(vcol, 0, 0).y; if (y < vflick.contentY) vflick.contentY = y; else if (y + height > vflick.contentY + vflick.height) vflick.contentY = y + height - vflick.height; }

                                        Row {
                                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                            spacing: 10
                                            Item {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 24; height: 24
                                                Icon {
                                                    anchors.centerIn: parent; visible: !!vcell.it.slowy
                                                    text: vcell.it.slowy ?? ""; font.pixelSize: 14
                                                    color: vcell.on ? Theme.fg : Theme.grey
                                                }
                                                Image {
                                                    anchors.centerIn: parent; visible: !vcell.it.slowy && status === Image.Ready
                                                    width: 20; height: 20; source: vcell.it.src ?? ""
                                                    sourceSize: Qt.size(20, 20); asynchronous: true
                                                    layer.enabled: true; layer.effect: Dm { step: 2.5 }
                                                }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 34
                                                elide: Text.ElideRight
                                                textFormat: Text.StyledText
                                                text: {
                                                    const hl = vcell.it.hl ?? [];
                                                    return [...(vcell.it.name ?? "")].map((c, i) => {
                                                        const e = c === "<" ? "&lt;" : c === "&" ? "&amp;" : c;
                                                        return hl.includes(i) ? `<font color="${Theme.fg}">${e}</font>` : e;
                                                    }).join("");
                                                }
                                                font { family: Theme.mono; pixelSize: 13 }
                                                color: vcell.on ? Theme.fg : Theme.grey
                                            }
                                        }
                                        TapHandler { onTapped: { root.sel = vcell.it.k; root.launch(); } }
                                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // letters of all applications whose rows are currently visible: "A-F"
    readonly property var allItems: blocks.find(b => b.all)?.items ?? []
    readonly property Item allGrid: { const i = blocks.findIndex(b => b.all); return blockRep.count > i && i >= 0 ? blockRep.itemAt(i)?.g ?? null : null; }
    readonly property string range: {
        if (!allGrid || !allItems.length) return "";
        const rh = root.ui === "compact" ? 52 : 120;
        const top = allGrid.mapToItem(body, 0, 0).y;
        const r0 = Math.max(0, Math.floor((flick.contentY - top) / rh)), r1 = Math.floor((flick.contentY + flick.height - top) / rh);
        const seen = allItems.slice(r0 * root.cols, (r1 + 1) * root.cols).map(a => a.name[0].toUpperCase());
        return seen.length ? seen[0] === seen[seen.length - 1] ? seen[0] : `${seen[0]}–${seen[seen.length - 1]}` : "";
    }
    function jump(l) {
        const i = allItems.findIndex(a => a.name[0].toUpperCase() >= l);
        if (i < 0) return;
        sel = allItems[i].k;
        const rh = root.ui === "compact" ? 52 : 120;
        flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), allGrid.mapToItem(body, 0, 0).y + Math.floor(i / root.cols) * rh);
    }

    // application cell: adapts to launcher style
    component Cell: Item {
        id: cell
        required property int index
        property var items: []
        readonly property var modelData: items[index] ?? ({ name: "", hl: [] })
        readonly property bool on: root.sel === modelData.k
        readonly property bool compact: root.ui === "compact"
        width: body.width / root.cols
        height: compact ? 48 : 120
        onOnChanged: if (on) flick.ensure(mapToItem(body, 0, 0).y, height)

        function hlText() {
            const hl = cell.modelData.hl ?? [];
            return [...(cell.modelData.name ?? "")].map((c, i) => {
                const e = c === "<" ? "&lt;" : c === "&" ? "&amp;" : c;
                return hl.includes(i) ? `<font color="${Theme.fg}">${e}</font>` : e;
            }).join("");
        }

        // compact: horizontal row
        Rectangle {
            visible: cell.compact
            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
            radius: 12
            color: cell.on ? Theme.s2 : "transparent"
            Row {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 32; radius: 16
                    color: cell.on ? Theme.fg : Theme.s2
                    Icon {
                        anchors.centerIn: parent; visible: !!cell.modelData.slowy
                        text: cell.modelData.slowy ?? ""; font.pixelSize: 16
                        color: cell.on ? Theme.ink : Theme.fg
                    }
                    Image {
                        anchors.centerIn: parent; visible: !cell.modelData.slowy && status === Image.Ready
                        width: 18; height: 18; source: cell.modelData.src ?? ""
                        sourceSize: Qt.size(18, 18); asynchronous: true; retainWhileLoading: true
                        layer.enabled: true; layer.effect: Dm { step: 2.5 }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44
                    elide: Text.ElideRight; textFormat: Text.StyledText
                    text: cell.hlText()
                    font { family: Theme.ui; pixelSize: 15 }
                    color: cell.on ? Theme.fg : Theme.grey
                }
            }
            TapHandler { onTapped: { root.sel = cell.modelData.k; root.launch(); } }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        // classic: vertical tile
        Column {
            visible: !cell.compact
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 88; height: 88; radius: 44
                color: cell.on ? Theme.fg : Theme.s2
                Icon {
                    anchors.centerIn: parent; visible: !!cell.modelData.slowy
                    text: cell.modelData.slowy ?? ""; font.pixelSize: 36
                    color: cell.on ? Theme.ink : Theme.fg
                }
                Image {
                    anchors.centerIn: parent; visible: !cell.modelData.slowy && status === Image.Ready
                    width: 44; height: 44; source: cell.modelData.src ?? ""
                    sourceSize: Qt.size(44, 44); asynchronous: true; retainWhileLoading: true
                    layer.enabled: true; layer.effect: Dm { step: 2.5 }
                }
                TapHandler { onTapped: { root.sel = cell.modelData.k; root.launch(); } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
            Text {
                width: cell.width - 8
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight; textFormat: Text.StyledText
                text: cell.hlText()
                font { family: Theme.ui; pixelSize: 14 }
                color: cell.on ? Theme.fg : Theme.grey
            }
        }
    }
}
