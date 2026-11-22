-- BGComs secure part: the invisible button over the battlefield map that sends the callouts.
--
-- During a battleground match addon code can't send chat, and in combat it can't change a secure
-- button. So the choice is made by a restricted snippet wrapped around the button's OnClick, from
-- values loaded out of combat (places, sectors, texts) and the cursor position:
--   middle button down: if the modifier is held, the nearest place to the cursor is picked, and
--     the button grows into a square centred on the cursor, so that the release lands on it;
--   middle button up: the drag from the press point gives the call and the count, the button
--     shrinks back over the map, writes "/i <message>" into its macrotext, and lets Blizzard's
--     SecureActionButton handler run it as a macro (a macro the player clicked may talk in a
--     battleground; only boss encounters restrict macro chat).
-- Left and right clicks pass through to the map; mouse motion too (map tooltips keep working),
-- unless /bgc motion on.
--
-- Everything here that touches the button is out of combat only, except what the snippet does.

local _, ns = ...

local G = ns.GEOMETRY
local Secure = {}
ns.Secure = Secure

local header, overlay
local applied = {} -- attribute values last set from here, to set only what changed
local pendingConfig = false
local lastRects
local homeKey

-- The restricted snippet (preBody of the OnClick wrap): self is the button's handle.
-- Returning false skips Blizzard's handler (nothing is run); returning nothing lets it run the
-- macro. Down clicks never run anything: "useOnKeyDown" is false, so actions fire on release.
local SNIPPET = [=[
if button ~= "MiddleButton" then
	return false
end
local seq = self:GetAttribute("bgc-seq") or 0
if down then
	if self:GetAttribute("bgc-open") then
		-- A press while still open: the last release was missed. Put the button back, cancel.
		self:ClearAllPoints()
		self:SetPoint("BOTTOMLEFT", "$screen", "BOTTOMLEFT", self:GetAttribute("bgc-l"), self:GetAttribute("bgc-b"))
		self:SetWidth(self:GetAttribute("bgc-w"))
		self:SetHeight(self:GetAttribute("bgc-h"))
		self:SetAttribute("bgc-open", nil)
		self:SetAttribute("bgc-res", "stale")
		self:SetAttribute("bgc-seq", seq + 1)
		return false
	end
	if not self:GetAttribute("bgc-active") or not self:GetAttribute("bgc-ax") then
		return false
	end
	local mod = self:GetAttribute("bgc-mod")
	if (mod == "alt" and not IsAltKeyDown()) or (mod == "ctrl" and not IsControlKeyDown())
		or (mod == "shift" and not IsShiftKeyDown()) then
		return false
	end
	local fx, fy = self:GetMousePosition()
	if not fx then
		return false
	end
	local mx = self:GetAttribute("bgc-bx") + fx * self:GetAttribute("bgc-ax")
	local my = 1 - (self:GetAttribute("bgc-by") + fy * self:GetAttribute("bgc-ay"))
	self:SetAttribute("bgc-mx", mx)
	self:SetAttribute("bgc-my", my)
	self:SetAttribute("bgc-downseq", (self:GetAttribute("bgc-downseq") or 0) + 1)
	local pw = self:GetAttribute("bgc-pw")
	local ph = self:GetAttribute("bgc-ph")
	local best, bestD
	for code, x, y in gmatch(self:GetAttribute("bgc-nodes") or "", "([^;,]+),([^;,]+),([^;,]+)") do
		local ex = (tonumber(x) - mx) * pw
		local ey = (tonumber(y) - my) * ph
		local d = ex * ex + ey * ey
		if not bestD or d < bestD then
			best = code
			bestD = d
		end
	end
	if not best then
		self:SetAttribute("bgc-res", "noloc")
		self:SetAttribute("bgc-seq", seq + 1)
		return false
	end
	local size = self:GetAttribute("bgc-size")
	self:SetAttribute("bgc-loc", best)
	self:SetAttribute("bgc-open", true)
	self:ClearAllPoints()
	self:SetPoint("CENTER", "$cursor", "BOTTOMLEFT", 0, 0)
	self:SetWidth(size)
	self:SetHeight(size)
	return false
end
-- Release.
if not self:GetAttribute("bgc-open") then
	return false
end
local size = self:GetAttribute("bgc-size")
local fx, fy = self:GetMousePosition()
self:ClearAllPoints()
self:SetPoint("BOTTOMLEFT", "$screen", "BOTTOMLEFT", self:GetAttribute("bgc-l"), self:GetAttribute("bgc-b"))
self:SetWidth(self:GetAttribute("bgc-w"))
self:SetHeight(self:GetAttribute("bgc-h"))
self:SetAttribute("bgc-open", nil)
self:SetAttribute("bgc-seq", seq + 1)
if not fx then
	self:SetAttribute("bgc-res", "outside")
	return false
end
local dx = (fx - 0.5) * size
local dy = (fy - 0.5) * size
self:SetAttribute("bgc-dx", dx)
self:SetAttribute("bgc-dy", dy)
local dead = self:GetAttribute("bgc-dead")
local dist = math.sqrt(dx * dx + dy * dy)
if dist < dead then
	self:SetAttribute("bgc-res", "cancel")
	return false
end
local angle = math.atan2(dy, dx) * 57.295779513
if angle < 0 then
	angle = angle + 360
end
local kind, counted
for name, a1, a2, c in gmatch(self:GetAttribute("bgc-sectors") or "", "([^;,]+),([^;,]+),([^;,]+),([^;,]+)") do
	if angle >= tonumber(a1) and angle < tonumber(a2) then
		kind = name
		counted = (c == "1")
	end
end
local template = kind and self:GetAttribute("bgc-tpl-" .. kind)
if not template or template == "" then
	self:SetAttribute("bgc-res", "cancel")
	return false
end
local count = ""
if counted then
	local n = floor((dist - dead) / self:GetAttribute("bgc-band")) + 1
	local maxCount = self:GetAttribute("bgc-maxcount")
	if n > maxCount then
		count = maxCount .. "+"
	else
		count = tostring(n)
	end
end
local message = gsub(gsub(template, "<n>", count), "<loc>", self:GetAttribute("bgc-loc"))
self:SetAttribute("bgc-msg", message)
if self:GetAttribute("bgc-test") == "print" then
	self:SetAttribute("bgc-res", "test")
	return false
end
self:SetAttribute("macrotext", self:GetAttribute("bgc-prefix") .. " " .. message)
self:SetAttribute("bgc-res", "sent")
]=]
Secure.SNIPPET = SNIPPET -- for tools/checks

