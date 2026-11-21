// explicit 3 x 3 placement for home widgets. Pure functions shared by Theme.qml, Prefs.qml and the Node tests.
// A widget with span s owns s consecutive cells of one row, so its id appears in each of those cells.
"use strict";

function blank() {
    return Array(9).fill(null);
}

function copy(slots) {
    return Array.isArray(slots) && slots.length === 9 ? slots.slice() : blank();
}

function spanOf(kinds, id) {
    return kinds?.[id] ?? 1;
}

function cellsOf(slots, id) {
    const out = [];
    for (let i = 0; i < 9; i++) if (slots[i] === id) out.push(i);
    return out;
}

function anchorOf(cell, span) {
    return Math.floor(cell / 3) * 3 + Math.min(cell % 3, 3 - span);
}

function canFit(slots, kinds, id, cell) {
    const span = spanOf(kinds, id);
    const row = Math.floor(cell / 3), col = cell % 3;
    if (row < 0 || row > 2 || col < 0 || col + span > 3) return false;
    for (let k = 0; k < span; k++) if (slots[row * 3 + col + k] !== null) return false;
    return true;
}

function write(out, kinds, id, cell) {
    const span = spanOf(kinds, id);
    const row = Math.floor(cell / 3), col = cell % 3;
    for (let k = 0; k < span; k++) out[row * 3 + col + k] = id;
}

function clear(slots, id) {
    const out = copy(slots);
    for (let i = 0; i < 9; i++) if (out[i] === id) out[i] = null;
    return out;
}

function firstFit(slots, kinds, id) {
    const span = spanOf(kinds, id);
    for (let cell = 0; cell < 9; cell++) {
        if (canFit(slots, kinds, id, cell)) return cell;
    }
    return -1;
}

function migrate(ids, kinds) {
    const out = blank();
    let row = 0, col = 0;
    for (const id of ids ?? []) {
        const span = spanOf(kinds, id);
        if (!kinds?.[id]) continue;
        if (col + span > 3) { row++; col = 0; }
        if (row > 2) break;
        for (let k = 0; k < span; k++) out[row * 3 + col + k] = id;
        col += span;
    }
    return out;
}

function place(slots, kinds, id, cell) {
    if (!kinds?.[id] || !Number.isInteger(cell) || cell < 0 || cell > 8) return null;
    const out = copy(slots);
    const old = cellsOf(out, id);
    for (const c of old) out[c] = null;

    const at = anchorOf(cell, spanOf(kinds, id));
    const row = Math.floor(at / 3), col = at % 3;
    const target = [];
    for (let k = 0; k < spanOf(kinds, id); k++) target.push(row * 3 + col + k);
    const other = [...new Set(target.map(c => out[c]).filter(v => v !== null))];

    if (other.length === 0) {
        write(out, kinds, id, at);
        return out;
    }
    if (other.length !== 1 || old.length === 0) return null;

    const displaced = other[0];
    for (const c of cellsOf(out, displaced)) out[c] = null;
    const back = old[0];
    if (!canFit(out, kinds, displaced, back)) return null;
    write(out, kinds, displaced, back);
    write(out, kinds, id, at);
    return out;
}

function swap(slots, kinds, a, b) {
    if (a === b) return copy(slots);
    const out = copy(slots);
    const ca = cellsOf(out, a), cb = cellsOf(out, b);
    if (ca.length === 0 || cb.length === 0) return null;
    for (const c of ca.concat(cb)) out[c] = null;
    if (!canFit(out, kinds, b, ca[0]) || !canFit(out, kinds, a, cb[0])) return null;
    write(out, kinds, b, ca[0]);
    write(out, kinds, a, cb[0]);
    return out;
}

function syncWidgets(slots, oldWidgets) {
    const placed = [];
    for (const id of slots ?? []) if (id !== null && !placed.includes(id)) placed.push(id);
    for (const id of oldWidgets ?? []) if (!placed.includes(id)) placed.push(id);
    return placed;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { migrate, cellsOf, firstFit, place, swap, clear, syncWidgets };
}
