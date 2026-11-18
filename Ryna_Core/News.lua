-- News: what's new, once after each update (docs/ryna-agent-cores-mods.md 9.2). The notes are
-- WhatsNew.lua's (ns.NEWS), made from whats-new.json by scripts/whats-new.mjs. At the first login on
-- a version that has a note, a small frame says what changed: the core's changes, those of the mods
-- that are on, and any mod the note introduces that isn't on yet. One button closes it and it doesn't
-- come back for that version (RynaDB.newsSeen). Never in chat, never during a fight (it waits for the
-- fight to end), never on a new install, where nothing is new. The setting newsPopup (on) turns it
-- off; /ryna news shows the note whenever asked.

local _, ns = ...
local L = ns.L

local N = {}
ns.News = N

local WIDTH = 440
-- The mods a note can name, as a heading says them.
N.NAMES = { chronicle = "Chronicle", automation = "Automation", prices = "Prices", fights = "Fights",
  meter = "Meter" }
-- The order the groups are shown in.
N.ORDER = { "meter", "fights", "chronicle", "prices", "automation", "core" }

-- The note for a version; nil when it has none.
function N.For(version)
  for _, note in ipairs(ns.NEWS or {}) do
    if note.version == version then return note end
  end
  return nil
end

-- The note /ryna news shows: this version's, else the newest there is (one still marked "next" is the
-- release being made).
function N.Latest()
  return N.For(ns.VERSION) or (ns.NEWS or {})[1]
end

