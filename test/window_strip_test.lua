-- The window's strip (Window.lua: a "strip" column and a row's strips), against the fake client the
-- window tests use (test/fake_client.lua), with the core addon alone: a strip's
-- blocks get their share as alpha (brightness) or height (one line, or two from the middle), a share
-- outside 0..1 is clamped, past 48 blocks the rest are left out, labels sit at their blocks, a row with
-- a strip still sorts and searches, a strip column draws a bar for a row without a strip, scrolling
-- 2,000 rows makes no new textures, and a section's title can follow its context. From the repository
-- root, with Lua 5.1 (what the game runs) or later:
--
--   lua5.1 test/window_strip_test.lua
--
-- This proves the logic; how the blocks look in the default UI and in ElvUI is the game's to show.
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
local function near(got, want, what)
  check(type(got) == "number" and math.abs(got - want) < 1e-9,
    what .. ": got " .. tostring(got) .. ", want " .. tostring(want))
end

F.Install()
_G.UnitGUID = function(unit) if unit == "player" then return "Player-91-0000000A" end end
_G.UnitName = function(unit) if unit == "player" then return "Brennic" end end
_G.C_AddOns = { GetAddOnMetadata = function() return "0.0.0" end }
_G.RynaDB = { schema = 1, settings = {}, journal = {}, characters = {} }

local core = {}
F.LoadAddon(CORE, "Ryna_Core", core)
F.Fire("ADDON_LOADED", "Ryna_Core")
F.Fire("PLAYER_LOGIN")
F.DropTimers()

local R = _G.Ryna
local Wn = core.Window
eq(R.Window.STRIP_MAX, 48, "the strip's limit is published")

