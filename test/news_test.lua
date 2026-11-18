-- What's new (News.lua) against the fake client, with the core addon and made-up notes.
-- From the repository root, with Lua 5.1 (what the game runs) or later:
--
--   lua5.1 test/news_test.lua
--
-- It proves: the groups a note makes (a mod that is on, one that isn't but is introduced, one that
-- isn't and is only changed, the core's last); the popup at the first login after an update, once, with
-- the version, headline and body; closing marks it seen; nothing on a new install, with the setting
-- off, for a version with no note, or twice; it waits out a fight; /ryna news whenever asked; the
-- notes shipped with the addon are well formed; nothing in chat unasked, no errors.
-- luacheck: ignore 1

local CORE = "Ryna_Core/"
local F = dofile("test/fake_client.lua")

local failures, checks = 0, 0
local function check(cond, what)
  checks = checks + 1
  if not cond then
    failures = failures + 1
    print("FAIL: " .. what)
  end
end
local function eq(got, want, what)
  check(got == want, what .. ": got " .. tostring(got) .. ", want " .. tostring(want))
end

local NOTES = {
  { version = "9.9.9", headline = "A headline.", items = {
    { where = "meter", new = true, text = "A live meter." },
    { where = "meter", text = "A threat bar." },
    { where = "prices", text = "A price fix." },
    { where = "chronicle", text = "A record fix." },
    { where = "core", text = "A core change." },
  } },
}

-- One login: the saved table (nil for a new install), the version, and what the client says of combat.
local function login(saved, opts)
  opts = opts or {}
  for i = #F.frames, 1, -1 do F.frames[i] = nil end
  F.Install()
  _G.UnitGUID = function(unit) if unit == "player" then return "Player-1-0000000A" end end
  _G.UnitName = function(unit) if unit == "player" then return "Dela" end end
  _G.C_AddOns = { GetAddOnMetadata = function() return opts.version or "9.9.9" end }
  _G.InCombatLockdown = function() return opts.fighting or false end
  _G.RynaNews, _G.RynaVersionNotice = nil, nil
  _G.RynaDB = saved
  local core = {}
  F.LoadAddon(CORE, "Ryna_Core", core)
  local shipped = core.NEWS
  core.NEWS = opts.notes or NOTES
  if opts.mods then
    for _, id in ipairs(opts.mods) do _G.Ryna.RegisterMod({ id = id, name = id }) end
  end
  F.Fire("ADDON_LOADED", "Ryna_Core")
  F.Fire("PLAYER_LOGIN")
  F.DropTimers()
  return core, shipped
end
local function old() return { schema = 1, settings = {}, journal = {}, characters = {} } end

-- The notes shipped with the addon ---------------------------------------------------------------------

local _, shipped = login(old())
local core
check(type(shipped) == "table" and #shipped >= 1, "the addon ships notes")
for _, note in ipairs(shipped) do
  check(type(note.version) == "string" and type(note.headline) == "string" and #note.items >= 1,
    "a shipped note has a version, a headline and items")
end

-- The groups ---------------------------------------------------------------------------------------------

core = login(old(), { mods = { "chronicle" } })
local N = core.News
local groups = N.Groups(NOTES[1])
eq(#groups, 3, "a mod that is off and only changed (prices) is left out")
eq(groups[1].heading, "Meter by Ryna", "a mod the note introduces is shown though it is off")
eq(groups[1].hint, "new mod: turn it on in the Ryna app", "with how to get it")
eq(#groups[1].lines, 2, "and all its lines")
eq(groups[2].heading, "Chronicle by Ryna", "a mod that is on shows its changes")
eq(groups[2].hint, nil, "with no hint")
eq(groups[3].heading, "Everywhere", "the core's come last")
core = login(old(), { mods = { "meter" } })
eq(core.News.Groups(NOTES[1])[1].hint, "new", "a new mod already on is just marked new")

-- The first login after an update -------------------------------------------------------------------

core = login(old(), { mods = { "chronicle" } })
N = core.News
local f = N.frame
check(f ~= nil and f:IsShown(), "an existing account on a version with a note: the popup")
eq(f.title._text, "What's new in Ryna 9.9.9", "its title names the version")
eq(f.headline._text, "A headline.", "its headline")
local wanted = "Meter by Ryna  new mod: turn it on in the Ryna app\n  • A live meter."
check(F.Plain(f.body._text):find(wanted, 1, true) ~= nil,
  "its body: a heading, its hint and a bullet per change")
check(not F.Plain(f.body._text):find("A price fix", 1, true), "without what isn't this player's")
eq(_G.RynaDB.newsSeen, nil, "not seen until it is closed")
F.Click(f.close)
check(not f:IsShown(), "the button closes it")
eq(_G.RynaDB.newsSeen, "9.9.9", "and it is marked seen")
check(#F.chat == 0, "nothing in chat: " .. table.concat(F.chat, " / "))

-- Not again; not on a new install; not with the setting off; not without a note -------------------

local saved = old()
saved.newsSeen = "9.9.9"
core = login(saved)
check(core.News.frame == nil, "seen already: nothing")
core = login(nil)
check(core.News.frame == nil, "a new install: nothing, since nothing is new")
eq(_G.RynaDB.newsSeen, "9.9.9", "and this version is marked seen for it")
saved = old()
saved.settings.newsPopup = false
core = login(saved)
check(core.News.frame == nil, "the setting off: nothing")
eq(_G.RynaDB.newsSeen, nil, "and not marked seen, so turning it on shows it")
saved = old()
saved.newsSeen = "9.9.8"
core = login(saved, { version = "9.9.10" })
check(core.News.frame == nil, "a version with no note: nothing")

-- It waits out a fight -----------------------------------------------------------------------------------

core = login(old(), { fighting = true })
check(core.News.frame == nil, "logging in mid-fight: not yet")
F.Fire("PLAYER_REGEN_ENABLED")
check(core.News.frame ~= nil and core.News.frame:IsShown(), "shown when the fight ends")
core.News.frame:Hide()
F.Fire("PLAYER_REGEN_ENABLED")
check(not core.News.frame:IsShown(), "and only once")

-- /ryna news -------------------------------------------------------------------------------------------

saved = old()
saved.newsSeen = "9.9.9"
core = login(saved)
_G.SlashCmdList.RYNA("news")
check(core.News.frame ~= nil and core.News.frame:IsShown(), "/ryna news shows it though it was seen")
check(#F.chat == 0, "and says nothing in chat when it can show it")
core = login(old(), { version = "1.2.3", notes = { { version = "next", headline = "Soon.", items = {
  { where = "core", text = "A change." } } } } })
check(core.News.frame == nil, "a note still marked next is no login popup")
_G.SlashCmdList.RYNA("news")
eq(core.News.frame.title._text, "What's new in Ryna 1.2.3", "but /ryna news shows it, under the version running")
core = login(old(), { notes = {} })
_G.SlashCmdList.RYNA("news")
eq(#F.chat, 1, "with no notes at all, the command says so")

eq(core.errors.count, 0, "no errors caught: " .. tostring(core.errors.last))
print(string.format("news: %d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
