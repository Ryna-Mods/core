# Ryna Core

The base addon of [Ryna](https://github.com/Ryna-Mods/ryna) for World of Warcraft: Forever. Every
Ryna mod builds on it:

- **Ryna's window** (`/ryna`), its minimap button and the settings panel, which the mods add their
  own sections and tabs to.
- **The saved data** (`RynaDB`) and the journal the mods record into.
- **The mod API** (`Ryna`): what a mod registers with, and the level it asks for.
- **What's new**: a note once after an update, never in chat and never during a fight.

On its own it records nothing; the mods do the work (Chronicle, Meter, Prices, Automation, Fights).
It prints nothing unasked.

## Installing

- **With the Ryna app** ([download](https://github.com/MaddisonM79/ryna_agent/releases/latest)),
  which installs Ryna Core and the mods you turn on, and keeps them up to date.
- **The bundle**: every Ryna addon in one zip, from
  [Ryna-Mods/ryna](https://github.com/Ryna-Mods/ryna/releases/latest).
- **By hand**: this repository's releases hold `Ryna_Core-<version>.zip`; unzip it into
  `Interface/AddOns`.

## Working on it

`Ryna_Core/` is the addon. Its tests (`test/`) run it against a fake client
(`test/fake_client.lua`).

```bash
scripts/check.sh
```

That is everything CI runs: the version and levels, the notes, luacheck, the strings
(`tools/strings.mjs`: every string the code uses is in `Locales/enUS.lua` and in each locale's
template) and the tests. It needs Lua (5.1 is what the game runs),
[luacheck](https://github.com/lunarmodules/luacheck) and Node.

- **The version** is `## Version` in [`Ryna_Core.toc`](Ryna_Core/Ryna_Core.toc), and nowhere else.
- **The mod API's level** is `## X-Ryna-API` there, and the lowest level still served is
  `## X-Ryna-API-Min`. `Mods.lua` says the same two numbers to the mods in the game
  (`R.API`, `R.API_MIN`), and the check holds them together. A change that could break a mod raises
  the level; dropping support for old mods raises the lowest.
- **What's new** is written in [`whats-new.json`](whats-new.json); `node scripts/whats-new.mjs`
  makes `Ryna_Core/WhatsNew.lua` from it. A release needs no note: the popup shows only on a version
  that has one.
- **Files the Ryna app writes** into an installed copy (`AgentStatus.lua`, `Data/*.lua`) are here as
  shipped: empty.

A release is a signed tag `vX.Y.Z` that matches the TOC; the bundle then names that release in its
`bundle.json` ([how](https://github.com/Ryna-Mods/ryna/blob/main/RELEASING.md)).

## Where it came from

Ryna Core was written in [MaddisonM79/ryna_agent](https://github.com/MaddisonM79/ryna_agent)
(`cores/wow/addon`), and its history up to 0.5.0 is there. Bugs and requests go to
[ryna_agent's issues](https://github.com/MaddisonM79/ryna_agent/issues).

## Licence

MIT.
