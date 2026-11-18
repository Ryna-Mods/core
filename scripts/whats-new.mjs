#!/usr/bin/env node
// What's new: the note a player sees once in the game after an update (a popup at login; News.lua).
// The words are written by hand in whats-new.json at the repository root, newest release first; this
// script makes Ryna_Core/WhatsNew.lua from it (no dependencies; Node 18+). From the repository root:
//
//   node scripts/whats-new.mjs                  write WhatsNew.lua
//   node scripts/whats-new.mjs --check          exit 1 when it isn't what the file makes (CI)
//   node scripts/whats-new.mjs --require 0.5.1  exit 1 when a note is still marked "next", or the
//                                               file is stale (the release workflow)
//
// A note: { version, headline, items: [{ where, text, new? }] }. `version` is this addon's ("0.5.1"),
// or "next" while the release has no number yet: rename it in the change that sets the version.
// A release needs no note: the popup shows only on a version that has one.
// `where` says whose change it is: "core", or a mod's id. The notes up to 0.5.0 carry the mods'
// changes too, from when every addon shared a release; from here a mod brings its own notes, and a
// new note here is the core's alone. `new` marks the item that introduces a mod.
//
// This is ryna_agent's scripts/whats-new.mjs, without the app's copy.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
export const SOURCE = join(ROOT, "whats-new.json");
export const LUA = join(ROOT, "Ryna_Core", "WhatsNew.lua");

// Where a change can be. The game shows them all.
export const WHERE = { core: true, chronicle: true, automation: true, prices: true, fights: true, meter: true };
const VERSION = /^\d+\.\d+\.\d+$/;

/** The notes, checked. Throws an Error naming the first thing wrong. */
export function parse(text) {
  const notes = JSON.parse(text);
  if (!Array.isArray(notes)) throw new Error("whats-new.json must be a list of notes");
  const seen = new Set();
  notes.forEach((n, i) => {
    const at = `note ${i + 1}`;
    if (typeof n.version !== "string" || !(n.version === "next" || VERSION.test(n.version))) {
      throw new Error(`${at}: version must be a release number or "next"`);
    }
    if (seen.has(n.version)) throw new Error(`${at}: a second note for ${n.version}`);
    seen.add(n.version);
    if (n.version === "next" && i !== 0) throw new Error(`${at}: "next" must be the first note`);
    if (typeof n.headline !== "string" || !n.headline.trim()) throw new Error(`${at}: no headline`);
    if (!Array.isArray(n.items) || n.items.length === 0) throw new Error(`${at}: no items`);
    n.items.forEach((it, j) => {
      const here = `${at}, item ${j + 1}`;
      if (!(it.where in WHERE)) throw new Error(`${here}: unknown "where" ${JSON.stringify(it.where)}`);
      if (typeof it.text !== "string" || !it.text.trim()) throw new Error(`${here}: no text`);
      if (it.new !== undefined && typeof it.new !== "boolean") throw new Error(`${here}: "new" must be true or false`);
    });
  });
  return notes;
}

const luaString = (s) => JSON.stringify(s).replace(/\\u([0-9a-f]{4})/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)));

/** The game's copy: the notes with something the game shows, as a Lua table on the core's namespace. */
export function toLua(notes) {
  const out = [
    "-- WhatsNew: the notes News.lua shows after an update. Written by scripts/whats-new.mjs from",
    "-- whats-new.json at the repository root: change that file and run the script, never this one.",
    "-- luacheck: ignore 631",
    "",
    "local _, ns = ...",
    "",
    "ns.NEWS = {",
  ];
  for (const n of notes) {
    const items = n.items.filter((it) => WHERE[it.where]);
    if (items.length === 0) continue;
    out.push("  {", `    version = ${luaString(n.version)},`, `    headline = ${luaString(n.headline)},`, "    items = {");
    for (const it of items) {
      out.push(`      { where = ${luaString(it.where)},${it.new ? " new = true," : ""} text = ${luaString(it.text)} },`);
    }
    out.push("    },", "  },");
  }
  out.push("}", "");
  return out.join("\n");
}

/** Why a release can't go out with these notes, or null. */
export function refusal(notes, version) {
  if (notes.some((n) => n.version === "next")) {
    return `whats-new.json still has a note marked "next": name it ${version} (or remove it).`;
  }
  if (!/^\d+\.\d+\.\d+$/.test(version)) return `${version || "(nothing)"} isn't a release number.`;
  return null;
}

function main(argv) {
  const notes = parse(readFileSync(SOURCE, "utf8"));
  const made = [[LUA, toLua(notes)]];
  const need = argv.indexOf("--require");
  if (need >= 0) {
    const why = refusal(notes, argv[need + 1] ?? "");
    if (why) {
      console.error(why);
      return 1;
    }
  }
  if (argv.includes("--check") || need >= 0) {
    let stale = false;
    for (const [path, text] of made) {
      let have = "";
      try { have = readFileSync(path, "utf8"); } catch { /* missing counts as stale */ }
      if (have.replace(/\r\n/g, "\n") !== text) {
        console.error(`${path} isn't what whats-new.json makes: run node scripts/whats-new.mjs`);
        stale = true;
      }
    }
    if (stale) return 1;
    console.log(`whats-new: ${notes.length} note${notes.length === 1 ? "" : "s"}, WhatsNew.lua current`);
    return 0;
  }
  for (const [path, text] of made) writeFileSync(path, text);
  console.log(`whats-new: wrote WhatsNew.lua from ${notes.length} note${notes.length === 1 ? "" : "s"}`);
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    process.exit(main(process.argv.slice(2)));
  } catch (e) {
    console.error(`whats-new: ${e.message}`);
    process.exit(1);
  }
}
