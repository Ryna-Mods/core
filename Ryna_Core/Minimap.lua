-- Minimap: a round button on the minimap's edge. A click opens Ryna's menu: every section of Ryna's
-- window, what the mods that are on add (the Meter's windows, say), what's new, and Settings last.
-- Dragging moves it around the ring, the tooltip shows the one-line status. Its angle and whether
-- it's shown live in RynaDB.settings.minimap. No library; nothing happens on a client without a
-- Minimap frame, and on one without the client's menus a click opens Settings, as it always did.
--
--   M.Add{ label, order, run, checked }   a mod's entry (Ryna.Minimap.Add): run() on a click;
--                                         `checked`, a function, makes it a tick box showing what
--                                         it returns
--   M.Rows()                              the menu as rows: { title }, { divider },
--                                         { text, pick } or { text, pick, checked }

local _, ns = ...
local L = ns.L

local M = {}
ns.Minimap = M

local ICON = "Interface\\Icons\\INV_Misc_Note_01"

-- What the mods added, in the order they are shown.
M.items = {}

function M.Add(spec)
  if type(spec) ~= "table" or type(spec.label) ~= "string" or spec.label == "" or type(spec.run) ~= "function" then
    return false
  end
  M.items[#M.items + 1] = {
    label = spec.label, run = spec.run, order = tonumber(spec.order) or 100, seq = #M.items + 1,
    checked = type(spec.checked) == "function" and spec.checked or nil,
  }
  table.sort(M.items, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.seq < b.seq
  end)
  return true
end

function M.Rows()
  local rows = { { title = "Ryna " .. tostring(ns.VERSION) } }
  local sections = ns.Window.List()
  if #sections > 0 then
    rows[#rows + 1] = { title = L["Open Ryna's window on"] }
    for _, s in ipairs(sections) do
      rows[#rows + 1] = { text = s.label, pick = function() ns.Window.Open(s.key) end }
    end
  end
  if #M.items > 0 then
    rows[#rows + 1] = { divider = true }
    for _, item in ipairs(M.items) do
      rows[#rows + 1] = { text = item.label, pick = item.run, checked = item.checked }
    end
  end
  rows[#rows + 1] = { divider = true }
  if ns.News and ns.News.Latest() then
    rows[#rows + 1] = { text = L["What's new"], pick = function() ns.News.Show(ns.News.Latest()) end }
  end
  rows[#rows + 1] = { text = L["Settings"], pick = function() ns.Panel.Open() end }
  return rows
end

-- A click: the menu, or Settings on a client without the client's menus.
function M.Click(owner)
  local open = ns.Fn("MenuUtil", "CreateContextMenu")
  local ok = open and pcall(open, owner, function(_, root)
    for _, row in ipairs(M.Rows()) do
      if row.title then
        root:CreateTitle(row.title)
      elseif row.divider then
        root:CreateDivider()
      elseif row.checked then
        root:CreateCheckbox(row.text, function() return row.checked() and true or false end, function()
          ns.Run("minimap menu", row.pick)
        end)
      else
        root:CreateButton(row.text, function() ns.Run("minimap menu", row.pick) end)
      end
    end
  end)
  if not ok then ns.Panel.Open() end
end

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function place(button, angle)
  local map = _G.Minimap
  local radius = (map:GetWidth() or 140) / 2 + 5
  local rad = math.rad(angle)
  button:ClearAllPoints()
  button:SetPoint("CENTER", map, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function cursorAngle()
  local map = _G.Minimap
  local mx, my = map:GetCenter()
  local x, y = GetCursorPosition()
  local scale = map:GetEffectiveScale()
  return math.deg(atan2(y / scale - my, x / scale - mx)) % 360
end

local function onDragUpdate(self)
  local angle = cursorAngle()
  ns.db.settings.minimap.angle = angle
  place(self, angle)
end

local function tooltip(self)
  local tip = _G.GameTooltip
  if not tip then return end
  tip:SetOwner(self, "ANCHOR_LEFT")
  tip:SetText("Ryna " .. ns.VERSION)
  tip:AddLine(ns.Status.SyncLine(), 1, 1, 1, true)
  if #ns.Status.UpdateLines() > 0 then tip:AddLine(L["Update available"], 0.25, 1, 0.25) end
  tip:AddLine(L["Click: Ryna's menu. Drag: move this button."], 0.6, 0.6, 0.6, true)
  tip:Show()
end

function M.Create()
  if M.button or not _G.Minimap then return end
  local b = CreateFrame("Button", "RynaMinimapButton", _G.Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetSize(20, 20)
  bg:SetPoint("CENTER")
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON)
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")

  b:SetScript("OnClick", function(self)
    if _G.GameTooltip then _G.GameTooltip:Hide() end
    ns.Run("minimap click", M.Click, self)
  end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(s) ns.Run("minimap drag", onDragUpdate, s) end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self) ns.Run("minimap tooltip", tooltip, self) end)
  b:SetScript("OnLeave", function()
    if _G.GameTooltip then _G.GameTooltip:Hide() end
  end)

  M.button = b
  M.Update()
end

-- Shows or hides the button and puts it at its saved angle.
function M.Update()
  local b = M.button
  if not b then return end
  local mm = ns.db.settings.minimap
  place(b, mm.angle)
  if mm.shown then b:Show() else b:Hide() end
end