-- Blizzard refuses, at the first click, any snippet whose text holds "{", "}" or the word
-- "function" anywhere, comments and strings included (RestrictedExecution.lua). Say so at load.
if string.find(SNIPPET, "[{}]") or string.find(SNIPPET, "function", 1, true) then
	ns.Print("|cffff4040internal error: the secure snippet holds { } or 'function'; callouts won't work.|r")
end

local function setAttr(name, value)
	if applied[name] ~= value then
		overlay:SetAttribute(name, value)
		applied[name] = value
	end
end

local function round(value, step)
	return math.floor(value / step + 0.5) * step
end

---------------------------------------------------------------------------------------------------
-- Configuration handed to the snippet (out of combat only).

local function sectorsString()
	local parts = {}
	for _, sector in ipairs(ns.SECTORS) do
		parts[#parts + 1] = sector.kind .. "," .. sector.from .. "," .. sector.to .. "," .. (sector.counted and "1" or "0")
	end
	return table.concat(parts, ";")
end

local function nodesString(nodes)
	local parts = {}
	for _, node in ipairs(nodes) do
		parts[#parts + 1] = node.code .. "," .. node.x .. "," .. node.y
	end
	return table.concat(parts, ";")
end

local function instancePrefix()
	local slash = _G.SLASH_INSTANCE_CHAT1
	if type(slash) == "string" and not ns.IsSecret(slash) and string.match(slash, "^/%S+$") then
		return slash
	end
	return "/i"
end

function Secure.Prefix()
	local cur = ns.current
	if ns.db.test == "say" and not (cur.ctx and cur.ctx.inBG) then
		return "/s"
	end
	return instancePrefix()
end

local function applyMouse()
	pcall(overlay.SetMouseClickEnabled, overlay, true)
	pcall(overlay.SetMouseMotionEnabled, overlay, ns.db.motion and true or false)
end

function Secure.SyncConfig()
	if not overlay then
		return
	end
	if InCombatLockdown() then
		pendingConfig = true
		return
	end
	pendingConfig = false
	local cur = ns.current
	setAttr("bgc-active", cur.active and true or false)
	setAttr("bgc-mod", ns.db.modifier)
	setAttr("bgc-test", (ns.db.test == "print") and "print" or "off")
	setAttr("bgc-prefix", Secure.Prefix())
	setAttr("bgc-size", G.size)
	setAttr("bgc-dead", G.dead)
	setAttr("bgc-band", G.band)
	setAttr("bgc-maxcount", G.maxCount)
	setAttr("bgc-sectors", sectorsString())
	for kind, text in pairs(cur.templates) do
		setAttr("bgc-tpl-" .. kind, text)
	end
	setAttr("bgc-nodes", nodesString(cur.nodes))
	applyMouse()
end

---------------------------------------------------------------------------------------------------
-- Following the map (out of combat): the button covers the map's visible area, and the snippet
-- gets how to turn a point of that area into map coordinates.

-- The map's visible area (c) and its canvas (v) in UIParent units, written into `out` (the
-- tracker reuses one table, so nothing is allocated 5 times a second).
local function measure(map, out)
	local container = map.ScrollContainer
	local canvas = (map.GetCanvas and map:GetCanvas()) or (container and container.Child)
	if not (container and canvas) then
		return nil
	end
	local ok1, cl, cb, cw, ch = pcall(container.GetRect, container)
	local ok2, vl, vb, vw, vh = pcall(canvas.GetRect, canvas)
	if not (ok1 and ok2) or ns.IsSecret(cl) or ns.IsSecret(vl) then
		return nil
	end
	if not (cl and cb and cw and ch and vl and vb and vw and vh) or cw <= 0 or ch <= 0 or vw <= 0 or vh <= 0 then
		return nil
	end
	local ui = UIParent:GetEffectiveScale()
	local ce = container:GetEffectiveScale() / ui
	local ve = canvas:GetEffectiveScale() / ui
	out = out or { c = {}, v = {} }
	local c, v = out.c, out.v
	c.l, c.b, c.w, c.h = cl * ce, cb * ce, cw * ce, ch * ce
	v.l, v.b, v.w, v.h = vl * ve, vb * ve, vw * ve, vh * ve
	return out
end
local rectsBuffer = { c = {}, v = {} }

-- The button's place over the map, and how a point of it becomes map coordinates. The map can
-- zoom (mouse wheel) and pan (drag) at any time; out of combat this follows it 5 times a second.
local function transformOf(rects)
	local c, v = rects.c, rects.v
	return round(c.l, 0.01), round(c.b, 0.01), round(c.w, 0.01), round(c.h, 0.01),
		round(c.w / v.w, 0.0001), round((c.l - v.l) / v.w, 0.0001), round(c.h / v.h, 0.0001), round((c.b - v.b) / v.h, 0.0001)
end

-- In combat the snippet keeps the last values: has the map zoomed, panned or moved since?
local function mapMovedSinceApplied(rects)
	if not applied["bgc-ax"] then
		return false
	end
	local l, b, w, h, ax, bx, ay, by = transformOf(rects)
	return math.abs(l - applied["bgc-l"]) > 1 or math.abs(b - applied["bgc-b"]) > 1
		or math.abs(w - applied["bgc-w"]) > 1 or math.abs(h - applied["bgc-h"]) > 1
		or math.abs(ax - applied["bgc-ax"]) > 0.002 or math.abs(bx - applied["bgc-bx"]) > 0.002
		or math.abs(ay - applied["bgc-ay"]) > 0.002 or math.abs(by - applied["bgc-by"]) > 0.002
end

-- The place under the cursor on the map as drawn now (for the log: in combat after a zoom it can
-- differ from the snippet's pick).
local function placeUnderCursor(rects)
	if not rects then
		return nil
	end
	local x, y = GetCursorPosition()
	local ui = UIParent:GetEffectiveScale()
	local v = rects.v
	local mx = (x / ui - v.l) / v.w
	local my = 1 - (y / ui - v.b) / v.h
	local best, bestD
	for _, node in ipairs(ns.current.nodes) do
		local ex, ey = (node.x - mx) * v.w, (node.y - my) * v.h
		local d = ex * ex + ey * ey
		if not bestD or d < bestD then
			best, bestD = node.code, d
		end
	end
	return best, round(mx, 0.001), round(my, 0.001)
end

local function setHome(rects, force)
	local l, b, w, h, ax, bx, ay, by = transformOf(rects)
	local v = rects.v
	setAttr("bgc-l", l)
	setAttr("bgc-b", b)
	setAttr("bgc-w", w)
	setAttr("bgc-h", h)
	setAttr("bgc-ax", ax)
	setAttr("bgc-bx", bx)
	setAttr("bgc-ay", ay)
	setAttr("bgc-by", by)
	setAttr("bgc-pw", round(v.w, 0.01))
	setAttr("bgc-ph", round(v.h, 0.01))
	local key = l .. "," .. b .. "," .. w .. "," .. h
	if (force or key ~= homeKey) and not overlay:GetAttribute("bgc-open") then
		homeKey = key
		overlay:ClearAllPoints()
		overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
		overlay:SetSize(w, h)
	end
end

-- Close a gesture whose release never reached the button (out of combat only).
local function forceClose()
	if not overlay or InCombatLockdown() then
		return
	end
	overlay:SetAttribute("bgc-open", nil)
	if lastRects then
		setHome(lastRects, true)
	else
		overlay:Hide()
	end
	ns.Wheel.Close()
end

local refreshLeft = 0
local openUpTicks = 0

local tracker

local function tick(elapsed)
	-- A slow refresh, in case points of interest change without an event.
	refreshLeft = refreshLeft - elapsed
	if refreshLeft <= 0 then
		refreshLeft = 5
		ns.Refresh()
	end

	local map = _G.BattlefieldMapFrame
	local rects
	if ns.current.active and map and map:IsVisible() then
		rects = measure(map, rectsBuffer)
		if rects and not ns.current.fakeMapID and ns.ShownMapID() ~= ns.current.mapID then
			ns.Refresh()
		end
	end
	if rects then
		lastRects = lastRects or { c = {}, v = {} }
		local c, v = lastRects.c, lastRects.v
		c.l, c.b, c.w, c.h = rects.c.l, rects.c.b, rects.c.w, rects.c.h
		v.l, v.b, v.w, v.h = rects.v.l, rects.v.b, rects.v.w, rects.v.h
	end

	-- Map zoomed, panned or moved during combat, or opened during combat (the button can't be shown
	-- then): the secure part still uses the old view.
	local moved = (overlay and rects and InCombatLockdown()
		and (not overlay:IsShown() or mapMovedSinceApplied(rects))) and true or false
	if moved ~= ns.mapMoved then
		ns.mapMoved = moved
		if moved then
			ns.Log("map_moved", { rects = rects, applied = { l = applied["bgc-l"], b = applied["bgc-b"], w = applied["bgc-w"],
				h = applied["bgc-h"], ax = applied["bgc-ax"], bx = applied["bgc-bx"], ay = applied["bgc-ay"], by = applied["bgc-by"] } })
		end
	end
	ns.MapVisuals.Update(rects)

	if not overlay then
		Secure.Create()
	end
	if not overlay or InCombatLockdown() then
		return
	end
	if pendingConfig then
		Secure.SyncConfig()
	end
	-- Open with the button up on two ticks running (0.2 s apart): the release was missed.
	if overlay:GetAttribute("bgc-open") and not IsMouseButtonDown("MiddleButton") then
		openUpTicks = openUpTicks + 1
		if openUpTicks >= 2 then
			openUpTicks = 0
			forceClose()
		end
	else
		openUpTicks = 0
	end
	if rects then
		setHome(rects)
		if not overlay:IsShown() then
			overlay:Show()
		end
	elseif overlay:IsShown() then
		overlay:Hide()
	end
	-- Inactive and everything put away: stop ticking until a battleground or test mode.
	if not ns.current.active and not overlay:IsShown() and not ns.perfRun then
		tracker:Hide()
	end
end

-- The tracker only runs while BGComs is active (a battleground or test mode), 5 times a second.
-- Outside, BGComs runs nothing at all per frame.
tracker = CreateFrame("Frame")
tracker:Hide()
local tickWait = 0
tracker:SetScript("OnUpdate", function(_, elapsed)
	tickWait = tickWait + elapsed
	if tickWait < 0.2 then
		return
	end
	local step = tickWait
	tickWait = 0
	if ns.db and not ns.perfPaused then
		local t0, kb0 = ns.PerfBegin()
		ns.SafeCall(tick, step)
		ns.PerfEnd(t0, kb0, "tracker")
	end
end)

function Secure.UpdateTracker()
	if ns.current.active or ns.perfRun or (overlay and overlay:IsShown()) then
		tracker:Show()
	end
end

---------------------------------------------------------------------------------------------------
-- After each click (insecure, runs after the secure part): the wheel, placing, the log.

local lastSeq, lastDownSeq = 0, 0
local justPlaced = false

local function r(value, step)
	if type(value) ~= "number" then
		return value
	end
	return round(value, step)
end

local function report(self)
	local res = self:GetAttribute("bgc-res")
	local entry = {
		res = res,
		loc = self:GetAttribute("bgc-loc"),
		mx = r(self:GetAttribute("bgc-mx"), 0.001),
		my = r(self:GetAttribute("bgc-my"), 0.001),
	}
	if res == "sent" or res == "test" or res == "cancel" then
		entry.dx = r(self:GetAttribute("bgc-dx"), 0.1)
		entry.dy = r(self:GetAttribute("bgc-dy"), 0.1)
	end
	if res == "sent" or res == "test" then
		entry.msg = self:GetAttribute("bgc-msg")
		entry.macro = (res == "sent") and self:GetAttribute("macrotext") or nil
	end
	entry.test = ns.db.test
	entry.key = ns.current.key
	entry.lockdown = ns.ChatLockdown()
	ns.Log("gesture", entry)

	-- A flash only for what was sent; a cancel shows nothing (it only cluttered the view).
	if res == "sent" then
		ns.Wheel.Flash(entry.msg, 0.3, 1, 0.3)
	elseif res == "test" then
		ns.Wheel.Flash(entry.msg, 1, 0.82, 0)
	elseif res == "noloc" and not justPlaced then
		ns.Print("no place known on this map. /bgc place CODE adds one, /bgc debug shows what the map has.")
	end

	-- Test mode: a debug line for every gesture.
	if ns.db.test ~= "off" and not (ns.current.ctx and ns.current.ctx.inBG) then
		ns.Print(string.format("|cff999999[test]|r %s: %s | place %s, map %s, %s | drag %s, %s%s",
			tostring(res), tostring(entry.msg or "-"), tostring(entry.loc or "-"),
			tostring(entry.mx), tostring(entry.my), tostring(entry.dx or "-"), tostring(entry.dy or "-"),
			entry.macro and (" | macro: " .. entry.macro) or ""))
	end
end

local function onPostClick(self, button, down)
	if button ~= "MiddleButton" then
		return
	end
	justPlaced = false
	if down then
		local downSeq = self:GetAttribute("bgc-downseq") or 0
		if downSeq ~= lastDownSeq then
			lastDownSeq = downSeq
			local trueLoc, trueX, trueY = placeUnderCursor(lastRects)
			ns.Log("press", { loc = self:GetAttribute("bgc-loc"), open = self:GetAttribute("bgc-open") and true or nil,
				mx = r(self:GetAttribute("bgc-mx"), 0.001), my = r(self:GetAttribute("bgc-my"), 0.001),
				mapMoved = ns.mapMoved or nil, shownLoc = trueLoc, shownX = trueX, shownY = trueY })
			if ns.placing then
				ns.FinishPlacing(self:GetAttribute("bgc-mx"), self:GetAttribute("bgc-my"))
				justPlaced = true
				forceClose()
			end
		end
		if self:GetAttribute("bgc-open") then
			ns.Wheel.Open(self:GetAttribute("bgc-loc"))
		end
	else
		ns.Wheel.Close()
	end
	local seq = self:GetAttribute("bgc-seq") or 0
	if seq ~= lastSeq then
		lastSeq = seq
		report(self)
	end
end

---------------------------------------------------------------------------------------------------
-- Creation: secure frames can't be made in combat, so this waits for the end of combat if needed.

function Secure.Create()
	if overlay or InCombatLockdown() or not ns.db then
		return
	end
	header = CreateFrame("Frame", "BGComsSecureHeader", UIParent, "SecureHandlerBaseTemplate")
	overlay = CreateFrame("Button", "BGComsOverlay", UIParent, "SecureActionButtonTemplate")
	overlay:SetFrameStrata("DIALOG")
	overlay:SetFrameLevel(50)
	overlay:SetSize(10, 10)
	overlay:SetPoint("CENTER")
	overlay:RegisterForClicks("MiddleButtonDown", "MiddleButtonUp")
	overlay:SetAttribute("useOnKeyDown", false)
	overlay:SetAttribute("type", "macro")
	overlay:EnableMouseWheel(false)
	local ok, err = pcall(overlay.SetPassThroughButtons, overlay, "LeftButton", "RightButton", "Button4", "Button5")
	Secure.passThrough = ok and true or tostring(err)
	applyMouse()
	SecureHandlerWrapScript(overlay, "OnClick", header, SNIPPET)
	overlay:SetScript("PostClick", function(self, button, down)
		ns.SafeCall(onPostClick, self, button, down)
	end)
	overlay:Hide()
	wipe(applied)
	homeKey = nil
	Secure.SyncConfig()
end

ns.Listen("LOGIN", function()
	Secure.Create()
end)

ns.Listen("COMBAT_END", function()
	Secure.Create()
	if pendingConfig then
		Secure.SyncConfig()
	end
end)

ns.Listen("NODES_CHANGED", function()
	Secure.SyncConfig()
	Secure.UpdateTracker()
end)

ns.Listen("SETTINGS_CHANGED", function()
	Secure.SyncConfig()
	Secure.UpdateTracker()
end)

ns.Listen("WORLD", function()
	Secure.UpdateTracker()
end)

ns.Listen("PERF_START", function()
	Secure.UpdateTracker()
end)

ns.Listen("WHEEL_ABANDONED", function()
	forceClose()
end)

---------------------------------------------------------------------------------------------------
-- The battlefield map in battlegrounds (option "Open the battlefield map in battlegrounds").
--
-- Blizzard's map opens itself on PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA and NEW_WMO_CHUNK
-- when its setting showBattlefieldMinimap is "1" and its addon is loaded (Blizzard_BattlefieldMap,
-- Mainline OnEvent; Leatrix Maps loads that addon at login). So on the way into a battleground
-- BGComs only switches the setting on, and Blizzard's own code opens the map.
-- BGComs never shows or hides Blizzard's map itself: that would run the map's code tainted, and its
-- pins then call protected functions that get blocked (map addons that show or hide maps
-- themselves get blamed for such errors). On the way out, if the map was closed before, the setting goes back to "0": the map
-- doesn't come back by itself, but stays on screen until Shift-M closes it.

local MAP_CVAR = "showBattlefieldMinimap"
local mapNoticeDue

local function mapSetting()
	local ok, value = pcall(GetCVar, MAP_CVAR)
	return ok and value or nil
end

local function headingToBattleground()
	if not (GetMaxBattlefieldID and GetBattlefieldStatus) then
		return false
	end
	local okMax, max = pcall(GetMaxBattlefieldID)
	for i = 1, (okMax and tonumber(max) or 0) do
		local ok, status = pcall(GetBattlefieldStatus, i)
		if ok and (status == "confirm" or status == "active") then
			return true
		end
	end
	return false
end

local function ensureMapLoaded()
	local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
	if isLoaded and isLoaded("Blizzard_BattlefieldMap") then
		return true
	end
	-- Not loaded yet (Leatrix Maps loads it at login): load it as Leatrix Maps does.
	local load = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
	local ok, loaded = pcall(load, "Blizzard_BattlefieldMap")
	ns.Log("map_load", { ok = ok, loaded = ok and loaded or tostring(loaded) })
	return ok and loaded
end

local function openMapForBattleground()
	if not ns.db.autoMap then
		return
	end
	local value = mapSetting()
	if ns.db.mapRestore == nil then
		local map = _G.BattlefieldMapFrame
		local open = value == "1" or (map and map:IsShown())
		ns.db.mapRestore = open and "keep" or "0"
		ns.Log("map_open", { setting = value, restore = ns.db.mapRestore })
	end
	if value ~= "1" then
		pcall(SetCVar, MAP_CVAR, "1")
	end
	ensureMapLoaded()
end

local function restoreMapSetting()
	local restore = ns.db.mapRestore
	ns.db.mapRestore = nil
	if restore == "0" then
		pcall(SetCVar, MAP_CVAR, "0")
		mapNoticeDue = true
	end
	ns.Log("map_restore", { restore = restore })
end

ns.On("PLAYER_LEAVING_WORLD", function()
	if not ns.db then
		return
	end
	local _, instanceType = IsInInstance()
	if instanceType == "pvp" then
		restoreMapSetting()
	elseif headingToBattleground() then
		openMapForBattleground()
	end
end)

ns.Listen("WORLD", function()
	local _, instanceType = IsInInstance()
	if instanceType == "pvp" then
		-- Also here, for a /reload in a battleground or a missed PLAYER_LEAVING_WORLD: the map then
		-- opens at Blizzard's next zone change event.
		openMapForBattleground()
	elseif ns.db.mapRestore then
		restoreMapSetting()
	end
	if mapNoticeDue then
		mapNoticeDue = nil
		local map = _G.BattlefieldMapFrame
		if map and map:IsShown() then
			ns.Print("the battleground map stays open: Shift-M closes it. It won't open by itself outside battlegrounds.")
		end
	end
end)

---------------------------------------------------------------------------------------------------
-- /bgc debug: the button and what it was given.

ns.AddDebugPart("secure", function()
	local part = { created = overlay ~= nil, passThrough = Secure.passThrough, pendingConfig = pendingConfig,
		homeKey = homeKey, lastRects = lastRects, prefix = Secure.Prefix(),
		mapSetting = mapSetting(), mapRestore = ns.db.mapRestore, autoMap = ns.db.autoMap }
	local map = _G.BattlefieldMapFrame
	part.map = map and {
		loaded = true,
		visible = map:IsVisible(),
		strata = map:GetFrameStrata(),
		level = map:GetFrameLevel(),
		mapID = ns.ShownMapID(),
		rects = map:IsVisible() and measure(map) or nil,
	} or { loaded = false }
	if overlay then
		local l, b, w, h = overlay:GetRect()
		part.overlay = {
			shown = overlay:IsShown(),
			visible = overlay:IsVisible(),
			rect = { l = l, b = b, w = w, h = h },
			strata = overlay:GetFrameStrata(),
			level = overlay:GetFrameLevel(),
			protected = { overlay:IsProtected() },
			clickEnabled = overlay.IsMouseClickEnabled and overlay:IsMouseClickEnabled(),
			motionEnabled = overlay.IsMouseMotionEnabled and overlay:IsMouseMotionEnabled(),
		}
		part.attributes = {}
		for _, name in ipairs({ "type", "useOnKeyDown", "macrotext", "bgc-active", "bgc-mod", "bgc-test", "bgc-prefix",
			"bgc-l", "bgc-b", "bgc-w", "bgc-h", "bgc-ax", "bgc-bx", "bgc-ay", "bgc-by", "bgc-pw", "bgc-ph",
			"bgc-nodes", "bgc-sectors", "bgc-open", "bgc-loc", "bgc-msg", "bgc-res", "bgc-seq", "bgc-downseq",
			"bgc-mx", "bgc-my", "bgc-dx", "bgc-dy" }) do
			part.attributes[name] = overlay:GetAttribute(name)
		end
	end
	return part
end)
