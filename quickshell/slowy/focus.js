// pure duration parsing shared by Focus.qml and the Node test. Hours in, whole minutes out.
"use strict";

function hoursToMinutes(value, fallback) {
    const h = Number.parseFloat(value);
    if (!Number.isFinite(h) || h <= 0) return fallback;
    return Math.max(1, Math.min(24 * 60, Math.round(h * 60)));
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { hoursToMinutes };
}
