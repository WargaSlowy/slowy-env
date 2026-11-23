import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs
import qs.components

PanelWindow {
    id: root

    property var note: null
    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    function show(n) {
        note = n;
        shown = true;
        hideT.restart();
    }

    visible: t > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "slowy-notif"

    Timer { id: hideT; interval: 4000; onTriggered: root.shown = false }

    Connections {
        target: Notes
        function onReceived(n) {
            if (Theme.state.dnd && n.urgency !== NotificationUrgency.Critical) return;
            root.show(n);
        }
    }

    Stage {
        id: stage
        Rectangle {
            id: card
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -20 * (1 - root.t)
            width: Math.min(520, stage.width - 80)
            implicitHeight: col.implicitHeight + 32
            radius: 20
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            opacity: root.t
            scale: 0.96 + 0.04 * root.t

            Column {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 6

                Lb {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (root.note?.appName || "Notification").toUpperCase()
                    px: 10
                    color: Theme.grey
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: root.note?.summary ?? ""
                    font { family: Theme.ui; pixelSize: 16; weight: Font.DemiBold }
                    color: Theme.fg
                }
                Text {
                    visible: !!(root.note?.body)
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: root.note?.body ?? ""
                    font { family: Theme.ui; pixelSize: 13 }
                    color: Theme.grey
                }
            }

            MouseArea { anchors.fill: parent; onClicked: root.shown = false }
        }
    }
}
