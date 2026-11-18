-- The move from the folder Ryna to Ryna_Core (Init.lua, Core.lua, Panel.lua) against the fake client.
-- From the repository root, with Lua 5.1 (what the game runs) or later:
--
--   lua5.1 test/legacy_test.lua
--
-- It proves: with the old folder not loaded nothing is done or asked; with it loaded the mod API and
-- RynaDB are this addon's again, the old one is turned off in the game's addon list, the reload is
-- offered in a dialog and never in chat, and what's new waits for it; the old name's blocked calls
-- still count as ours; the Mods tab lists the mods and never this addon; a mod whose TOC asks for a
-- newer core API says so there.
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

-- One login of the core alone. `legacy`: the old folder loaded too, and after this addon its saved
-- file and its API table are the ones in the globals, as the client leaves them.
local function login(legacy)
  for i = #F.frames, 1, -1 do F.frames[i] = nil end
  F.Install()
  _G.UnitGUID = function(unit) if unit == "player" then return "Player-1-0000000A" end end
  _G.UnitName = function(unit) if unit == "player" then return "Dela" end end
  local disabled, shown = {}, {}
  local addons = {
    { "Ryna_Core", "Ryna Core" }, { "Ryna_Chronicle", "Chronicle by Ryna", api = "2" },
    { "Ryna_Future", "Future by Ryna", api = "3" }, { "HealBot", "HealBot" },
  }
  _G.C_AddOns = {
    GetAddOnMetadata = function(name, field)
      if field == "Version" then return "9.9.9" end
      for _, a in ipairs(addons) do if a[1] == name and field == "X-Ryna-API" then return a.api end end
    end,
    IsAddOnLoaded = function(name) return name == "Ryna_Core" or (legacy and name == "Ryna") or false end,
    DisableAddOn = function(name) disabled[#disabled + 1] = name end,
    GetNumAddOns = function() return #addons end,
    GetAddOnInfo = function(i) return addons[i][1], addons[i][2], "notes" end,
  }
  _G.StaticPopup_Show = function(which) shown[#shown + 1] = which; return true end
  _G.ReloadUI = function() end
  _G.RynaDB = { schema = 1, settings = {}, journal = {}, characters = {}, newsSeen = "9.9.9", mine = true }
  local core = {}
  F.LoadAddon(CORE, "Ryna_Core", core)
  F.Fire("ADDON_LOADED", "Ryna_Core")
  local own = _G.Ryna
  local old
  if legacy then
    old = { schema = 1, settings = {}, journal = {}, characters = { kept = {} }, newsSeen = "9.9.9" }
    _G.RynaDB = old
    _G.Ryna = { API = 1 }
  end
  F.Fire("PLAYER_LOGIN")
  F.DropTimers()
  return core, { disabled = disabled, shown = shown, own = own, old = old }
end

local core, did = login(false)
check(not core.legacy, "no old folder: nothing to finish")
eq(#did.disabled, 0, "no old folder: nothing turned off")
eq(#did.shown, 0, "no old folder: no dialog")
check(core.db.mine, "no old folder: this folder's saved file is RynaDB")
eq(_G.Ryna.API, 2, "the mod API's level")
eq(core.API_LEVEL, 2, "the level the Mods tab compares with")
eq(_G.Ryna.API_MIN, 2, "the lowest level the core still serves")
eq(core.API_MIN, 2, "the lowest level the Mods tab compares with")

-- Whose blocked call it is: this addon under either name, and a mod by its prefix.
check(core.IsOwnAddon("Ryna_Core"), "the core is ours")
check(core.IsOwnAddon("Ryna"), "the core under its old folder's name is ours")
check(core.IsOwnAddon("Ryna_Chronicle"), "a mod is ours by its name")
check(not core.IsOwnAddon("Rynamite") and not core.IsOwnAddon("HealBot"), "another addon is not ours")

-- The Mods tab: the mods, never this addon; and the level each asks for.
local names = {}
local future
for _, m in ipairs(core.Panel.ModAddons()) do
  names[#names + 1] = m.name
  if m.name == "Ryna_Future" then future = m end
end
eq(table.concat(names, ","), "Ryna_Chronicle,Ryna_Future", "the Mods tab lists the mods, not the core")
eq(future and future.api, 3, "a mod's level is its TOC's")
check(#F.chat == 0, "nothing in chat: " .. table.concat(F.chat, " / "))
eq(core.errors.count, 0, "no errors caught: " .. tostring(core.errors.last))

core, did = login(true)
check(core.legacy, "the old folder loaded: noted")
eq(table.concat(did.disabled, ","), "Ryna", "the old folder is turned off in the game's addon list")
check(_G.Ryna == did.own, "the mod API is this addon's again")
check(core.db == did.old and _G.RynaDB == did.old, "RynaDB is the one the client will save")
check(core.db.characters.kept ~= nil, "what the old folder's file held came along")
eq(table.concat(did.shown, ","), "RYNA_LEGACY_RELOAD", "the reload is offered, and what's new waits for it")
check(type(_G.StaticPopupDialogs.RYNA_LEGACY_RELOAD.text) == "string", "the dialog has its words")
check(#F.chat == 0, "nothing in chat: " .. table.concat(F.chat, " / "))
eq(core.errors.count, 0, "no errors caught: " .. tostring(core.errors.last))

print(string.format("legacy: %d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
