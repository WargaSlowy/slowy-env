"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { hoursToMinutes } = require("./focus.js");

test("hoursToMinutes converts decimal hours to minutes", () => {
    assert.equal(hoursToMinutes(1.5, 25), 90);
    assert.equal(hoursToMinutes("0.25", 25), 15);
});

test("hoursToMinutes uses the fallback for empty or invalid input", () => {
    assert.equal(hoursToMinutes("", 25), 25);
    assert.equal(hoursToMinutes("abc", 25), 25);
    assert.equal(hoursToMinutes(-1, 25), 25);
});

test("hoursToMinutes clamps to one minute and twenty four hours", () => {
    assert.equal(hoursToMinutes(0.001, 25), 1);
    assert.equal(hoursToMinutes(99, 25), 1440);
});

test("home widget adjusts durations without keyboard focus", () => {
    const home = fs.readFileSync(path.join(__dirname, "home/Home.qml"), "utf8");
    assert.ok(!home.includes("TextInput"), "home is a bottom layer with keyboardFocus None, so typing cannot work there");
    assert.ok(home.includes("setFocusHours(") && home.includes("setBreakHours("));
    assert.ok(home.includes("Focus.toggle()") && home.includes("Focus.reset()"), "home tile needs play and reset buttons");
});
