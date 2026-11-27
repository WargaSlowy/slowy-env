pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "focus.js" as FocusMath

// Focus/break pomodoro timer. One cycle: focus -> break -> stop.
// Persists to state so reload continues the active timer.
Singleton {
    id: root

    property int focusMinutes: 25
    property int breakMinutes: 5
    readonly property real focusHours: focusMinutes / 60
    readonly property real breakHours: breakMinutes / 60
    readonly property int minutes: focusMinutes // compat
    property bool isBreak: false
    property bool running: false
    property real end: 0
    property real rest: 0 // remaining while paused (ms of current mode)
    property real now: Date.now()
    signal done
    signal modeChanged(string mode)

    readonly property int modeMs: isBreak ? breakMinutes * 60000 : focusMinutes * 60000
    readonly property real left: running ? Math.max(0, end - now) : rest
    readonly property real f: modeMs > 0 ? 1 - left / modeMs : 0
    readonly property bool paused: !running && rest < modeMs && rest > 0

    function save() { Qt.callLater(stateFile.writeAdapter); }

    function finishBreak() {
        running = false;
        isBreak = false;
        rest = focusMinutes * 60000;
        Quickshell.execDetached(["notify-send", "-a", "focus", "Pomodoro", `Istirahat ${breakMinutes} menit selesai.`]);
        done();
        sync();
    }

    function startBreak() {
        isBreak = true;
        rest = breakMinutes * 60000;
        end = Date.now() + rest;
        running = true;
        now = Date.now();
        Quickshell.execDetached(["notify-send", "-a", "focus", "Pomodoro", `Fokus ${focusMinutes} menit selesai. Istirahat ${breakMinutes} menit.`]);
        modeChanged("break");
        done();
        sync();
    }

    function restore() {
        now = Date.now();
        if (!running) { sync(); return; }
        if (end > now) { sync(); return; }
        if (!isBreak) {
            const breakMs = breakMinutes * 60000;
            const intoBreak = now - end;
            if (intoBreak < breakMs) {
                isBreak = true;
                rest = breakMs;
                end = now + (breakMs - intoBreak);
                running = true;
            } else {
                running = false;
                isBreak = false;
                rest = focusMinutes * 60000;
            }
        } else {
            running = false;
            isBreak = false;
            rest = focusMinutes * 60000;
        }
        sync();
    }

    Component.onCompleted: {
        stateFile.waitForJob();
        focusMinutes = st.focusMinutes;
        breakMinutes = st.breakMinutes;
        isBreak = st.isBreak;
        running = st.running;
        end = st.end;
        rest = st.rest > 0 ? st.rest : modeMs;
        restore();
    }

    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice/focus.json"
        blockLoading: true
        watchChanges: false
        onAdapterUpdated: Qt.callLater(stateFile.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: st
            property int focusMinutes: 25
            property int breakMinutes: 5
            property bool isBreak: false
            property bool running: false
            property double end: 0
            property double rest: 0
        }
    }

    function sync() {
        st.focusMinutes = focusMinutes;
        st.breakMinutes = breakMinutes;
        st.isBreak = isBreak;
        st.running = running;
        st.end = end;
        st.rest = rest;
        save();
    }

    function clampMin(m) { m = Math.round(Number(m)); return Number.isFinite(m) ? Math.max(1, Math.min(24 * 60, m)) : 1; }
    function set(m) { setFocus(m); }
    function setFocus(m) { focusMinutes = clampMin(m); if (!isBreak) reset(); else sync(); }
    function setBreak(m) { breakMinutes = clampMin(m); if (isBreak) reset(); else sync(); }
    function setFocusHours(h) { setFocus(FocusMath.hoursToMinutes(h, 25)); }
    function setBreakHours(h) { setBreak(FocusMath.hoursToMinutes(h, 5)); }
    function reset() { running = false; rest = modeMs; sync(); }
    function toggle() {
        if (running) { rest = left; running = false; sync(); return; }
        now = Date.now();
        end = now + (rest > 0 ? rest : modeMs);
        running = true;
        sync();
    }
    function switchMode() {
        isBreak = !isBreak;
        running = false;
        rest = modeMs;
        modeChanged(isBreak ? "break" : "focus");
        sync();
    }
    function mmss(ms) { const s = Math.ceil(ms / 1000); return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`; }

    Timer {
        running: root.running
        interval: 1000
        repeat: true
        onTriggered: {
            root.now = Date.now();
            if (root.left > 0) return;
            if (!root.isBreak) root.startBreak();
            else root.finishBreak();
        }
    }
}
