-- The window's pieces for a fight's detail (Window.lua: a section's `say` and `buttons`, a strip's
-- `marks`), against the fake client the window tests use (test/fake_client.lua),
-- with the core addon alone: sentences sit above the column headings and push the list down, the
-- header's buttons take the place of the pickers and the search box (and give it back), a disabled
-- button does nothing, a text entry is plain text, and skulls sit at their blocks, clamped into the
-- run. From the repository root, with Lua 5.1 (what the game runs) or later:
--
--   lua5.1 test/window_say_test.lua
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
eq(R.Window.MAX_SAY, 3, "the sentences' limit is published")
eq(R.Window.MAX_BUTTONS, 4, "and the buttons'")
eq(R.Window.STRIP_MARKS, 4, "and the marks'")

-- A plain section, to compare against.
check(R.Window.AddSection({
  key = "plain", group = "me", label = "Plain", order = 1,
  columns = { { title = "Name", width = 200 } },
  rows = function() return { { cells = { "one" } } } end,
}), "a plain section: added")

-- A section with sentences, buttons and a strip column.
local said = { "First sentence.", { text = "A dimmer one.", dim = true } }
local earlier, later = 0, 0
local withButtons = true
local marks = { 3, 99, "x" }
check(R.Window.AddSection({
  key = "fight", group = "combat", label = "Fight", order = 1,
  say = function() return said end,
  buttons = function()
    if not withButtons then return {} end
    return {
      { label = "0:36 · 5 players" },
      { label = "‹ Earlier", click = function(ctx)
        earlier = earlier + 1
        check(ctx.section == "fight", "a click has the context")
      end },
      { label = "Later ›", click = function() later = later + 1 end, disabled = true },
    }
  end,
  columns = { { title = "Who", width = 150 }, { title = "", width = 208, kind = "strip" } },
  rows = function()
    return { { cells = { "Aster" }, strips = { [2] = { form = "height", values = { 0.1, 0.2, 0.3, 0.4, 0.5,
      0.6, 0.7, 0.8, 0.9, 1 }, below = { 1 }, marks = marks } } } }
  end,
}), "a section with say and buttons: added")
check(not R.Window.AddSection({ key = "bad", group = "me", columns = {}, rows = function() end, say = "no" }),
  "a say that isn't a function: refused")

R.Window.Open("plain")
local f = Wn.frame
local plainTop = f.listTop
check(f.picker:IsShown() and f.search:IsShown(), "a plain section: the picker and the search box")
for i = 1, 3 do check(not f.say[i]:IsShown(), "no sentences: line " .. i .. " hidden") end

R.Window.Open("fight")
eq(f.say[1]:GetText(), "First sentence.", "the first sentence")
eq(f.say[1]._color[1], 1, "in white")
eq(f.say[2]:GetText(), "A dimmer one.", "the second")
check(f.say[2]._color[1] < 1, "dimmer")
check(not f.say[3]:IsShown(), "two lines: the third is hidden")
eq(f.listTop, plainTop - 2 * 16 - 6, "the list moves down by the sentences")
eq(f.say[1]._points[1][5], plainTop - 2, "the first sentence sits where the list would have started")

-- Buttons in place of the pickers and the search box, laid out from the right.
check(not f.picker:IsShown(), "the picker gives way to the buttons")
check(not f.search:IsShown(), "and the search box")
local shownButtons = {}
for _, b in ipairs(f.navButtons) do if b:IsShown() then shownButtons[#shownButtons + 1] = b end end
eq(#shownButtons, 2, "two buttons")
eq(f.navButtons[1]:GetText(), "Later ›", "the last entry is the rightmost button")
eq(f.navButtons[1]._points[1][4], -34, "at the header's right edge")
eq(f.navButtons[2]:GetText(), "‹ Earlier", "the one before it beside it")
eq(f.navButtons[2]._points[1][4], -34 - 84 - 6, "84 wide and 6 apart")
check(not f.navButtons[1]:IsEnabled(), "a disabled entry: a disabled button")
eq(f.navTexts[1]:GetText(), "0:36 · 5 players", "an entry with no click is text")
F.Click(f.navButtons[2])
eq(earlier, 1, "a click runs the entry")
F.Click(f.navButtons[1])
eq(later, 0, "a disabled one doesn't")

-- Skulls on the strip: at their blocks, clamped into the run; anything not a number is skipped.
local st = f.rows[1].strips[2]
eq(st.marks[1] and st.marks[1]._texture, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "the game's skull")
local step = 200 / 10
eq(st.marks[1]._points[1][4], 2.5 * step, "centred on block 3")
eq(st.marks[2]._points[1][4], 9.5 * step, "block 99 clamped to the last block")
check(st.marks[1]:IsShown() and st.marks[2]:IsShown(), "both shown")
eq(st.marks[3], nil, "the third isn't a number: no mark")
marks = {}
Wn.views.fight.built = false
Wn.Draw()
check(not st.marks[1]:IsShown() and not st.marks[2]:IsShown(), "no marks: the skulls go")

-- No buttons: the picker and the search box come back; nothing said: no gap.
withButtons = false
said = {}
Wn.Draw()
check(f.picker:IsShown() and f.search:IsShown(), "no buttons: the picker and the search box are back")
for _, b in ipairs(f.navButtons) do check(not b:IsShown(), "and the buttons are gone") end
check(not f.navTexts[1]:IsShown(), "and the text")
eq(f.listTop, plainTop, "no sentences: the list where it always was")

-- At most three lines; empty and odd entries skipped.
said = { "a", "", 42, { text = "b" }, "c", "d" }
Wn.Draw()
eq(f.say[1]:GetText() .. f.say[2]:GetText() .. f.say[3]:GetText(), "abc", "three lines, the empty and odd ones skipped")

-- The empty line may follow the context.
local why = "absent"
check(R.Window.AddSection({
  key = "empty", group = "me", label = "Empty", order = 2,
  columns = { { title = "Name", width = 200 } },
  rows = function() return {} end,
  empty = function(ctx)
    check(ctx.section == "empty", "the empty text has the context")
    return why == "absent" and "Nothing yet." or ""
  end,
}), "a section with an empty function: added")
R.Window.Open("empty")
eq(f.empty:GetText(), "Nothing yet.", "its own empty line")
why = "other"
Wn.Draw()
eq(f.empty:GetText(), "Nothing recorded yet.", "nothing from it: the window's own")
R.Window.Open("fight")

-- Back on the plain section after the buttons: the picker and the search box stay.
withButtons = true
Wn.Draw()
R.Window.Open("plain")
check(f.picker:IsShown() and f.search:IsShown(), "another section: the picker and the search box")
check(not f.say[1]:IsShown(), "and no sentences")

check(#F.chat == 0, "nothing in chat: " .. table.concat(F.chat, " / "))
check(core.errors.count == 0, "no errors caught: " .. tostring(core.errors.last))
print(string.format("window say: %d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
