// credits.json is the list of people thanked, as in ryna_agent (whose About tab and CREDITS.md carry
// the same list); this holds the addon's Credits.lua to it. node --test scripts/credits.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => readFileSync(join(ROOT, p), "utf8");
const credits = JSON.parse(read("credits.json"));

/** `text` as it's written inside a double-quoted Lua string: backslashes first, then quotes. */
const luaQuoted = (text) => text.replace(/\\/g, "\\\\").replace(/"/g, '\\"');

test("a credits line is quoted for Lua the way Lua reads it back", () => {
  assert.equal(luaQuoted('say "hi"'), 'say \\"hi\\"');
  assert.equal(luaQuoted("a\\b"), "a\\\\b");
  assert.equal(luaQuoted('\\"'), '\\\\\\"');
});

test("credits.json has names, roles and lines", () => {
  assert.ok(credits.length >= 1);
  for (const c of credits) {
    assert.match(c.name, /\S/);
    assert.match(c.role, /\S/);
    assert.match(c.line, /\S/);
  }
});

test("the addon's Credits.lua carries every name and line", () => {
  const lua = read("Ryna_Core/Credits.lua");
  for (const c of credits) {
    assert.ok(lua.includes(c.name), `Credits.lua lacks ${c.name}`);
    // The game's fonts have no beer glyph: the Lua copy says Cheers! instead.
    const luaLine = luaQuoted(c.line.replace("🍻", "Cheers!"));
    assert.ok(lua.includes(luaLine), `Credits.lua lacks ${c.name}'s line`);
  }
});
