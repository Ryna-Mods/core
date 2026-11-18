-- Init: the login sequence. Loaded after every core module, before any mod (a mod depends on this
-- addon, so the client loads it after), and a mod's own login work is its onLogin (Mods.lua).
--
-- PLAYER_LOGIN sets up RynaDB, prunes the journal and starts this session's journal, then runs each
-- mod's onLogin in the order they registered (Chronicle builds the character record and writes the
-- session's `login` event there). The heavier scans are the mods' own, deferred past the first
-- PLAYER_ENTERING_WORLD.

local addonName, ns = ...
local L = ns.L

ns.On("ADDON_LOADED", function(_, name)
  if name == addonName then ns.InitDB() end
end)

-- Before 0.5.0 this addon's folder was Ryna. The companion app moves an install over with the game
-- closed: the folder, and each account's saved file. Someone who unpacks a release by hand gets
-- Ryna_Core beside the old Ryna, and the client then loads the same addon twice, both on one RynaDB.
-- So when the old one loaded: take the mod API and RynaDB back (whichever of the two loaded last has
-- them), turn the old one off in the game's addon list, and ask for the reload that makes it so (a
-- dialog, never chat). RynaDB is the old folder's saved file when this one has none yet, which is how
-- everything recorded comes along; from the reload on it is saved under this folder's name.
function ns.RetireLegacy()
  local loaded = ns.Fn("C_AddOns", "IsAddOnLoaded") or ns.Fn("IsAddOnLoaded")
  if not ns.Try(loaded, ns.LEGACY_NAME) then return false end
  Ryna = ns.ModAPI
  if _G.RynaDB ~= ns.db then ns.InitDB() end
  local disable = ns.Fn("C_AddOns", "DisableAddOn") or ns.Fn("DisableAddOn")
  if disable then pcall(disable, ns.LEGACY_NAME) end
  ns.legacy = true
  ns.Debug("the old Ryna folder loaded too: turned off in the game's addon list, reload to finish")
  return true
end

function ns.OfferLegacyReload()
  local dialogs = StaticPopupDialogs
  local show = ns.Fn("StaticPopup_Show")
  local reload = ns.Fn("C_UI", "Reload") or ns.Fn("ReloadUI")
  if type(dialogs) ~= "table" or not show or not reload then return false end
  if not dialogs.RYNA_LEGACY_RELOAD then
    dialogs.RYNA_LEGACY_RELOAD = {
      text = L["Ryna moved to a new addon folder, Ryna_Core, and the old one is still here. Reload now to "
        .. "finish the move? Everything Ryna recorded comes along."],
      button1 = _G.RELOADUI or L["Reload"], button2 = _G.CANCEL or L["Later"],
      OnAccept = function() reload() end,
      timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
  end
  return ns.Try(show, "RYNA_LEGACY_RELOAD") and true or false
end

ns.On("PLAYER_LOGIN", function()
  ns.Run("legacy folder", ns.RetireLegacy)
  if not ns.db then ns.InitDB() end
  ns.Journal.Prune()
  ns.Journal.StartSession(UnitGUID("player"))
  ns.CallMods("onLogin")
  if ns.Setting("chatNotices") then
    ns.PrintRaw(string.format("|cff7fb2ffRyna %s|r: %s", ns.VERSION, L["recording. /ryna for settings."]))
  end
  ns.Debug("login: %d mods (%s)", #ns.mods, ns.ListText((function()
    local ids = {}
    for i, m in ipairs(ns.mods) do ids[i] = m.id end
    return ids
  end)()))
  if ns.Setting("chatNotices") and ns.Status.IsStale() then
    ns.Print(L["the companion app hasn't synced recently."])
  end
  ns.Debug("companion app file: %s", ns.Status.DebugLine())
  ns.Run("advanced combat logging", ns.CombatLog.ApplyAdvancedLogging)
end)

-- The UI is a second PLAYER_LOGIN handler, after the one above, with each part under its own
-- pcall: a client without the Settings API or a minimap still records, and an error above doesn't
-- take the panel with it.
ns.On("PLAYER_LOGIN", function()
  if not ns.db then ns.InitDB() end
  ns.Run("panel", ns.Panel.Register)
  ns.Run("minimap", ns.Minimap.Create)
  -- A frame, never chat, and only when the API said this version is no longer supported.
  ns.Run("version notice", ns.Notice.ShowAtLogin)
  -- What's new, once after an update: a frame too, and not on top of the notice above.
  if ns.legacy then
    -- The old folder is still loaded: the reload comes first, and the news after it.
    ns.Run("legacy reload", ns.OfferLegacyReload)
  elseif not ns.Notice.shown then
    ns.Run("news", ns.News.ShowAtLogin)
  end
end)

ns.On("PLAYER_LOGOUT", function()
  ns.CallMods("onLogout")
end)

-- When the client blocks or forbids something this addon or one of its mods did (the "blocked
-- from an action only available to the Blizzard UI" dialog), say which call it was, in chat and in
-- RynaDB.blocked, so it can be found without a taint log.
--
-- Only ours. The client sends these events for every addon, and through 0.4.0 this printed each
-- one with "Please report this line": HealBot moving its own frame in combat, which the client
-- refuses as a matter of course, read as a Ryna fault. Another addon's goes to the debug log.
local function noteBlocked(event, addon, fn)
  local what = tostring(fn)
  local verb = event == "ADDON_ACTION_FORBIDDEN" and "forbade" or "blocked"
  if not ns.IsOwnAddon(addon) then
    ns.Debug("the client %s a call to %s by %s (another addon's, not reported)", verb, what, tostring(addon))
    return
  end
  ns.db.blocked = { event = event, fn = what, at = ns.Now(), addon = ns.VERSION }
  ns.PrintRaw(string.format("|cffff6060Ryna|r: the client %s a call to %s by %s (Ryna %s). Please report this line.",
    verb, what, tostring(addon), ns.VERSION))
end
ns.On("ADDON_ACTION_FORBIDDEN", noteBlocked)
ns.On("ADDON_ACTION_BLOCKED", noteBlocked)
