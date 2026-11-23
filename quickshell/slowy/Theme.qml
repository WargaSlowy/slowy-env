pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings
import "slots.js" as Slots

// slowy: black, white dots, one red. Palette, fonts, motion, state (theme, silence) and hypr/kitty appearance live here
Singleton {
    id: root

    // state survives a restart; the lock (a separate process) also reads it
    readonly property alias state: st
    readonly property bool light: st.light

    // colorschemes (prefs · LOOK): four-tone stack for the shell and 16 ANSI for kitty
    readonly property var schemes: ({
        everblush: {
            bg: "#141b1e", s1: "#232a2d", s2: "#232a2d", s3: "#b3b9b8",
            mute: "#4a4a4a", grey: "#b3b9b8", fg: "#dadada", ink: "#141b1e", red: "#e57474",
            ansi: ["#232a2d", "#e57474", "#8ccf7e", "#e5c76b", "#67b0e8", "#c47fd5", "#6cbfbf", "#dadada",
                   "#b3b9b8", "#e57474", "#8ccf7e", "#e5c76b", "#67b0e8", "#c47fd5", "#6cbfbf", "#dadada"]
        },
        aphelion: {
            bg: "#101319", s1: "#171b24", s2: "#171b24", s3: "#3A435A",
            mute: "#3A435A", grey: "#f4f3ee", fg: "#f4f3ee", ink: "#101319", red: "#E34F4F",
            ansi: ["#171b24", "#E34F4F", "#69bfce", "#e37e4f", "#5679E3", "#956dca", "#5599E2", "#f4f3ee",
                   "#3A435A", "#DE2B2B", "#56B7C8", "#DE642B", "#3E66E0", "#885AC4", "#3F8CDE", "#DDDBCF"]
        }
    })
    readonly property var scheme: schemes[st.scheme] ?? schemes.everblush
    readonly property var schemeNames: Object.keys(schemes)

    // light theme: same layout, greys inverted; the scheme colors the dark theme, red comes from it
    readonly property color bg: light ? "#E9E9E9" : scheme.bg   // background, wallpaper
    readonly property color s1: light ? "#FFFFFF" : scheme.s1   // bar, panels
    readonly property color s2: light ? "#F1F1F1" : scheme.s2   // tiles, off
    readonly property color s3: light ? "#D9D9D9" : scheme.s3   // lines, extinguished dots
    readonly property color mute: light ? "#B8B8B8" : scheme.mute // inactive
    readonly property color grey: light ? "#6E6E6E" : scheme.grey // labels, secondary
    readonly property color fg: light ? "#0B0B0B" : scheme.fg   // text, on, focus
    readonly property color ink: light ? "#FFFFFF" : scheme.ink  // text on a white tile
    readonly property color red: scheme.red                     // at most one thing on screen, and only "live"
    readonly property color glow: light ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color scrim: light ? Qt.rgba(0.91, 0.91, 0.91, 0.8) : Qt.rgba(0, 0, 0, 0.74)

    readonly property string dot: "Doto"                   // digits and short words, not smaller than 26px
    readonly property string ui: "GeistMono Nerd Font"
    readonly property string mono: "JetBrainsMono Nerd Font"            // labels in uppercase
    readonly property string nf: "JetBrainsMono Nerd Font" // icons

    // fonts offered by the LOOK page for the three home text groups, in picker order
    readonly property var fontNames: [
        "Doto", "GeistMono Nerd Font", "JetBrainsMono Nerd Font", "0xProto Nerd Font",
        "Cartograph CF", "Bebas Neue", "CommitMono Nerd Font", "DepartureMono Nerd Font"
    ]

    // design canvas 1920x1080 to screen. ponytail: based on the first screen; monitors of different sizes should be computed from the window screen
    readonly property real s: {
        const sc = Quickshell.screens[0];
        return sc ? Math.min(sc.width / 1920, sc.height / 1080) : 1;
    }

    // glide: ease-out-quart, no overshoot, like bezier glide in hypr
    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
    readonly property int t: 350

    // wallpaper is drawn from a screen-sized copy (made by the picker, magick); the original can be a 40 MB png and would take seconds to load.
    // ponytail: if no copy exists (cache cleared, path entered by hand), empty, grid and orb until the picker is opened
    readonly property string wallCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/slowy/walls"
    function wallSrc(p) { return p ? `${wallCache}/${p.slice(p.lastIndexOf("/") + 1)}.jpg` : ""; }

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    // clock per 12/24 setting: "09" or "9"
    function hh(d) { const h = d.getHours(); return st.clock24 ? String(h).padStart(2, "0") : String(h % 12 || 12); }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase(); }

    // as in Rules: apply() at startup must see slowy.json, not the defaults
    Component.onCompleted: {
        stateFile.waitForJob();
        if (!Array.isArray(st.widgetSlots) || st.widgetSlots.length !== 9)
            st.widgetSlots = Slots.migrate(st.widgets ?? [], kinds);
    }

    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice/slowy.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        // write once at the end of the turn; writeAdapter() on every field in a row mixes up adjacent ones
        onAdapterUpdated: Qt.callLater(stateFile.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: st
            property bool light: false
            property bool dnd: false  // new ones are not shown, critical ones always
            property int unread: 0    // for the lock
            // ---- what settings (prefs) control ----
            property var widgets: ["weather", "calendar", "cpu", "player", "buds", "system"] // home bento in order, see kinds
            property var widgetSlots: [] // explicit 3 x 3 placement, row-major; widgets stays the ordered id list
            property bool clock24: true
            property bool blink: true      // clock colon blinks
            property int clockSize: 300    // home clock digits, px
            property string clockFont: "Doto"                   // home clock digits
            property string greetFont: "GeistMono Nerd Font"     // greeting and name
            property string metaFont: "JetBrainsMono Nerd Font"  // date and notification line
            property string barFont: "JetBrainsMono Nerd Font"   // bar labels
            property string name: ""       // in the greeting; empty means $USER
            property string scheme: "everblush" // prefs · LOOK: everblush | aphelion
            // wallpaper (wall/Walls picker, drawn by components/Wall): image path; empty means background color. The picker folder can be changed here
            property string wall: ""
            property string wallDir: ""    // empty means ~/Pictures/Wallpapers
            property int wallLook: 0       // 0 dots, 1 grey photo, 2 color
            property int wallPitch: 10     // dot pitch, px
            property int wallBright: 85    // %, from background to image
            property int rounding: 20      // hypr windows
            property bool edges: true      // Slowy strips at the edges (volume/brightness, flashes, progress)
            property int briSteps: 20      // brightness from keys: divisions per scale, 40/20/10 gives 2.5/5/10 % steps
            property bool quickHover: true // quick settings on hover over the right edge
            property bool deckHover: true  // deck is the panel at the bottom center, slides out on hovering the edge
            property var deck: ["clock", "weather", "perf", "net", "media"] // its sections in order, see decks
            property var bar: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"] // bar tray from top to bottom, see bars
            property bool barTitle: true   // window title stacked in the bar
            property string barStyle: "slowy" // bar style: slowy or vdx
            property string barWs: "circle" // workspace indicator: circle | number
            property int barRadius: 16        // vdx pill corner radius, px; 0 is square
            property int barBorder: 1         // vdx pill frame width, px; 0 removes it
            property int pillHeight: 32       // vdx pill height at rest, px
            property int topGap: 0            // extra top reservation below the pill, px
            property int hubWidth: 400        // vdx hub width, px
            property int barIconGrow: 0       // px added to the vdx tray icons, as in vdx
            property bool showClock: true     // vdx Show the clock
            property bool noticeDot: true     // vdx barFolderDot: dot for unseen notices
            property bool hubPlayer: true     // vdx hubPlayer: the track in the hub
            // recording (quick/Rec, Sys.recArgs)
            property int recArea: 0        // 0 whole monitor, 1 region (slurp)
            property int recAudio: 0       // 0 no sound, 1 system, 2 microphone, 3 both on one track
            property int recFps: 60
            property int recQuality: 2     // medium, high, very_high, ultra
            property bool recCursor: true
        }
    }

    // bento widgets: id to width in cells (3 columns x 3 rows of 220). What does not fit is not shown
    readonly property var kinds: ({ weather: 1, calendar: 1, cpu: 1, ram: 1, gpu: 1, disk: 1, battery: 1, buds: 1, player: 2, system: 3, cat: 1, cava: 1 })
    // deck sections
    readonly property var decks: ["clock", "weather", "perf", "net", "media"]
    // bar tray
    readonly property var bars: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"]

    // ---- appearance of everything outside the shell. Called only by shell.qml: at startup and on theme change ----
    // hypr inherits from demonshot: monitor, input, idle, night light and motion are set by its Rules (shell.qml), animations come from
    // the hypr config. From here come gaps/border/blur/shadows from its rules.json, while slowy has its own border colors, shadows, groups, background and
    // rounding 20 (without them the red glow and demonshot groups from hypr/variables.lua would remain).
    // Back to demonshot: `rice switch` runs hyprctl reload, its applyAll repaints
    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // kitty includes this file after its own colors (include in kitty.conf); demonshot writes its palette there too
    FileView { id: kitty; path: Quickshell.env("HOME") + "/.config/demonshot/kitty.conf"; printErrors: false }
    // ghostty includes this file at the end of its config and rereads it on SIGUSR2
    FileView { id: ghostty; path: Quickshell.env("HOME") + "/.config/demonshot/ghostty.conf"; printErrors: false }
    // gtk: written by Theme.apply(); ~/.config/gtk-{3,4}.0/gtk.css symlink to this file. Toggle gtk-theme after writing so running GTK apps re-read it
    FileView {
        id: gtkCss
        path: Quickshell.env("HOME") + "/.config/quickshell/slowy/term/gtk-3.0/gtk.css"
        printErrors: false
    }
    // firefox: textfox config.css — written by Theme.apply(); userChrome.css imports it. Firefox re-reads on restart
    FileView {
        id: firefoxCss
        path: Quickshell.env("HOME") + "/.mozilla/firefox/6kfl0w8f.default-release/chrome/config.css"
        printErrors: false
    }
    // qt: qtengine.colors — written by Theme.apply(); qt5ct/qt6ct read it on next start
    FileView {
        id: qtengineColors
        path: Quickshell.env("HOME") + "/.config/qtengine.colors"
        printErrors: false
    }
    // 16 ANSI colors of the selected scheme: pastel for the terminal only. In the light theme 0<->15 and 7<->8 so white is not lost on white
    readonly property var ansi: scheme.ansi

    function apply() {
        // game mode (Rules.store.game) over the settings, like ultra: border 1, no gaps or rounding, tearing for
        // windows with immediate (games, hyprland/rules.lua). When leaving, own values return, allow_tearing false, as in general.lua
        const r = Rules.store, g = r.game;
        const c = x => `"rgb(${hex(x)})"`;
        // shadow: in the dark theme a barely visible white glow, in the light theme a soft black
        const shadow = light ? "rgba(0000002E)" : `rgba(${hex(fg)}1A)`;
        hypr(`hl.config({ general = { gaps_in = ${g ? 0 : r.gapsIn}, gaps_out = ${g ? 0 : r.gapsOut}, border_size = ${g ? 1 : r.border}, allow_tearing = ${g}, `
           + `col = { active_border = ${c(fg)}, inactive_border = ${c(s3)} } }, `
           + `decoration = { rounding = ${g ? 0 : st.rounding}, blur = { enabled = ${Rules.blurOn} }, shadow = { enabled = ${Rules.shadowOn}, color = "${shadow}" } }, `
           + `group = { col = { border_active = ${c(fg)}, border_inactive = ${c(s3)}, border_locked_active = ${c(fg)}, border_locked_inactive = ${c(mute)} }, `
           + `groupbar = { font_family = "${mono}", text_color = ${c(fg)}, col = { active = ${c(s3)}, inactive = ${c(s1)}, locked_active = ${c(s3)}, locked_inactive = ${c(s1)} } } }, `
           + `misc = { background_color = ${c(bg)} } })`);

        // only the scheme itself: font, tabs, animations, selection and keys stay in ~/.config/kitty/kitty.conf
        const a = light ? [15, 1, 2, 3, 4, 5, 6, 8, 7, 9, 10, 11, 12, 13, 14, 0].map(i => ansi[i]) : ansi;
        kitty.setText("# slowy: colorscheme only — Theme.apply() writes, do not edit by hand\n" + [
            ["foreground", fg], ["background", bg], ["cursor", fg]
        ].concat(a.map((c, i) => ["color" + i, c])).map(([k, v]) => `${k} ${typeof v === "string" ? v : v.toString().slice(0, 7).toUpperCase()}`).join("\n") + "\n");
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);

        // ghostty: palette only; font, padding, shaders and keys stay in ~/.config/ghostty/config
        const gv = v => typeof v === "string" ? v : v.toString().slice(0, 7).toUpperCase();
        const ghosttyLines = [
            ["background", bg], ["foreground", fg], ["cursor-color", fg], ["cursor-text", bg],
            ["selection-background", a[6]], ["selection-foreground", bg]
        ].map(([k, v]) => `${k} = ${gv(v)}`);
        a.forEach((c, i) => ghosttyLines.push(`palette = ${i}=${gv(c)}`));
        ghostty.setText("# slowy: colorscheme only - Theme.apply() writes, do not edit by hand\n" + ghosttyLines.join("\n") + "\n");
        Quickshell.execDetached(["pkill", "-USR2", "-x", "ghostty"]);

        // gtk: same palette for GTK apps (thunar, etc.); ~/.config/gtk-{3,4}.0/gtk.css symlink to this file
        const sc = c => typeof c === "string" ? c : c.toString().slice(0, 7).toUpperCase();
        const alphaCss = (c, alpha) => `alpha(${sc(c)}, ${alpha})`;
        gtkCss.setText(`/* slowy: colorscheme — Theme.apply() writes, do not edit by hand */
@define-color accent_color ${sc(fg)};
@define-color accent_bg_color ${sc(fg)};
@define-color accent_fg_color ${sc(bg)};
@define-color destructive_color ${sc(red)};
@define-color destructive_bg_color ${sc(red)};
@define-color destructive_fg_color ${sc(bg)};
@define-color window_bg_color ${sc(bg)};
@define-color window_fg_color ${sc(fg)};
@define-color view_bg_color ${sc(bg)};
@define-color view_fg_color ${sc(fg)};
@define-color headerbar_bg_color ${sc(bg)};
@define-color headerbar_fg_color ${sc(fg)};
@define-color headerbar_border_color ${sc(bg)};
@define-color headerbar_backdrop_color ${sc(bg)};
@define-color popover_bg_color ${sc(bg)};
@define-color popover_fg_color ${sc(fg)};
@define-color dialog_bg_color ${sc(bg)};
@define-color dialog_fg_color ${sc(fg)};
@define-color card_bg_color ${sc(bg)};
@define-color card_fg_color ${sc(fg)};
@define-color sidebar_bg_color ${sc(bg)};
@define-color sidebar_fg_color ${sc(fg)};
@define-color sidebar_border_color ${sc(bg)};
@define-color sidebar_backdrop_color ${sc(bg)};
@define-color borders ${sc(s3)};
@define-color theme_bg_color ${sc(bg)};
@define-color theme_fg_color ${sc(fg)};
@define-color theme_base_color ${sc(bg)};
@define-color theme_text_color ${sc(fg)};
@define-color theme_selected_bg_color ${sc(fg)};
@define-color theme_selected_fg_color ${sc(bg)};
@define-color insensitive_fg_color ${sc(mute)};

window, popover, menu { font-family: "GeistMono Nerd Font"; }

button, entry { border-radius: 999px; }
entry { padding-left: 14px; padding-right: 14px; }
.linked:not(.vertical) > button:not(:first-child), .linked:not(.vertical) > entry:not(:first-child) { border-top-left-radius: 0; border-bottom-left-radius: 0; }
.linked:not(.vertical) > button:not(:last-child), .linked:not(.vertical) > entry:not(:last-child) { border-top-right-radius: 0; border-bottom-right-radius: 0; }
.linked.vertical > button, .linked.vertical > entry { border-radius: 12px; }
popover > contents, popover.background { border-radius: 24px; }

switch:checked slider { background-color: ${sc(bg)}; }

scrollbar slider { border-radius: 999px; background-color: ${sc(mute)}; }
scrollbar slider:hover, scrollbar slider:active { background-color: ${sc(s3)}; }

.thunar paned > separator { min-width: 12px; background: none; box-shadow: none; }
.thunar, .thunar window, .thunar grid, .thunar paned, .thunar notebook, .thunar stack,
.thunar .standard-view, .thunar .standard-view .view, .thunar .standard-view scrolledwindow, .thunar .standard-view viewport, .thunar .standard-view frame,
.thunar .sidebar, .thunar .sidebar .view, .thunar .sidebar scrolledwindow, .thunar .sidebar viewport, .thunar .sidebar list, .thunar .sidebar row,
.thunar placessidebar, .thunar placessidebar list, .thunar placessidebar row,
.thunar toolbar, .thunar .location-toolbar, .thunar statusbar, .thunar headerbar {
  background-color: ${sc(bg)};
  background-image: none;
}
.thunar .standard-view { border-radius: 28px; padding: 10px; margin: 0 12px 0 0; }
.thunar .sidebar .view, .thunar placessidebar row { padding: 8px 12px; border-radius: 999px; }
.thunar .path-bar-button { font-family: "Space Mono"; font-size: 12px; letter-spacing: 1px; padding: 6px 14px; background: none; background-color: ${sc(bg)}; box-shadow: none; border: none; }
.thunar notebook header { background: none; background-color: ${sc(bg)}; box-shadow: none; border: none; }
.thunar notebook header tab { border-radius: 999px; padding: 4px 16px; box-shadow: none; background: none; background-color: ${sc(bg)}; }
.thunar statusbar { font-family: "Space Mono"; font-size: 11px; letter-spacing: 1.5px; color: ${sc(mute)}; padding: 6px 12px; }
.thunar .rubberband { background-color: ${alphaCss(fg, 0.08)}; border: 1px solid ${alphaCss(fg, 0.4)}; }
.thunar .standard-view .view:selected, .thunar .standard-view .view:selected *, .thunar iconview.view:selected, .thunar treeview.view:selected { background-color: ${sc(fg)}; color: ${sc(bg)}; }
.thunar .standard-view .view:selected { border-radius: 14px; }
.thunar .standard-view treeview.view:selected, .thunar .standard-view treeview.view:selected * { border-radius: 0; }
.thunar .sidebar .view:selected, .thunar .sidebar row:selected, .thunar placessidebar row:selected { background-color: ${sc(fg)}; color: ${sc(bg)}; }
.thunar .path-bar-button:checked { background-color: ${sc(fg)}; color: ${sc(bg)}; }
.thunar notebook header tab:checked { background-color: ${sc(fg)}; color: ${sc(bg)}; }
`);

        // force GTK to re-read the css (same trick rice uses)
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "Adwaita"]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "adw-gtk3-dark"]);

        // firefox: textfox config.css — variables from the current scheme
        const accent = scheme.ansi[4] ?? scheme.fg; // blue-ish accent
        firefoxCss.setText(`/*
 * textfox config — ${scheme === schemes.everblush ? "everblush" : "aphelion"}
 * auto-generated by slowy Theme.apply(); do not edit by hand
 */

:root {
  /* layout */
  --tf-font-family: "JetBrainsMono NF", monospace;
  --tf-font-size: 13px;
  --tf-rounding: 4px;
  --tf-border-width: 2px;
  --tf-display-horizontal-tabs: block;
  --tf-display-nav-buttons: flex;
  --tf-display-urlbar-icons: flex;
  --tf-display-sidebar-tools: flex;
  --tf-display-titles: flex;

  /* scheme */
  --tf-bg: ${sc(scheme.bg)};
  --tf-border: ${sc(scheme.s3)};
  --tf-accent: ${sc(accent)};
  --tf-text: ${sc(scheme.fg)};

  /* about:newtab */
  --newtab-wallpaper-color: ${sc(scheme.bg)};
  --newtab-contextual-text-primary-color: ${sc(scheme.fg)};
}

/* main panel border: accent, not the flat --tf-border gray */
#tabbrowser-tabbox {
  border-color: var(--tf-accent);
}

tab,
#nav-bar,
#PersonalToolbar,
#sidebar-box,
#sidebar-main,
findbar,
menupopup,
panel,
toolbar,
.browserContainer {
  color: var(--tf-text) !important;
}
`);

        // qt: qtengine.colors — same palette for Qt apps (rofi, qbittorrent, obsidian...)
        const scq = c => typeof c === "string" ? c : c.toString().slice(0, 7).toUpperCase();
        const link = scheme.ansi[4] ?? scheme.fg;
        qtengineColors.setText(`# slowy: colorscheme — Theme.apply() writes, do not edit by hand

[Colors:Button]
BackgroundAlternate=${scq(s2)}
BackgroundNormal=${scq(bg)}
DecorationFocus=${scq(fg)}
DecorationHover=${scq(s3)}
ForegroundActive=${scq(fg)}
ForegroundInactive=${scq(mute)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(fg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}

[Colors:Complementary]
BackgroundAlternate=${scq(bg)}
BackgroundNormal=${scq(s1)}
DecorationFocus=${scq(fg)}
DecorationHover=${scq(s3)}
ForegroundActive=${scq(fg)}
ForegroundInactive=${scq(mute)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(fg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}

[Colors:Header]
BackgroundAlternate=${scq(bg)}
BackgroundNormal=${scq(bg)}
DecorationFocus=${scq(fg)}
DecorationHover=${scq(s3)}
ForegroundActive=${scq(fg)}
ForegroundInactive=${scq(mute)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(fg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}

[Colors:Input]
BackgroundAlternate=${scq(s1)}
BackgroundNormal=${scq(s1)}
DecorationFocus=${scq(fg)}
DecorationHover=${scq(s3)}
ForegroundActive=${scq(fg)}
ForegroundInactive=${scq(mute)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(fg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}

[Colors:Item]
BackgroundAlternate=${scq(s2)}
BackgroundNormal=${scq(bg)}
DecorationFocus=${scq(fg)}
DecorationHover=${scq(s3)}
ForegroundActive=${scq(fg)}
ForegroundInactive=${scq(mute)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(fg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}

[Colors:Selection]
BackgroundAlternate=${scq(fg)}
BackgroundNormal=${scq(fg)}
DecorationFocus=${scq(bg)}
DecorationHover=${scq(fg)}
ForegroundActive=${scq(bg)}
ForegroundInactive=${scq(bg)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(bg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}

[Colors:Text]
BackgroundAlternate=${scq(bg)}
BackgroundNormal=${scq(bg)}
DecorationFocus=${scq(fg)}
DecorationHover=${scq(s3)}
ForegroundActive=${scq(fg)}
ForegroundInactive=${scq(mute)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(fg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}

[Colors:Tooltip]
BackgroundAlternate=${scq(s1)}
BackgroundNormal=${scq(s1)}
DecorationFocus=${scq(fg)}
DecorationHover=${scq(s3)}
ForegroundActive=${scq(fg)}
ForegroundInactive=${scq(mute)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(fg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}

[Colors:View]
BackgroundAlternate=${scq(s2)}
BackgroundNormal=${scq(s1)}
DecorationFocus=${scq(fg)}
DecorationHover=${scq(s3)}
ForegroundActive=${scq(fg)}
ForegroundInactive=${scq(mute)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(fg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}

[Colors:Window]
BackgroundAlternate=${scq(s1)}
BackgroundNormal=${scq(bg)}
DecorationFocus=${scq(fg)}
DecorationHover=${scq(s3)}
ForegroundActive=${scq(fg)}
ForegroundInactive=${scq(mute)}
ForegroundLink=${scq(link)}
ForegroundNegative=${scq(red)}
ForegroundNeutral=${scq(s3)}
ForegroundNormal=${scq(fg)}
ForegroundPositive=${scq(link)}
ForegroundVisited=${scq(link)}
`);
    }
}
