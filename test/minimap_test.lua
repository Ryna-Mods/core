-- The minimap button's menu (Minimap.lua) against the fake client, with the core addon alone.
-- From the repository root, with Lua 5.1 (what the game runs) or later:
--
--   lua5.1 test/minimap_test.lua
--
-- It proves: the menu's rows (the version, the window's sections, what mods added in their order, what's
-- new, Settings last); a mod's entry needs a label and something to run; a click opens the client's
-- menu with a button per row and a tick box for an entry with `checked`; picking a row does its thing;
-- on a client without menus a click opens Settings as before; nothing in chat, no errors.
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

F.Install()
_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-0000000A" end end
_G.UnitName = function(unit) if unit == "player" then return "Dela" end end
_G.C_AddOns = { GetAddOnMetadata = function() return "9.9.9" end }
_G.RynaDB = { schema = 1, settings = {}, journal = {}, characters = {}, newsSeen = "9.9.9" }

local core = {}
F.LoadAddon(CORE, "Ryna_Core", core)
core.NEWS = { { version = "9.9.9", headline = "A headline.", items = { { where = "core", text = "A change." } } } }
F.Fire("ADDON_LOADED", "Ryna_Core")
F.Fire("PLAYER_LOGIN")
F.DropTimers()

local M, R = core.Minimap, _G.Ryna
check(M.button ~= nil, "the button was made")

-- What was opened, in place of the real things.
local did = {}
core.Window.List = function() return { { key = "characters", group = "me", label = "Characters" },
  { key = "history", group = "me", label = "History" } } end
core.Window.Open = function(key) did[#did + 1] = "window " .. tostring(key) end
core.Panel.Open = function() did[#did + 1] = "settings" end
core.News.Show = function(note) did[#did + 1] = "news " .. note.version; return true end

local function words(rows)
  local out = {}
  for _, r in ipairs(rows) do
    out[#out + 1] = r.title and ("[" .. r.title .. "]") or (r.divider and "-")
      or (r.checked and ("(" .. r.text .. ")") or r.text)
  end
  return table.concat(out, "|")
end

eq(words(M.Rows()), "[Ryna 9.9.9]|[Open Ryna's window on]|Characters|History|-|What's new|Settings",
  "the menu with no mods' entries")

-- A mod's entries -----------------------------------------------------------------------------------------

check(type(R.Minimap) == "table" and type(R.Minimap.Add) == "function", "mods can add to it")
eq(R.Minimap.Add({ label = "", run = function() end }), false, "an entry needs a label")
eq(R.Minimap.Add({ label = "Nothing" }), false, "and something to run")
local on = true
eq(R.Minimap.Add({ label = "Later", order = 30, run = function() did[#did + 1] = "later" end }), true, "an entry")
R.Minimap.Add({ label = "Meter", order = 20, checked = function() return on end,
  run = function() on = not on end })
eq(words(M.Rows()), "[Ryna 9.9.9]|[Open Ryna's window on]|Characters|History|-|(Meter)|Later|-|What's new|Settings",
  "mods' entries sit between the window and Settings, in their order, a tick box in brackets here")

-- A click ----------------------------------------------------------------------------------------------

local made
_G.MenuUtil = { CreateContextMenu = function(owner, build)
  made = { owner = owner, titles = 0, dividers = 0, buttons = {}, boxes = {} }
  build(owner, {
    CreateTitle = function() made.titles = made.titles + 1 end,
    CreateDivider = function() made.dividers = made.dividers + 1 end,
    CreateButton = function(_, text, pick) made.buttons[#made.buttons + 1] = { text = text, pick = pick } end,
    CreateCheckbox = function(_, text, isOn, pick)
      made.boxes[#made.boxes + 1] = { text = text, isOn = isOn, pick = pick }
    end,
  })
end }
F.Click(M.button, "LeftButton")
check(made and made.owner == M.button, "a click opens the client's menu at the button")
eq(made.titles, 2, "its two headings")
eq(made.dividers, 2, "its two dividers")
eq(#made.buttons, 5, "a button per plain row")
eq(#made.boxes, 1, "a tick box for the entry that can be on or off")
eq(made.boxes[1].isOn(), true, "the tick box shows what the mod says")
made.boxes[1].pick()
eq(made.boxes[1].isOn(), false, "and ticking it runs the mod's entry")
made.buttons[1].pick()
made.buttons[3].pick()
made.buttons[4].pick()
made.buttons[5].pick()
eq(table.concat(did, ", "), "window characters, later, news 9.9.9, settings", "each row does its thing")
made = nil
F.Click(M.button, "RightButton")
check(made ~= nil, "a right-click opens it too")

-- A client without menus: Settings, as before -------------------------------------------------------

_G.MenuUtil = nil
did = {}
F.Click(M.button, "LeftButton")
eq(table.concat(did, ", "), "settings", "no menus in the client: a click opens Settings")
core.NEWS = {}
check(not words(M.Rows()):find("What's new", 1, true), "no note at all: no What's new row")

check(#F.chat == 0, "nothing in chat: " .. table.concat(F.chat, " / "))
eq(core.errors.count, 0, "no errors caught: " .. tostring(core.errors.last))
print(string.format("minimap: %d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
