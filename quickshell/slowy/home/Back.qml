import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// home backdrop in a separate window on the background layer: wallpaper only.
// The home itself (clock, bento) is on the layer above and transparent.
PanelWindow {
    id: root

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "slowy-back"

    Stage {
        id: stage
        Wall { id: wall; anchors.fill: parent; path: Theme.wallSrc(Theme.state.wall); animate: !Sys.wallOpen }
    }
}