-- A section with a strip column: three rows, a sort key and a search over the names.
local STRIP_W = 250
local data = {
  { name = "Alpha", n = 3, strips = { [2] = { values = { 0, 0.25, 1, 0.5 } } } },
  { name = "Bravo", n = 9, strips = { [2] = { values = { -1, 2, 0 / 0, "x" } } } },
  { name = "Charlie", n = 1, bars = { [2] = { value = 2, max = 4 } }, cells2 = "2 of 4" },
}
local titleCalls = 0
check(R.Window.AddSection({
  key = "strips", group = "me", label = "Strips", order = 1,
  title = function(ctx)
    titleCalls = titleCalls + 1
    return "Strips › " .. (ctx.filter or "all")
  end,
  filter = function() return { { value = nil, label = "All" }, { value = "b", label = "B" } } end,
  columns = { { title = "Name", width = 120 }, { title = "Hours", width = STRIP_W + 8, kind = "strip" },
    { title = "N", width = 60, justify = "RIGHT" } },
  rows = function(ctx)
    local out = {}
    for _, d in ipairs(data) do
      if R.Window.Match(d.name, ctx.search) then
        out[#out + 1] = { cells = { d.name, d.cells2 or "", tostring(d.n) }, sort = { d.name:lower(), nil, d.n },
          strips = d.strips, bars = d.bars, name = d.name }
      end
    end
    out[#out + 1] = { header = true, cells = { "Heading", "under it", "" }, strips = { [2] = { values = { 1 } } } }
    return out
  end,
}), "a section with a strip column: added")

R.Window.Open("strips")
local f = Wn.frame
eq(f.title:GetText(), "Strips › all", "the title follows the context")
R.Window.SetFilter("strips", "b")
eq(f.title:GetText(), "Strips › b", "and the filter")
R.Window.SetFilter("strips", nil)

local function rowNamed(name)
  for r = 1, Wn.visible do
    local row = f.rows[r]
    if row:IsShown() and row.data and row.data.name == name then return row end
  end
end

-- Brightness: one block per value, its alpha the share.
local alpha = rowNamed("Alpha")
local st = alpha.strips and alpha.strips[2]
check(st and st:IsShown(), "Alpha's strip is drawn")
eq(alpha.cols[2]:GetText(), "", "a strip takes the place of the cell's text")
check(not alpha.bars[2]:IsShown(), "and of any bar")
eq(st:GetWidth(), STRIP_W, "the strip spans its column (less the cell's margin)")
for i, want in ipairs({ 0, 0.25, 1, 0.5 }) do
  local b = st.top[i]
  check(b and b:IsShown(), "brightness block " .. i .. " is shown")
  near(b and b:GetAlpha(), want, "brightness block " .. i .. "'s alpha is its share")
  eq(b and b._height, 14, "brightness block " .. i .. " is the strip's full height")
end
eq(st.top[5], nil, "four values: four blocks made, no more")
eq(st.top[2]._width, STRIP_W / 4 - 1, "blocks share the width, a pixel apart")
eq(st.top[3]._points[1][4], STRIP_W / 2, "block 3 starts halfway along")
eq(st.top[1]._colorTexture[1] .. "," .. st.top[1]._colorTexture[2], "0.26,0.52",
  "the default colour, the window's bar blue")

-- Out of range: clamped (and anything not a number is 0).
local bravo = rowNamed("Bravo")
for i, want in ipairs({ 0, 1, 0, 0 }) do
  near(bravo.strips[2].top[i]:GetAlpha(), want, "a share outside 0..1 (or not a number) clamped, block " .. i)
end
eq(R.Window.StripShare(-0.5) .. " " .. Wn.StripShare(1.5) .. " " .. Wn.StripShare(0.3) .. " " .. Wn.StripShare(nil),
  "0 1 0.3 0", "StripShare clamps")

-- A strip column draws a bar for a row with no strip; a heading row draws neither.
local charlie = rowNamed("Charlie")
check(charlie.bars[2]:IsShown(), "a row with a bar and no strip: its bar, in the strip column")
eq(charlie.bars[2].text:GetText(), "2 of 4", "with its text over it")
check(not (charlie.strips and charlie.strips[2] and charlie.strips[2]:IsShown()), "and no strip")
local heading
for r = 1, Wn.visible do if f.rows[r].data and f.rows[r].data.header then heading = f.rows[r] end end
check(heading and not (heading.strips and heading.strips[2] and heading.strips[2]:IsShown()), "a heading row: no strip")

-- Sorting by N: the strips go with their rows (the heading, with no key, last).
Wn.SortBy(3)
eq(f.rows[1].data.name, "Bravo", "most first")
near(f.rows[1].strips[2].top[2]:GetAlpha(), 1, "row 1's strip is now Bravo's")
check(not f.rows[3].strips or not f.rows[3].strips[2] or not f.rows[3].strips[2]:IsShown(),
  "row 3 is Charlie now: the strip it drew before is hidden")
check(f.rows[3].bars[2]:IsShown(), "and Charlie's bar is drawn there")
check(f.rows[4].data.header, "the heading, with no sort key, last")
Wn.SortBy(3)
eq(f.rows[1].data.name, "Charlie", "fewest first")
Wn.SortBy(3)
eq(f.rows[1].data.name, "Alpha", "the section's own order again")

-- Searching: the matching row keeps its strip.
Wn.Search("brav")
eq(#Wn.views.strips.sorted, 2, "one row matches, and the heading")
eq(f.rows[1].data.name, "Bravo", "Bravo")
check(f.rows[1].strips[2]:IsShown(), "with its strip")
near(f.rows[1].strips[2].top[2]:GetAlpha(), 1, "its own shares")
Wn.Search("")

-- Height, one line: grows up from the bottom; an empty block is hidden.
local holder = F.new("Frame", nil, nil)
holder.top, holder.below, holder.labels = {}, {}, {}
holder.track = F.new("Texture", nil, holder)
holder:SetWidth(100)
eq(Wn.DrawStrip(holder, { form = "height", values = { 0.5, 0, 1 } }), 3, "three blocks drawn")
eq(holder.top[1]._height, 7, "half a share: half the strip's height")
eq(holder.top[1]._points[1][1] .. " " .. holder.top[1]._points[1][3], "BOTTOMLEFT BOTTOMLEFT",
  "growing up from the bottom")
check(not holder.top[2]:IsShown(), "a share of 0: no block")
eq(holder.top[3]._height, 14, "a full share: the full height")
eq(holder.top[1]:GetAlpha(), 1, "height blocks are opaque")

-- Height, two lines: values up from the middle, below down from it, each its own colour.
eq(Wn.DrawStrip(holder, { form = "height", values = { 1, 0.5 }, below = { 0.5, 0, 0.25 },
  color = { 0.1, 0.2, 0.3 }, belowColor = { 0.9, 0.1, 0.1 } }), 3, "the longer line sets the run: three")
eq(holder.top[1]._height, 7, "top line: a full share is half the strip")
eq(holder.top[1]._points[1][1] .. " " .. holder.top[1]._points[1][3], "BOTTOMLEFT LEFT", "growing up from the middle")
eq(holder.below[1]._height, 3.5, "bottom line: half a share is a quarter of the strip")
eq(holder.below[1]._points[1][1] .. " " .. holder.below[1]._points[1][3], "TOPLEFT LEFT",
  "growing down from the middle")
check(not holder.below[2]:IsShown(), "a bottom share of 0: no block")
check(not holder.top[3]:IsShown(), "no top value for block 3: no top block")
eq(holder.below[3]._height, 1.75, "block 3's bottom share is drawn (a quarter of the half)")
eq(holder.top[1]._colorTexture[3], 0.3, "the top line's colour")
eq(holder.below[1]._colorTexture[1], 0.9, "the bottom line's colour")

-- Brightness again on the same holder: the bottom line goes, the heights are the strip's.
Wn.DrawStrip(holder, { values = { 0.4 } })
check(not holder.below[1]:IsShown(), "back to brightness: no bottom line")
check(not holder.top[2]:IsShown(), "one value: the second block is hidden")
eq(holder.top[1]._height, 14, "full height")

-- Past 48: the first 48 are drawn, the rest left out.
local many = {}
for i = 1, 60 do many[i] = i / 60 end
eq(Wn.DrawStrip(holder, { values = many }), 48, "60 values: 48 blocks")
eq(holder.top[49], nil, "no 49th block is ever made")
near(holder.top[48]:GetAlpha(), 48 / 60, "the 48th is the 48th value")
eq(holder.top[48]._width, 100 / 48, "48 blocks across the width, too narrow for a gap")
eq(Wn.DrawStrip(holder, { values = { 1 }, count = 500 }), 48, "a count past 48: 48")

-- Labels: texts at their blocks' left edges, no blocks, no track.
eq(Wn.DrawStrip(holder, { count = 24, labels = { [1] = "12 AM", [7] = "6 AM", [13] = "12 PM", [19] = "6 PM",
  [30] = "never", [2.5] = "nor this" } }), 0, "a label row draws no blocks")
eq(holder.labels[1]:GetText(), "12 AM", "label 1")
eq(holder.labels[7]._points[1][4], 25, "label 7 sits at block 7's left edge (6 of 24 across 100)")
eq(holder.labels[30], nil, "a label past the run: left out")
check(not holder.top[1]:IsShown(), "no blocks under labels")
check(not holder.track:IsShown(), "no track under labels")
Wn.DrawStrip(holder, { values = { 1 } })
check(not holder.labels[1]:IsShown(), "a strip after labels hides them")
check(holder.track:IsShown(), "and shows its track")

-- 2,000 rows with strips: the row frames' blocks are made once, scrolling makes none.
data = {}
for i = 1, 2000 do
  local v = {}
  for h = 1, 24 do v[h] = ((i + h) % 10) / 10 end
  data[i] = { name = "Row " .. i, n = i, strips = { [2] = { values = v } } }
end
R.Window.Refresh()
Wn.views.strips.built = false
Wn.Draw()
eq(#Wn.views.strips.sorted, 2001, "2,000 rows and the heading")
local made = #F.frames
for _ = 1, 30 do f.list._scripts.OnMouseWheel(f.list, -1) end
f.bar:SetValue(1500)
eq(#F.frames, made, "scrolling 2,000 rows with strips makes no new frames or textures")
local first = f.rows[1].data
near(f.rows[1].strips[2].top[1]:GetAlpha(), first.strips[2].values[1], "the row on screen shows its own shares")

check(#F.chat == 0, "nothing in chat: " .. table.concat(F.chat, " / "))
check(core.errors.count == 0, "no errors caught: " .. tostring(core.errors.last))
print(string.format("window strip: %d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
