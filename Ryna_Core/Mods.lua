-- Mods: the mod API, the one global this addon defines for other addons (`Ryna`), and the registry of
-- the mods that use it. A mod is its own addon folder (`Ryna_<Name>`, `## Dependencies: Ryna_Core`) that
-- the companion app installs beside this one (docs/ryna-agent-cores-mods.md section 6). Chronicle,
-- everything recorded about a character, is the first (mods/wow/chronicle). A mod reaches the core
-- only through this table, never through the core's private namespace, so the core can change
-- inside without breaking one.
--
-- Ryna.API is the level of this surface, a whole number. A mod's TOC says the level it needs
-- (## X-Ryna-API) and its Mod.lua loads nothing on a core below it; the Mods tab says so. The rule:
-- a change here that an existing mod could break on (something removed, renamed or made to behave
-- differently) raises the number, and an addition a mod must have raises it too, so "needs level N"
-- is the whole of what a mod says about the core. Level 1 was the surface through 0.4.4, in the
-- folder Ryna. Level 2 is the same surface in the folder Ryna_Core (0.5.0): a mod's
-- `## Dependencies` names the folder, so no level 1 mod loads against this core. The surface (API 2):
--
--   Ryna.API, Ryna.VERSION            the API's level (2) and the core addon's version
--   Ryna.RegisterMod(spec)            { id, addon, name, version, onLogin, onLogout, onDefaults } -> true
--                                     onLogin runs at PLAYER_LOGIN after RynaDB is set up and the
--                                     journal session has started; onLogout at PLAYER_LOGOUT;
--                                     onDefaults after the panel's Defaults button reset the settings
--   Ryna.Mods()                       the registered mods, in the order they registered
--   Ryna.On(event, fn)                the event dispatcher: fn(event, ...) under pcall
--   Ryna.DB()                         RynaDB (nil before the client loads it). A mod writes only
--                                     under its own key (RynaDB[<mod id>]) or in the character
--                                     record it keeps; Chronicle, the first mod, keeps the keys
--                                     the companion app reads (characters, guilds, client)
--   Ryna.Journal.Add(type, fields, quiet), .Session(), .Seq(), .Count(), .Events(type) (that type's
--                                     events, read only), .Remove(type, drop) (drops those drop(e)
--                                     is true for), .ShortLived (bulky types leave once uploaded)
--   Ryna.Settings.Get(key), .Set(key, value), .All(), .AddDefaults(defaults), .COMBAT_LOG_MODES
--   Ryna.Panel.AddTab{ key, label, order, build(frame), layout(stack, settings) }
--   Ryna.Panel.AddStatusLines(order, fn)   fn() -> lines for the Status tab, at `order`
--   Ryna.Panel.Refresh(), .RefreshIfShown(), .Widgets (text, button, link, checkbox, toggle, WIDTH)
--   Ryna.Slash.Add{ word, run(arg, rest), help, order }   a /ryna <word> command and its help line;
--                                     arg is the next word, rest the whole line after <word>
--                                     (cores after 0.3.4; 0.3.4 passes arg only)
--   Ryna.Slash.AddStatusLines(order, fn)   fn() -> lines for /ryna status, at `order`
--   Ryna.Window.AddSection(spec)      a section of Ryna's one window (Window.lua has the spec), and
--                                     .Open(key), .Toggle(key), .Hide(), .IsShown(), .Selected(),
--                                     .Refresh(key), .Choose(guid), .Characters(), .Match(text,
--                                     search), .QualityColor(q), .ClassColor(class), .ClassName(class),
--                                     .Money(copper), .ItemIcon(id), .TooltipSection() (cores after
--                                     0.3.9; a mod checks `Ryna.Window` before using it); a "strip"
--                                     column and row.strips, .STRIP_MAX (48) and .StripShare(v) (the
--                                     0..1 a block draws), and a title that is function(ctx) (cores
--                                     after 0.4.2; a mod checks `Ryna.Window.STRIP_MAX`); a section's
--                                     `say` lines and header `buttons`, a strip's `marks`, .MAX_SAY,
--                                     .MAX_BUTTONS and .STRIP_MARKS (cores after 0.4.2; a mod checks
--                                     `Ryna.Window.MAX_SAY`)
--   Ryna.Tooltip.HasLine(tooltip, text), .AddLine(tooltip, text, r, g, b, wrap)   the shared guard:
--                                     a line is never added twice, nor over the same text already
--                                     drawn (cores after 0.3.9)
--   Ryna.Data.Get(name, version)      a data-layer table the companion app wrote (Data.lua): the
--                                     table, or nil and "absent" or "version"; .WrittenAt(t), .Count(t)
--                                     (cores after 0.3.9; a mod checks `Ryna.Data` before using it)
--   Ryna.Minimap.Add{ label, order, run, checked }   an entry in the minimap button's menu: run() on
--                                     a click; `checked`, a function, makes it a tick box (cores
--                                     after 0.4.3; a mod checks `Ryna.Minimap` before using it)
--   Ryna.L                            the core's strings (a mod's own L falls back to it)
--   Ryna.Try, .Fn, .IsSecret, .NonEmpty, .Now, .Locale, .Print, .PrintRaw, .Debug, .DebugChanged,
--   .Debugging, .Plural, .N, .Run, .After, .Debounce, .ReportError, .CanonicalName, .MoneyText,
--   .DurationText, .ListText, .Ago, .Plain   the helpers (Core.lua, Status.lua)
--
-- Order numbers for the shared lists: the core's own Status tab lines are at 30 (journal), 35 (the
-- combat log) and 50 (the companion app), its /ryna status lines at 10 (versions), 30 (journal), 40
-- (the combat log) and 50 (the rest), its tabs at 10 (Status), 40 (Messages), 50 (Mods) and 60
-- (Advanced), its commands at 10 (status), 20 (combatlog) and 40 (debug).

