-- The journal's prune at login (Journal.lua's J.Prune): what stays for 30 days, and the bulky types
-- that go as soon as the companion app has uploaded them (J.SHORT_LIVED), against the app's
-- AgentStatus as it writes it. From the repository root, with Lua 5.1 (what the game runs) or later:
--
--   lua5.1 test/journal_test.lua
-- luacheck: ignore 1

local CORE = "Ryna_Core/"

local failures, checks = 0, 0
local function eq(got, want, what)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    print("FAIL: " .. what .. ": got " .. tostring(got) .. ", want " .. tostring(want))
  end
end

local NOW = 1800000000
local DAY = 86400
_G.time = function() return NOW end
_G.GetServerTime = _G.time
_G.date = os.date
_G.GetLocale = function() return "enUS" end
_G.CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end
_G.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
_G.C_Timer = { After = function() end }

local ns = {}
for _, file in ipairs({ "Core.lua", "Journal.lua" }) do
  assert(loadfile(CORE .. file))("Ryna_Core", ns)
end
local J = ns.Journal

local ACCOUNT = "acct-1"
local function event(kind, age, seq)
  return { session = "s", seq = seq, at = NOW - age, char = "Player-1-0A", type = kind }
end
local function count(kind)
  local n = 0
  for _, e in ipairs(ns.db.journal) do
    if e.type == kind then n = n + 1 end
  end
  return n
end
-- A login with these events saved and the app having uploaded everything up to `through` ago.
local function login(events, through)
  ns.db = { meta = { accountId = ACCOUNT }, journal = events }
  _G.RynaAgentStatus = through and { accounts = { { accountId = ACCOUNT, journalThrough = NOW - through } } } or nil
  J.Prune()
end

local function mixed()
  return {
    event("seen", 20 * DAY, 1), event("questDone", 20 * DAY, 2), event("seen", 2 * DAY, 3),
    event("seen", 3600, 4), event("auction", 2 * DAY, 5), event("zone", 3600, 6), event("seen", 60, 7),
    event("session", 31 * DAY, 8),
  }
end

-- The app has uploaded everything up to an hour ago: every sighting it has is dropped, the one from
-- a minute ago stays for the next upload, and what the game shows back (quests, zones) is untouched.
login(mixed(), 3600)
eq(count("seen"), 1, "uploaded sightings are dropped, the one not yet uploaded is kept")
eq(ns.db.journal[#ns.db.journal].seq, 7, "the kept sighting is the newest")
eq(count("auction"), 0, "an uploaded auction snapshot is dropped, as before")
eq(count("questDone"), 1, "an uploaded quest stays: the game reads it back")
eq(count("zone"), 1, "an uploaded zone change stays")
eq(count("session"), 0, "anything older than 30 days goes, whatever it is")

-- The app has never uploaded (no status file, or another account's): sightings wait three days for
-- it and no longer, so a save can't grow without bound while the app is away.
login(mixed(), nil)
eq(count("seen"), 3, "with no upload, only sightings past three days are dropped")
eq(count("questDone"), 1, "with no upload, a quest still stays its 30 days")
ns.db = { meta = { accountId = "someone-else" }, journal = mixed() }
_G.RynaAgentStatus = { accounts = { { accountId = ACCOUNT, journalThrough = NOW } } }
J.Prune()
eq(count("seen"), 3, "another account's upload says nothing about this one's sightings")

-- A save the size of the one that stopped syncing: 58,000 uploaded sightings and a day's play.
local big = {}
for i = 1, 58000 do big[#big + 1] = event("seen", 2 * DAY + i, i) end
for i = 1, 300 do big[#big + 1] = event("questDone", i, 58000 + i) end
for i = 1, 40 do big[#big + 1] = event("seen", i, 58300 + i) end
login(big, 600)
eq(#ns.db.journal, 340, "58,000 uploaded sightings go and the rest stays")
eq(count("seen"), 40, "the sightings since the last upload wait for the next one")

-- What a mod asks before leaning on this (Mods.lua's ShortLived) is still a table with both.
eq(type(J.SHORT_LIVED), "table", "SHORT_LIVED is a table")
eq(J.SHORT_LIVED.seen, 3 * DAY, "a sighting waits at most three days for an upload")
eq(J.SHORT_LIVED.auction, 3 * DAY, "an auction snapshot's limit is unchanged")

if failures > 0 then
  print(failures .. " of " .. checks .. " checks failed")
  os.exit(1)
end
print("journal_test: " .. checks .. " checks passed")