-- A note as groups to show: { { heading, hint, lines } }. A mod that is on shows its changes; one that
-- isn't shows them only when the note introduces it (an item marked new), with a hint that it can be
-- turned on; the core's come last, under "Everywhere".
function N.Groups(note)
  local by = {}
  for _, item in ipairs(note.items or {}) do
    local g = by[item.where]
    if not g then
      g = { lines = {}, new = false }
      by[item.where] = g
    end
    g.lines[#g.lines + 1] = item.text
    g.new = g.new or item.new == true
  end
  local out = {}
  for _, where in ipairs(N.ORDER) do
    local g = by[where]
    if g then
      if where == "core" then
        out[#out + 1] = { heading = L["Everywhere"], lines = g.lines }
      else
        local on = ns.modsById[where] ~= nil
        if on or g.new then
          out[#out + 1] = {
            heading = string.format(L["%s by Ryna"], N.NAMES[where] or where),
            hint = (not on) and L["new mod: turn it on in the Ryna app"] or (g.new and L["new"] or nil),
            lines = g.lines,
          }
        end
      end
    end
  end
  return out
end

-- The note as the frame's text: gold headings (a dim hint beside one), a bullet per change.
function N.Body(note)
  local parts = {}
  for _, g in ipairs(N.Groups(note)) do
    local heading = "|cffffd100" .. g.heading .. "|r"
    if g.hint then heading = heading .. "  |cff9d97aa" .. g.hint .. "|r" end
    parts[#parts + 1] = heading
    for _, line in ipairs(g.lines) do parts[#parts + 1] = "  • " .. line end
    parts[#parts + 1] = ""
  end
  parts[#parts] = nil
  return table.concat(parts, "\n")
end

local function create(kind, name, parent, templates)
  for _, template in ipairs(templates or {}) do
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
  end
  local ok, f = pcall(CreateFrame, kind, name, parent)
  if ok then return f end
  return nil
end

local function text(parent, fontObject, size)
  local ok, fs = pcall(parent.CreateFontString, parent, nil, "OVERLAY", fontObject)
  if not ok or not fs then fs = parent:CreateFontString(nil, "OVERLAY") end
  if not fs:GetFont() then fs:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12) end
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  if fs.SetWordWrap then fs:SetWordWrap(true) end
  fs:SetWidth(WIDTH - 32)
  return fs
end

function N.Create()
  if N.frame then return N.frame end
  local f = create("Frame", "RynaNews", _G.UIParent, { "BackdropTemplate" })
  if not f then return nil end
  N.frame = f
  f:SetWidth(WIDTH)
  f:SetPoint("TOP", _G.UIParent, "TOP", 0, -120)
  f:SetFrameStrata("DIALOG")
  if f.SetToplevel then f:SetToplevel(true) end
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  if not (f.SetBackdrop and pcall(f.SetBackdrop, f, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  }) and pcall(f.SetBackdropColor, f, 0.04, 0.04, 0.05, 0.96)) then
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.05, 0.96)
  end
  -- Escape closes it, like the game's own windows.
  if type(_G.UISpecialFrames) == "table" then table.insert(_G.UISpecialFrames, "RynaNews") end

  f.title = text(f, "GameFontNormalLarge", 14)
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
  f.headline = text(f, "GameFontDisable", 12)
  f.headline:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
  f.body = text(f, "GameFontHighlight", 12)
  f.body:SetPoint("TOPLEFT", f.headline, "BOTTOMLEFT", 0, -10)
  f.again = text(f, "GameFontDisableSmall", 10)
  f.again:SetWidth(WIDTH - 140)
  f.again:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
  f.again:SetText(L["/ryna news shows this again"])

  local close = create("Button", nil, f, { "UIPanelButtonTemplate" })
  close:SetSize(96, 22)
  if not close:GetFontString() then
    local fs = text(close, "GameFontNormal")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    close:SetFontString(fs)
  end
  close:SetText(L["Got it"])
  close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
  close:SetScript("OnClick", function() f:Hide() end)
  f.close = close
  f:Hide()
  -- Closed, by the button or Escape: this version's note has been seen. Set after the Hide above: a
  -- frame is made shown, and hiding it there must not count as the player closing it.
  f:SetScript("OnHide", function() ns.Run("news seen", N.Seen) end)
  return f
end

function N.Seen()
  if ns.db then ns.db.newsSeen = ns.VERSION end
end

-- Shows a note. Returns false when there is nothing to show or no frame to show it in.
function N.Show(note)
  if not note then return false end
  local body = N.Body(note)
  if body == "" then return false end
  local f = N.Create()
  if not f then return false end
  local version = note.version == "next" and ns.VERSION or note.version
  f.title:SetText(string.format(L["What's new in Ryna %s"], version))
  f.headline:SetText(note.headline or "")
  f.body:SetText(body)
  local height = 14 + (f.title:GetStringHeight() or 16) + 6 + (f.headline:GetStringHeight() or 14) + 10
    + (f.body:GetStringHeight() or 120)
  f:SetHeight(height + 52)
  f:Show()
  return true
end

-- Whether the login popup is due: the setting is on, this isn't a new install, this version has a note
-- and it hasn't been seen. A new install just marks the version seen.
function N.Due()
  if not ns.db then return false end
  if ns.dbFresh and ns.db.newsSeen == nil then
    ns.db.newsSeen = ns.VERSION
    return false
  end
  if ns.db.newsSeen == ns.VERSION then return false end
  if not ns.Setting("newsPopup") then return false end
  return N.For(ns.VERSION) ~= nil
end

-- At login: the popup when it is due, after the fight if there is one.
function N.ShowAtLogin()
  if N.asked or not N.Due() then return end
  N.asked = true
  local function show()
    if not N.shown then N.shown = N.Show(N.For(ns.VERSION)) end
  end
  local inCombat = ns.Fn("InCombatLockdown")
  if inCombat and ns.Try(inCombat) == true then
    ns.On("PLAYER_REGEN_ENABLED", show)
  else
    show()
  end
end

ns.SlashAdd({ word = "news", order = 45, help = L["/ryna news: what's new in this version"],
  run = function()
    if not N.Show(N.Latest()) then ns.Print(L["There is no note for this version."]) end
  end })
