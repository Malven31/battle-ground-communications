-- BGComs (Battle Ground Communications): battleground callouts from the battlefield map.
-- Core: namespace, secret checks, saved settings, the log, events and the /bgc command.
--
-- How a callout goes out (see Secure.lua): Alt + middle-click on the Shift-M map presses an
-- invisible secure button. Its restricted snippet picks the nearest location, the release picks
-- the call and the count from the drag, and the button runs "/i <message>" as a macro. During a
-- battleground match addon code can't send chat itself, but a macro the player triggers can.

local ADDON, ns = ...

ns.name = ADDON
local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMetadata and getMetadata(ADDON, "Version")) or "dev"

function ns.Print(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	print("|cff4fb3ffBGComs|r: " .. table.concat(parts, " "))
end

---------------------------------------------------------------------------------------------------
-- Secret values: some API results can be held but not looked at. Check before any comparison.

local issecret = type(issecretvalue) == "function" and issecretvalue or nil

function ns.IsSecret(value)
	return issecret ~= nil and issecret(value) and true or false
end

-- A copy safe to keep in the saved variables: secrets become "<secret>", functions and frames a word.
function ns.Plain(value, depth)
	depth = depth or 0
	if ns.IsSecret(value) then
		return "<secret>"
	end
	local kind = type(value)
	if kind == "table" then
		if depth >= 6 then
			return "{...}"
		end
		local copy = {}
		for k, v in pairs(value) do
			if not ns.IsSecret(k) and (type(k) == "string" or type(k) == "number") then
				copy[k] = ns.Plain(v, depth + 1)
			end
		end
		return copy
	elseif kind == "function" or kind == "userdata" or kind == "thread" then
		return kind
	end
	return value
end

---------------------------------------------------------------------------------------------------
-- Safe calls: an error is reported once (BugGrabber picks it up), never every frame.

ns.errors = {}

local function onError(err)
	err = tostring(err)
	local seen = ns.errors[err]
	ns.errors[err] = (seen or 0) + 1
	if not seen then
		local handler = geterrorhandler and geterrorhandler()
		if handler then
			handler(err)
		end
	end
	return err
end

function ns.SafeCall(fn, ...)
	return xpcall(fn, onError, ...)
end

---------------------------------------------------------------------------------------------------
-- Saved settings (account-wide): BGComsDB.

local DEFAULTS = {
	modifier = "none", -- none | alt | ctrl | shift: the key held with the middle button
	showNodes = true, -- the location codes drawn on the battlefield map
	test = "off", -- off | print (shown in your chat only) | say (sent with /s, to try the real send)
	testProfile = "grid", -- grid | ab | wsg | av | dsi: what test mode puts on the map
	testMapID = nil, -- the map whose art test mode draws (nil: found by name)
	motion = false, -- true: the overlay also takes mouse motion (map tooltips under it stop showing)
	autoMap = true, -- switch the battlefield map's own setting on in battlegrounds (Blizzard opens it)
	places = {}, -- [mapID] = { [code] = { x = 0..1, y = 0..1 } }: positions set with /bgc place
	templates = {}, -- [kind] = text: your own message texts ("" switches a call off)
}
ns.DEFAULTS = DEFAULTS

local function fillGaps(target, source)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			fillGaps(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

local function initDB()
	if type(BGComsDB) ~= "table" then
		BGComsDB = {}
	end
	local db = BGComsDB
	fillGaps(db, DEFAULTS)
	if type(db.log) ~= "table" then
		db.log = {}
	end
	-- 0.1.1: a plain middle-click by default (it was Alt + middle-click). Once, so a later
	-- /bgc mod alt stays.
	if not db.plainClickMigrated then
		db.plainClickMigrated = true
		if db.modifier == "alt" then
			db.modifier = "none"
		end
	end
	ns.db = db
end

---------------------------------------------------------------------------------------------------
-- Log: a ring buffer in the saved variables (written on /reload or logout), always on: it holds
-- each callout gesture and its result, blocked actions, and battleground entries. Plain values only.

local LOG_MAX = 300

function ns.Log(kind, data)
	local db = ns.db
	if not db then
		return
	end
	local log = db.log
	log[#log + 1] = {
		t = math.floor(GetTime() * 1000) / 1000,
		k = kind,
		c = InCombatLockdown() and 1 or nil,
		d = data,
	}
	while #log > LOG_MAX do
		table.remove(log, 1)
	end
end

---------------------------------------------------------------------------------------------------
-- Internal messages between the files.

local listeners = {}

function ns.Listen(message, fn)
	listeners[message] = listeners[message] or {}
	table.insert(listeners[message], fn)
end

function ns.Fire(message, ...)
	local list = listeners[message]
	if not list then
		return
	end
	for i = 1, #list do
		ns.SafeCall(list[i], message, ...)
	end
end

---------------------------------------------------------------------------------------------------
-- Game events. Registration is pcall'd: an event this client doesn't have is noted for /bgc debug.

local eventFrame = CreateFrame("Frame")
local handlers = {}
ns.unknownEvents = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		ns.SafeCall(list[i], event, ...)
	end
end)

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
			ns.unknownEvents[event] = true
		end
	end
	table.insert(handlers[event], fn)
end

---------------------------------------------------------------------------------------------------
-- Debug snapshot (/bgc debug): each file adds its part with ns.AddDebugPart(name, fn).

local debugParts = {}

function ns.AddDebugPart(name, fn)
	debugParts[#debugParts + 1] = { name = name, fn = fn }
end

function ns.SaveDebug()
	local snapshot = {
		time = date("%Y-%m-%d %H:%M:%S"),
		version = ns.version,
		combat = InCombatLockdown() and true or false,
		settings = ns.Plain({
			modifier = ns.db.modifier,
			showNodes = ns.db.showNodes,
			test = ns.db.test,
			motion = ns.db.motion,
		}),
		places = ns.Plain(ns.db.places),
		unknownEvents = ns.Plain(ns.unknownEvents),
		errors = ns.Plain(ns.errors),
	}
	for i = 1, #debugParts do
		local part = debugParts[i]
		local ok, result = pcall(part.fn)
		snapshot[part.name] = ns.Plain(ok and result or ("error: " .. tostring(result)))
	end
	ns.db.debug = snapshot
	ns.Print("state saved into BGComsDB.debug. It is written to disk on /reload or logout.")
end

---------------------------------------------------------------------------------------------------
-- /bgc perf: what BGComs costs, measured in-game. Three phases of PERF_SECONDS:
--   normal: whatever runs now (test mode or a battleground, Shift-M open, for a meaningful run);
--   wheel: the wheel open at the screen centre with a simulated cursor sweeping round and in and
--     out, so it repaints every frame (the worst case; a real wheel only works when the mouse moves);
--   paused: BGComs' tracker skipped and the wheel closed (the baseline).
-- Per phase: frames and frame time, BGComs' own Lua time per frame (debugprofilestop around each of
-- its OnUpdate runs) and its worst run, the memory it allocated, the game's add-on profiler for
-- BGComs (last 60 frames) and its count of frames over 1 ms. Saved into BGComsDB.perf.

local PERF_SECONDS = 6
local PERF_PHASES = {
	{ name = "normal" },
	{ name = "wheel open, simulated cursor", wheel = true },
	{ name = "BGComs paused (baseline)", paused = true },
}
local run -- the measurement in progress

-- Around each OnUpdate run of ours (Secure.lua's tracker, Wheel.lua's wheel). Nothing when idle.
function ns.PerfBegin()
	if run then
		return debugprofilestop(), collectgarbage("count")
	end
end

function ns.PerfEnd(t0, kb0, part)
	if not (t0 and run) then
		return
	end
	local phase = run.phase
	local ms = debugprofilestop() - t0
	phase.ms = phase.ms + ms
	phase.calls = phase.calls + 1
	if ms > phase.worst then
		phase.worst = ms
	end
	phase.parts[part] = (phase.parts[part] or 0) + ms
	local kb = collectgarbage("count") - kb0
	if kb > 0 then
		phase.kb = phase.kb + kb
	end
end

local Metric = (Enum and Enum.AddOnProfilerMetric) or {}

local function profiler(name, ...)
	local fn = C_AddOnProfiler and C_AddOnProfiler[name]
	if not fn then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and type(value) == "number" and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function memoryKB()
	if not (_G.UpdateAddOnMemoryUsage and _G.GetAddOnMemoryUsage) then
		return nil
	end
	pcall(_G.UpdateAddOnMemoryUsage)
	local ok, kb = pcall(_G.GetAddOnMemoryUsage, ADDON)
	return ok and kb or nil
end

local perfFrame = CreateFrame("Frame")
perfFrame:Hide()

local function startPhase(index)
	local spec = PERF_PHASES[index]
	run.phase = { name = spec.name, start = GetTime(), frames = 0, frameMs = 0, worstFrame = 0, ms = 0, calls = 0,
		worst = 0, kb = 0, parts = {}, over1 = profiler("GetAddOnMetric", ADDON, Metric.CountTimeOver1Ms or 5) }
	run.index = index
	ns.perfPaused = spec.paused and true or nil
	if spec.wheel then
		ns.Wheel.Open("GM", true)
	end
end

local function finishPhase()
	local phase = run.phase
	local spec = PERF_PHASES[run.index]
	if spec.wheel then
		ns.Wheel.Close()
	end
	ns.perfPaused = nil
	local duration = math.max(GetTime() - phase.start, 0.001)
	local frames = math.max(phase.frames, 1)
	local over1 = profiler("GetAddOnMetric", ADDON, Metric.CountTimeOver1Ms or 5)
	local result = {
		name = phase.name,
		seconds = math.floor(duration * 10 + 0.5) / 10,
		frames = phase.frames,
		fps = math.floor(phase.frames / duration * 10 + 0.5) / 10,
		frameMs = math.floor(phase.frameMs / frames * 100 + 0.5) / 100,
		worstFrameMs = math.floor(phase.worstFrame * 10 + 0.5) / 10,
		luaMsPerFrame = phase.ms / frames,
		luaWorstMs = phase.worst,
		runs = phase.calls,
		parts = phase.parts,
		allocatedKBPerSecond = phase.kb / duration,
		profilerRecentMs = profiler("GetAddOnMetric", ADDON, Metric.RecentAverageTime or 1),
		profilerFramesOver1Ms = (over1 and phase.over1) and (over1 - phase.over1) or nil,
	}
	run.results[#run.results + 1] = result
	ns.Print(string.format("%s: %.0f fps (frame %.1f ms, worst %.0f ms). BGComs: %.4f ms per frame, worst run %.3f ms, "
		.. "%.2f KB/s allocated; game profiler %s ms, frames over 1 ms: %s.",
		result.name, result.fps, result.frameMs, result.worstFrameMs, result.luaMsPerFrame, result.luaWorstMs,
		result.allocatedKBPerSecond, result.profilerRecentMs and string.format("%.4f", result.profilerRecentMs) or "?",
		tostring(result.profilerFramesOver1Ms or "?")))
end

perfFrame:SetScript("OnUpdate", function(_, elapsed)
	if not run then
		perfFrame:Hide()
		return
	end
	local phase = run.phase
	phase.frames = phase.frames + 1
	phase.frameMs = phase.frameMs + elapsed * 1000
	if elapsed * 1000 > phase.worstFrame then
		phase.worstFrame = elapsed * 1000
	end
	if GetTime() - phase.start >= PERF_SECONDS then
		finishPhase()
		if run.index < #PERF_PHASES then
			startPhase(run.index + 1)
		else
			local cur = ns.current or {}
			local profilerOn
			if C_AddOnProfiler and C_AddOnProfiler.IsEnabled then
				local ok, enabled = pcall(C_AddOnProfiler.IsEnabled)
				profilerOn = ok and enabled or "error"
			end
			-- Memory only before and after the whole run: updating it walks every addon (a spike).
			local memoryAfter = memoryKB()
			ns.db.perf = {
				time = date("%Y-%m-%d %H:%M:%S"),
				version = ns.version,
				context = { active = cur.active, key = cur.key, test = ns.db.test, mapShown = _G.BattlefieldMapFrame
					and _G.BattlefieldMapFrame:IsVisible() or false, combat = InCombatLockdown() and true or false },
				profilerEnabled = profilerOn,
				memoryKBBefore = run.memoryBefore,
				memoryKBAfter = memoryAfter,
				phases = run.results,
			}
			ns.Print(string.format("memory: %s KB.", memoryAfter and string.format("%.0f", memoryAfter) or "?"))
			run = nil
			ns.perfRun = nil
			perfFrame:Hide()
			ns.Fire("PERF_DONE")
			ns.Print("done, saved into BGComsDB.perf (written on /reload or logout).")
		end
	end
end)

function ns.StartPerf()
	if run then
		ns.Print("a measurement is already running.")
		return
	end
	if not (ns.current and ns.current.active) then
		ns.Print("|cffff8000BGComs is inactive here, so 'normal' measures nothing: /bgc test ab and Shift-M first for a meaningful run.|r")
	end
	ns.Print("measuring for " .. (PERF_SECONDS * #PERF_PHASES) .. " s: stand still, don't open the wheel.")
	run = { results = {}, memoryBefore = memoryKB() }
	ns.perfRun = run
	ns.Fire("PERF_START")
	startPhase(1)
	perfFrame:Show()
end

---------------------------------------------------------------------------------------------------
-- Blocked actions: if the game refuses something of ours (a send, a frame change), log it.

local function onBlocked(event, addonName, func)
	if addonName ~= ADDON then
		return
	end
	ns.Log("blocked", { event = event, func = ns.Plain(func) })
	if not ns.warnedBlocked then
		ns.warnedBlocked = true
		ns.Print("the game blocked an action (" .. tostring(ns.Plain(func)) .. "). Please /bgc debug, then /reload, and report it.")
	end
end

ns.On("ADDON_ACTION_BLOCKED", onBlocked)
ns.On("ADDON_ACTION_FORBIDDEN", onBlocked)

---------------------------------------------------------------------------------------------------
-- /bgc

function ns.PrintHelp()
	ns.Print("v" .. ns.version .. ". On the battlefield map (Shift-M): " .. ns.ClickLabel() .. " near a place, drag, release.")
	print("   |cffffd100/bgc|r - options (Options > AddOns > BGComs); |cffffd100/bgc help|r - this list")
	print("   up |cffffd100INC|r, up-right |cffffd100SPOTTED|r (drag further = more: 1 to 5+), up-left |cffffd100HELP|r, down-left |cffffd100OMW|r, down |cffffd100CLEAR|r, down-right |cffffd100EFC|r (flag battlegrounds). Release in the centre to cancel.")
	print("   |cffffd100/bgc test ab say|r - outside battlegrounds: Arathi Basin drawn on your Shift-M map, callouts really sent with /s, plus a debug line")
	print("   |cffffd100/bgc test [grid|ab|wsg|av|dsi] [print|say]|r - print: shown in your chat only; |cffffd100/bgc test off|r to stop")
	print("   |cffffd100/bgc nodes|r - show or hide the place codes on the map")
	print("   |cffffd100/bgc place CODE|r - your next click on the map puts CODE there (out of combat); |cffffd100/bgc forget CODE|r undoes it")
	print("   |cffffd100/bgc mod alt|ctrl|shift|none|r - the key held with the middle button")
	print("   |cffffd100/bgc perf|r - measure what BGComs costs per frame (18 s; best with /bgc test ab and Shift-M open)")
	print("   |cffffd100/bgc debug|r - save the current state into the saved variables")
	if ns.StatusLine then
		print("   " .. ns.StatusLine())
	end
end

local TEST_MODES = { off = true, print = true, say = true }
local TEST_PROFILES = { grid = true, ab = true, wsg = true, av = true, dsi = true }

-- /bgc test [grid|ab|wsg|av|dsi] [print|say|off] [mapID]. Alone: on (print) or off.
function ns.SetTest(rest)
	local mode, profile, mapID
	for word in string.gmatch(string.lower(rest or ""), "%S+") do
		if TEST_MODES[word] then
			mode = word
		elseif TEST_PROFILES[word] then
			profile = word
		elseif tonumber(word) then
			mapID = tonumber(word)
		else
			ns.Print("/bgc test [grid | ab | wsg | av | dsi] [print | say | off] [mapID]")
			return
		end
	end
	if not mode then
		if profile or mapID then
			mode = (ns.db.test ~= "off") and ns.db.test or "print"
		else
			mode = (ns.db.test == "off") and "print" or "off"
		end
	end
	if profile then
		ns.db.testProfile = profile
		ns.db.testMapID = nil
	end
	if mapID then
		ns.db.testMapID = mapID
	end
	ns.db.test = mode
	if mode == "off" then
		ns.Print("test mode off: callouts only work in battlegrounds, and are sent to battleground chat.")
	else
		local name = ns.PROFILES and ns.PROFILES[ns.db.testProfile] and ns.PROFILES[ns.db.testProfile].name or "compass grid"
		if ns.db.testProfile == "grid" then
			name = "a compass grid (N, NE, E...)"
		end
		ns.Print("test mode: " .. name .. " on the battlefield map (Shift-M), outside battlegrounds. Callouts are "
			.. (mode == "say" and "|cffff8000really sent with /s|r (people near you see them)" or "shown in your chat only")
			.. ", each with a debug line. /bgc test off to stop.")
	end
	ns.Fire("SETTINGS_CHANGED")
end

function ns.SetModifier(rest)
	local mode = string.lower(rest or "")
	if mode ~= "alt" and mode ~= "ctrl" and mode ~= "shift" and mode ~= "none" then
		ns.Print("/bgc mod alt | ctrl | shift | none (now: " .. ns.db.modifier .. ")")
		return
	end
	ns.db.modifier = mode
	ns.Print("callouts now use " .. ns.ClickLabel() .. ".")
	ns.Fire("SETTINGS_CHANGED")
end

function ns.SetMotion(rest)
	local mode = string.lower(rest or "")
	if mode ~= "on" and mode ~= "off" then
		ns.Print("/bgc motion on | off (now: " .. (ns.db.motion and "on" or "off") .. "). On: try it if middle-clicks on the map do nothing.")
		return
	end
	ns.db.motion = (mode == "on")
	ns.Print("overlay mouse motion " .. mode .. ".")
	ns.Fire("SETTINGS_CHANGED")
end

-- "Middle-click", or "Alt + middle-click" with a modifier.
function ns.ClickLabel()
	local mod = ns.db and ns.db.modifier or "none"
	if mod == "none" then
		return "Middle-click"
	end
	return ((mod == "ctrl" and "Ctrl") or (mod == "shift" and "Shift") or "Alt") .. " + middle-click"
end

SLASH_BGCOMS1 = "/bgc"
SLASH_BGCOMS2 = "/bgcoms"
SlashCmdList.BGCOMS = function(message)
	if not ns.db then
		return
	end
	local command, rest = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
	command = string.lower(command or "")
	if command == "" or command == "options" then
		if ns.OpenOptions then
			ns.SafeCall(ns.OpenOptions)
		else
			ns.PrintHelp()
		end
	elseif command == "test" then
		ns.SetTest(rest)
	elseif command == "nodes" then
		ns.db.showNodes = not ns.db.showNodes
		ns.Print("place codes on the map " .. (ns.db.showNodes and "shown." or "hidden."))
		ns.Fire("SETTINGS_CHANGED")
	elseif command == "place" then
		ns.SafeCall(ns.StartPlacing, rest)
	elseif command == "forget" then
		ns.SafeCall(ns.ForgetPlace, rest)
	elseif command == "mod" then
		ns.SetModifier(rest)
	elseif command == "motion" then
		ns.SetMotion(rest)
	elseif command == "debug" then
		ns.SafeCall(ns.SaveDebug)
	elseif command == "perf" then
		ns.SafeCall(ns.StartPerf)
	else
		ns.PrintHelp()
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle: DB_READY (settings loaded), LOGIN (the UI is built), COMBAT_START, COMBAT_END,
-- WORLD (entered the world or changed zone), SETTINGS_CHANGED.

ns.On("ADDON_LOADED", function(_, addonName)
	if addonName == ADDON then
		initDB()
		ns.Fire("DB_READY")
	end
end)

ns.On("PLAYER_LOGIN", function()
	ns.Fire("LOGIN")
end)

ns.On("PLAYER_REGEN_DISABLED", function()
	ns.Fire("COMBAT_START")
end)

ns.On("PLAYER_REGEN_ENABLED", function()
	ns.Fire("COMBAT_END")
end)

ns.On("PLAYER_ENTERING_WORLD", function()
	ns.Fire("WORLD")
end)

ns.On("ZONE_CHANGED_NEW_AREA", function()
	ns.Fire("WORLD")
end)
