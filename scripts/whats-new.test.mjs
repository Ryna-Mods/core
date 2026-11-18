// node --test scripts/whats-new.test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { LUA, SOURCE, parse, refusal, toLua } from "./whats-new.mjs";

const note = (version, items) => ({ version, headline: "A headline.", items });
const text = (notes) => JSON.stringify(notes);

test("the repository's notes are well formed and WhatsNew.lua is current", () => {
  const notes = parse(readFileSync(SOURCE, "utf8"));
  assert.equal(readFileSync(LUA, "utf8").replace(/\r\n/g, "\n"), toLua(notes));
});

test("a note needs a version, a headline, items, and a known place for each", () => {
  const ok = [{ where: "core", text: "A change." }];
  assert.throws(() => parse(text([note("soon", ok)])), /version/);
  assert.throws(() => parse(text([{ version: "1.0.0", headline: " ", items: ok }])), /headline/);
  assert.throws(() => parse(text([note("1.0.0", [])])), /items/);
  assert.throws(() => parse(text([note("1.0.0", [{ where: "elsewhere", text: "x" }])])), /where/);
  assert.throws(() => parse(text([note("1.0.0", [{ where: "core", text: "" }])])), /text/);
  assert.throws(() => parse(text([note("1.0.0", ok), note("1.0.0", ok)])), /second note/);
  assert.throws(() => parse(text([note("1.0.0", ok), note("next", ok)])), /first/);
  assert.equal(parse(text([note("next", ok), note("1.0.0", ok)])).length, 2);
});

test("the game's copy quotes its words for Lua and takes only known places", () => {
  const notes = [note("1.1.0", [{ where: "meter", new: true, text: 'Say "hi" · twice' }, { where: "core", text: "Plain." }])];
  const lua = toLua(notes);
  assert.match(lua, /version = "1\.1\.0"/);
  assert.match(lua, /\{ where = "meter", new = true, text = "Say \\"hi\\" · twice" \}/);
  assert.throws(() => parse(text([note("1.0.0", [{ where: "app", text: "The app's, not the game's." }])])), /where/);
});

test("a release is refused with a note still marked next; it needs no note of its own", () => {
  const ok = [{ where: "core", text: "A change." }];
  assert.match(refusal([note("next", ok)], "1.0.0"), /"next"/);
  assert.equal(refusal([note("0.9.0", ok)], "1.0.0"), null);
  assert.equal(refusal([note("1.0.0", ok), note("0.9.0", ok)], "1.0.0"), null);
  assert.match(refusal([note("0.9.0", ok)], ""), /isn't a release number/);
});
