import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root
    function toggle() { visible = !visible }
    function close() { visible = false }

    visible: false
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "slowy-keyhelp"

    readonly property var binds: [
        ["Super", "Launcher (tap)"],
        ["Super + A", "Quick settings"],
        ["Super + I", "Settings"],
        ["Super + V", "Clipboard"],
        ["Super + .", "Charms / emoji"],
        ["Super + Shift + W", "Wallpaper"],
        ["Super + Shift + S / Print", "Screenshot"],
        ["Super + Esc", "Power menu"],
        ["Super + L", "Lock"],
        ["Alt + F1", "Keybind help"],
        ["Alt + F", "Floating window"],
        ["Alt + T", "Tiled window"],
        ["Super + 1-9", "Workspace"],
        ["Super + Arrow", "Focus window"],
        ["Super + Q", "Close window"],
        ["Super + Shift + Q", "Kill window"]
    ]

    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.bg, 0.92)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage
        focus: true
        Keys.onEscapePressed: root.close()

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(720, stage.width - 120)
            height: col.implicitHeight + 64
            radius: 24
            color: Theme.fade(Theme.s1, 0.82)
            border { width: 1; color: Theme.fade(Theme.s2, 0.7) }
            clip: true

            Image {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.72
                height: width
                source: "../assets/warga_slowy_logo.svg"
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                opacity: 0.10
                smooth: true
            }

            Column {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 32 }
                spacing: 18

                Num { text: "KEYBINDS"; font.pixelSize: 34 }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 32
                    rowSpacing: 10
                    Repeater {
                        model: root.binds
                        Row {
                            required property var modelData
                            width: (col.width - 32) / 2
                            spacing: 10
                            Lb {
                                id: key
                                width: parent.width * 0.46
                                elide: Text.ElideRight
                                text: modelData[0]
                                px: 10
                                color: Theme.fg
                            }
                            Lb {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - key.width - 10
                                elide: Text.ElideRight
                                text: modelData[1]
                                px: 10
                                color: Theme.fg
                                opacity: 0.72
                            }
                        }
                    }
                }

                Lb { text: "Esc to close"; px: 10; color: Theme.fg; opacity: 0.6 }
            }
        }
    }
}
