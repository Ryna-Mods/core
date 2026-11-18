#!/usr/bin/env node
// The addon's version and its API levels, read from its TOC (the one place the version is written),
// with the levels held to what the game reads (Mods.lua), and the version to the tag when there is one.
//
//   node scripts/version.mjs [--tag vX.Y.Z]     prints version=X.Y.Z, api=N and apiMin=N
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const read = (file) => readFileSync(join(root, "Ryna_Core", file), "utf8");
const toc = read("Ryna_Core.toc");
const field = (key) => new RegExp(`^## ${key}:\\s*(\\S+)\\s*$`, "m").exec(toc)?.[1];
const version = field("Version");
const api = field("X-Ryna-API");
const apiMin = field("X-Ryna-API-Min");
if (!/^\d+\.\d+\.\d+$/.test(version ?? "")) throw new Error(`the TOC's version isn't X.Y.Z (${version})`);
if (!/^[1-9]\d*$/.test(api ?? "")) throw new Error(`the TOC's X-Ryna-API isn't a level (${api})`);
if (!/^[1-9]\d*$/.test(apiMin ?? "")) throw new Error(`the TOC's X-Ryna-API-Min isn't a level (${apiMin})`);
if (Number(apiMin) > Number(api)) throw new Error(`the lowest level served (${apiMin}) is above the level (${api})`);
if (/^## Dependencies:/m.test(toc)) throw new Error("the core depends on no other addon");
// A mod reads the levels from the core's table in the game; the TOC is what the Ryna app and the
// bundle read. By line, never by "\n": a Windows checkout has CRLF endings.
const lines = read("Mods.lua").split(/\r?\n/);
if (!lines.includes(`R.API = ${api}`)) throw new Error(`Mods.lua's R.API isn't the TOC's X-Ryna-API (${api})`);
if (!lines.includes(`R.API_MIN = ${apiMin}`)) throw new Error(`Mods.lua's R.API_MIN isn't the TOC's X-Ryna-API-Min (${apiMin})`);
// No Lua carries the version: the addon reads its TOC in the game, and a second copy goes stale.
const tocFiles = toc.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.endsWith(".lua"));
for (const file of tocFiles) {
  if (/^[ \t]*ns\.VERSION\s*=\s*["']/m.test(read(file.replaceAll("\\", "/")))) throw new Error(`${file} carries a version of its own`);
}
const at = process.argv.indexOf("--tag");
if (at > 0) {
  if (process.argv[at + 1] !== `v${version}`) throw new Error(`the tag is ${process.argv[at + 1]}, the TOC says ${version}`);
  // 0.5.0 was released from ryna_agent, with every other addon; this repository's line starts after it.
  const [a, b, c] = version.split(".").map(Number);
  if (a * 1e6 + b * 1e3 + c <= 5000) throw new Error(`${version} is already released (from ryna_agent); the first here is 0.5.1`);
}
console.log(`version=${version}\napi=${api}\napiMin=${apiMin}`);
