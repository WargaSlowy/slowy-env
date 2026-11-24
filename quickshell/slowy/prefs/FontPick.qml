import QtQuick
import QtQuick.Controls
import qs
import qs.components

// font selector: a pill shows the current choice, click or Enter opens a list above it.
// Up/down moves, Enter picks, Escape or focus loss closes. Left/right still steps without opening.
Rectangle {
    id: root

    property string label
    property var opts: []
    property int cur: -1
    signal picked(int i)

    function short(n) { return n.replace(" Nerd Font", "") }
    function openList() {
        list.sel = Math.max(0, root.cur);
        list.visible = true;
        root.forceActiveFocus();
    }
    function closeList() { list.visible = false }

    width: head.implicitWidth + name.implicitWidth + chev.implicitWidth + 78
    height: 64
    radius: 32
    color: Theme.s2
    border { width: activeFocus || list.visible ? 1 : 0; color: Theme.fg }
    activeFocusOnTab: true
    onActiveFocusChanged: if (!activeFocus && list.visible) closeList()

    Lb {
        id: head
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 28
        text: root.label
        color: root.activeFocus || list.visible ? Theme.fg : Theme.grey
    }
    Lb {
        id: name
        anchors { left: head.right; leftMargin: 14; verticalCenter: parent.verticalCenter }
        text: root.cur >= 0 ? root.short(root.opts[root.cur]) : ""
        color: Theme.fg
    }
    Icon {
        id: chev
        anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
        text: "\u{F0140}"
        font.pixelSize: 18
        color: Theme.grey
        rotation: list.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    }

    Keys.onPressed: e => {
        const n = root.opts.length;
        if (!list.visible) {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space || e.key === Qt.Key_Down) root.openList();
            else if (e.key === Qt.Key_Left) root.picked((Math.max(root.cur, 0) + n - 1) % n);
            else if (e.key === Qt.Key_Right) root.picked((Math.max(root.cur, 0) + 1) % n);
            else return;
        } else {
            if (e.key === Qt.Key_Up) list.sel = (list.sel + n - 1) % n;
            else if (e.key === Qt.Key_Down) list.sel = (list.sel + 1) % n;
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.picked(list.sel); root.closeList(); }
            else if (e.key === Qt.Key_Escape) root.closeList();
            else return;
        }
        e.accepted = true;
    }

    TapHandler {
        onTapped: {
            root.forceActiveFocus();
            if (list.visible) root.closeList();
            else root.openList();
        }
    }

    Popup {
        id: list
        property int sel: Math.max(0, root.cur)
        property real originX: 0
        property real spaceBelow: 320
        property real spaceAbove: 320
        readonly property real viewW: Overlay.overlay ? Overlay.overlay.width : 1200
        readonly property real viewH: Overlay.overlay ? Overlay.overlay.height : 800
        readonly property real wantH: root.opts.length * 48 + 16
        readonly property bool openUp: spaceBelow < Math.min(wantH, 320) && spaceAbove > spaceBelow
        readonly property real availH: Math.max(0, (openUp ? spaceAbove : spaceBelow) - 16)
        function place() {
            const pt = root.mapToItem(Overlay.overlay, 0, 0);
            originX = pt.x;
            spaceAbove = pt.y - 8;
            spaceBelow = viewH - (pt.y + root.height * Theme.s) - 8;
        }
        visible: false
        // ponytail: popup lives in the unscaled overlay, so clamp in device px then convert back to parent units
        x: Math.max((8 - originX) / Theme.s, Math.min(0, (viewW - 8 - originX - width) / Theme.s))
        y: openUp ? -(height + 12) / Theme.s : (root.height * Theme.s + 12) / Theme.s
        z: 10
        width: Math.max(root.width, 340)
        height: Math.max(1, Math.min(wantH, availH, 420))
        padding: 0
        closePolicy: Popup.NoAutoClose
        onAboutToShow: { place(); flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, sel * 48 - flick.height / 2 + 24)); }
        background: Rectangle {
            radius: 26
            color: Theme.s2
            border { width: 1; color: Theme.s3 }
        }
        contentItem: Flickable {
            id: flick
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: root.opts.length * 48 + 16
            Repeater {
                model: root.opts
                Rectangle {
                    required property string modelData
                    required property int index
                    x: 8
                    y: 8 + index * 48
                    width: list.width - 16
                    height: 48
                    radius: 24
                    color: index === list.sel ? Theme.fg : "transparent"
                    Lb {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 20
                        text: parent.modelData
                        px: 12
                        color: index === list.sel ? Theme.ink : Theme.grey
                    }
                    TapHandler {
                        onTapped: {
                            root.picked(parent.index);
                            root.closeList();
                        }
                    }
                }
            }
        }
    }
}