local _, ns = ...

local R = {}
Ryna = R

R.API = 2
-- The lowest level this core still serves: a mod written for a level below it loads nothing (its
-- Mod.lua checks) and the Mods tab says to update the mod. A change that removes or alters
-- something raises both numbers; one that only adds raises R.API alone.
R.API_MIN = 2
ns.API_LEVEL = R.API
ns.API_MIN = R.API_MIN
ns.ModAPI = R
R.VERSION = ns.VERSION
R.L = ns.L

-- The helpers, as they are in Core.lua and Status.lua.
for _, name in ipairs({ "Try", "Fn", "IsSecret", "NonEmpty", "Now", "Locale", "Print", "PrintRaw", "Debug",
  "DebugChanged", "Debugging", "Plural", "N", "Run", "After", "Debounce", "ReportError", "CanonicalName",
  "MoneyText", "DurationText", "ListText", "On" }) do
  R[name] = ns[name]
end
R.Ago = ns.Status.Ago
R.Plain = ns.Status.Plain
R.Data = ns.Data

function R.DB()
  return ns.db
end

-- Mods ------------------------------------------------------------------------------------------

ns.mods, ns.modsById, ns.modsByAddon = {}, {}, {}

function R.RegisterMod(spec)
  if type(spec) ~= "table" or type(spec.id) ~= "string" or spec.id == "" or ns.modsById[spec.id] then
    return false
  end
  local mod = {
    id = spec.id,
    addon = type(spec.addon) == "string" and spec.addon or nil,
    name = type(spec.name) == "string" and spec.name or spec.id,
    version = type(spec.version) == "string" and spec.version or nil,
    onLogin = spec.onLogin, onLogout = spec.onLogout, onDefaults = spec.onDefaults,
  }
  ns.mods[#ns.mods + 1] = mod
  ns.modsById[mod.id] = mod
  if mod.addon then ns.modsByAddon[mod.addon] = mod end
  ns.Debug("mods: %s %s registered", mod.id, tostring(mod.version))
  return true
end

function R.Mods()
  local out = {}
  for i, m in ipairs(ns.mods) do out[i] = { id = m.id, addon = m.addon, name = m.name, version = m.version } end
  return out
end

-- Each registered mod's hook (onLogin, onLogout, onDefaults), each under its own pcall.
function ns.CallMods(hook)
  for _, m in ipairs(ns.mods) do
    if type(m[hook]) == "function" then ns.Run(m.id .. " " .. hook, m[hook]) end
  end
end

-- The journal -----------------------------------------------------------------------------------

R.Journal = {
  Add = function(eventType, fields, quiet) return ns.Journal.Add(eventType, fields, quiet) end,
  Session = function() return ns.Journal.session end,
  Seq = function() return ns.Journal.seq or 0 end,
  Count = function() return ns.Journal.Count() end,
  -- Whether this core drops bulky event types once uploaded (Journal.lua, J.SHORT_LIVED); a mod that
  -- writes them sends nothing on a core without it.
  ShortLived = ns.Journal.SHORT_LIVED ~= nil,
  Events = function(eventType) return ns.Journal.Events(eventType) end,
  Remove = function(eventType, drop) return ns.Journal.Remove(eventType, drop) end,
}

-- Settings --------------------------------------------------------------------------------------

R.Settings = {
  COMBAT_LOG_MODES = ns.COMBAT_LOG_MODES,
  Get = function(key) return ns.Setting(key) end,
  Set = function(key, value)
    if not ns.db then return end
    ns.db.settings[key] = value
  end,
  All = function() return ns.db and ns.db.settings end,
  -- A mod's own boolean settings and their defaults, applied now (when RynaDB is set up) and at
  -- every reset.
  AddDefaults = function(defaults)
    if type(defaults) ~= "table" then return end
    for key, value in pairs(defaults) do
      if type(value) == "boolean" and ns.SETTING_DEFAULTS[key] == nil then ns.SETTING_DEFAULTS[key] = value end
    end
    if ns.db then ns.ApplySettingDefaults(ns.db.settings) end
  end,
}

-- Ordered lines from several sources: each source is fn() -> a list of lines, run under pcall.
function ns.OrderedLines(list)
  table.sort(list, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.seq < b.seq
  end)
  local out = {}
  for _, source in ipairs(list) do
    local ok, lines = pcall(source.fn)
    if ok and type(lines) == "table" then
      for _, line in ipairs(lines) do out[#out + 1] = line end
    elseif not ok then
      ns.ReportError("status lines", lines)
    end
  end
  return out
end

local function adder(list)
  return function(order, fn)
    if type(fn) ~= "function" then return end
    list[#list + 1] = { order = tonumber(order) or 100, fn = fn, seq = #list + 1 }
  end
end

-- The panel -------------------------------------------------------------------------------------

R.Panel = {
  AddTab = function(spec) return ns.Panel.AddTab(spec) end,
  AddStatusLines = adder(ns.Panel.statusSources),
  Refresh = function() return ns.Panel.Refresh() end,
  RefreshIfShown = function() return ns.Panel.RefreshIfShown() end,
  Widgets = ns.Panel.Widgets,
}

-- The window --------------------------------------------------------------------------------------

local Wn = ns.Window
R.Window = {
  AddSection = function(spec) return Wn.AddSection(spec) end,
  Open = function(key) return Wn.Open(key) end,
  Toggle = function(key) return Wn.Toggle(key) end,
  Hide = function() return Wn.Hide() end,
  IsShown = function() return Wn.IsShown() end,
  Selected = function() return Wn.Selected() end,
  Refresh = function(key) return Wn.Refresh(key) end,
  Choose = function(guid) return Wn.Choose(guid) end,
  SetFilter = function(key, value) return Wn.SetFilter(key, value) end,
  Characters = function() return Wn.Characters() end,
  TooltipSection = function(tooltip) return Wn.TooltipSection(tooltip) end,
  Match = Wn.Match, QualityColor = Wn.QualityColor, ClassColor = Wn.ClassColor, ClassName = Wn.ClassName,
  Money = Wn.Money, ItemIcon = Wn.ItemIcon,
  STRIP_MAX = Wn.STRIP_MAX, StripShare = Wn.StripShare,
  STRIP_MARKS = Wn.STRIP_MARKS, MAX_SAY = Wn.MAX_SAY, MAX_BUTTONS = Wn.MAX_BUTTONS,
}

R.Minimap = {
  Add = function(spec) return ns.Minimap.Add(spec) end,
}

R.Tooltip = {
  HasLine = function(tooltip, text) return ns.TooltipLines.Has(tooltip, text) end,
  AddLine = function(tooltip, text, r, g, b, wrap) return ns.TooltipLines.Add(tooltip, text, r, g, b, wrap) end,
}

-- /ryna -----------------------------------------------------------------------------------------

R.Slash = {
  Add = function(spec) return ns.SlashAdd(spec) end,
  AddStatusLines = adder(ns.slashStatusSources),
}
