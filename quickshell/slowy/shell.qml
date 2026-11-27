import QtQuick
import Quickshell
import Quickshell.Hyprland
import "bar"
import "buds"
import "charms"
import "clip"
import "slowy"
import "home"
import "launcher"
import "power"
import "prefs"
import "quick"
import "settings"
import "shot"
import "vpn"
import "wall"
import "keyhelp"
import "notif"

// slowy: a rice in the spirit of nothing os. Home on the wallpaper, bar, launcher, quick settings,
// Slowy strips at the edges instead of OSD, notification island, power menu, settings, deck (bottom dashboard), clipboard, charms (emoji and symbols), screenshots, vpn, wallpaper. Lock is a separate process (lock.qml).
// Switched from demonshot via `rice switch` / the Rice app; hypr binds are shared (shell:*), each shell takes its own
ShellRoot {
    id: shell
    property var frames: []

    Launcher { id: launcher }
    Quick { id: quick; onPowerRequested: power.open(); onSettingsRequested: prefs.open() }
    Power { id: power }
    Prefs { id: prefs; onWallRequested: walls.open() }
    Slowy { id: slowy }
    Buds {}
    Clip { id: clip }
    Charms { id: charms }
    Shot { id: shot }
    Vpn { id: vpn }
    Walls { id: walls }
    KeyHelp { id: keyhelp }
    Notif {}

    Variants {
        model: Quickshell.screens
        Scope {
            id: s
            required property var modelData
            Back { screen: s.modelData }
            Home { screen: s.modelData }
            Hot { screen: s.modelData; onTriggered: quick.peek() }
            Frame {
                id: frame
                screen: s.modelData
                visible: Theme.state.barStyle === "slowy"
                Component.onCompleted: shell.frames.push(frame)
            }
            Bar {
                screen: s.modelData
                visible: Theme.state.barStyle === "slowy"
                onMarkClicked: launcher.toggle()
                onTrayClicked: quick.toggle()
                onPowerClicked: power.visible ? power.close() : power.open()
                onWifiClicked: { quick.peeked = false; quick.open = true; quick.pick = "wifi"; }
            }
            VdxBar {
                screen: s.modelData
                onTrayClicked: quick.toggle()
                onPowerClicked: power.visible ? power.close() : power.open()
            }
        }
    }

    // hypr as in demonshot: its Rules (settings/Rules.qml, the same ~/.config/demonshot/rules.json) set monitor, input,
    // motion, night light and hypridle; on top Theme.apply sets its own border colors, rounding and kitty. It is also called on theme change
    Component.onCompleted: {
        hypr();
        Rules.night();
        Rules.idle();
    }
    // what lives in the hypr config. It rereads it itself: save any hypr file (links are live, both git pull and branch
    // changes), hyprctl reload, and it restores variables.lua defaults: demonshot borders, monitor, input, animations. We apply
    // ours again. hyprctl eval configreloaded is not sent, so there is no loop. Night light and hypridle are separate processes, reload does not touch them
    function hypr() {
        Rules.monitor();
        Rules.input();
        Rules.motion();
        Theme.apply();
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "configreloaded") shell.hypr(); }
    }
    Connections {
        target: Theme
        function onLightChanged() { Theme.apply(); }
    }
    Connections {
        target: Theme.state
        function onRoundingChanged() { Theme.apply(); }
    }
    Connections {
        target: Theme.state
        function onSchemeChanged() { Theme.apply(); }
    }
    // ultra mode enables/disables blur and shadows over the settings; windows must be repainted (refresh rate and motion are set by Rules.setMode).
    // Game mode does the same and also animations
    Connections {
        target: Rules.store
        function onUltraChanged() { Theme.apply(); }
        function onGameChanged() { Rules.motion(); Theme.apply(); }
    }


    // Super tap opens the launcher on release; any Super+<key> along the way sends interrupt, and the launcher does not open
    property bool interrupted: false
    Shortcut {
        name: "launcher"
        description: "лаунчер (тап Super)"
        onReleased: {
            if (!shell.interrupted) launcher.toggle();
            shell.interrupted = false;
        }
    }
    Shortcut { name: "launcherArm"; description: "нажатие Super — сброс interrupt"; onPressed: shell.interrupted = false }
    Shortcut { name: "launcherInterrupt"; description: "Super+<key> — do not open launcher"; onPressed: shell.interrupted = true }
    // Super+Space (altar in demonshot) toggles the bottom deck in the frame
    Shortcut {
        name: "altar"
        description: "deck: dashboard at bottom"
        onPressed: {
            const m = Hyprland.focusedMonitor?.name;
            for (let i = 0; i < shell.frames.length; i++)
                if (shell.frames[i].screen?.name === m) { shell.frames[i].deckOpen = !shell.frames[i].deckOpen; return; }
            if (shell.frames.length) shell.frames[0].deckOpen = !shell.frames[0].deckOpen;
        }
    }
    Shortcut { name: "quick"; description: "quick settings"; onPressed: quick.toggle() }
    Shortcut { name: "ward"; description: "quick settings"; onPressed: quick.toggle() } // Super+N in demonshot uses the same toggles
    Shortcut { name: "settings"; description: "settings"; onPressed: prefs.toggle() }
    Shortcut { name: "power"; description: "power menu"; onPressed: power.visible ? power.close() : power.open() }
    Shortcut { name: "shot"; description: "screenshot"; onPressed: shot.open() }
    Shortcut { name: "pact"; description: "vpn: clash verge"; onPressed: vpn.toggle() }
    Shortcut { name: "clip"; description: "clipboard"; onPressed: clip.toggle() }
    Shortcut { name: "charms"; description: "emoji, kaomoji, symbols"; onPressed: charms.toggle() }
    Shortcut { name: "wall"; description: "wallpaper"; onPressed: walls.toggle() }
    Shortcut { name: "keyhelp"; description: "keybind help"; onPressed: keyhelp.toggle() }
    Shortcut { name: "game"; description: "game mode"; onPressed: Rules.store.game = !Rules.store.game }

    component Shortcut: GlobalShortcut { appid: "shell" }
}
