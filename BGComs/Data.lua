-- BGComs data: the drag menu (sectors, counts, message texts), the battlegrounds and their places,
-- and which places are known on the map shown (from the map's points of interest, built-in
-- positions, and positions set with /bgc place).

local _, ns = ...

---------------------------------------------------------------------------------------------------
-- The drag menu. Distances are in UI units (the overlay's and the wheel's, both children of
-- UIParent); angles in degrees, counter-clockwise from the right. Secure.lua hands the same values
-- to the restricted snippet, so what the wheel shows is what gets sent.

-- Matched to Blizzard's radial wheel art (Blizzard_RadialWheel: no selection within ~22 of the
-- centre, wedge icons 80 out): counts 1 to 5 fit inside the disc, "5+" past its rim.
ns.GEOMETRY = {
	dead = 22, -- release closer than this to the press point: cancel
	band = 22, -- each band further out adds one to the count
	maxCount = 5, -- beyond five bands: "5+"
	size = 440, -- the square the secure button grows to while the mouse is held
	iconRadius = 84, -- where each call's icon sits
}

ns.SECTORS = {
	{ kind = "spotted", from = 0, to = 60, counted = true, label = "SPOTTED" },
	{ kind = "inc", from = 60, to = 120, counted = true, label = "INC" },
	{ kind = "help", from = 120, to = 180, label = "HELP" },
	{ kind = "omw", from = 180, to = 240, label = "OMW" },
	{ kind = "clear", from = 240, to = 300, label = "CLEAR" },
	{ kind = "efc", from = 300, to = 360, label = "EFC", flagOnly = true },
}

-- <n> is the count, <loc> the place code. Not braces: a secure snippet whose text holds "{" or "}"
-- anywhere, even in a string, is refused ("Direct table creation is not permitted").
ns.TEMPLATES = {
	inc = "<n> inc <loc>",
	spotted = "<n> spotted <loc>",
	help = "help <loc>",
	omw = "omw <loc>",
	clear = "<loc> clear",
	efc = "EFC <loc>",
}

local DEG = 180 / math.pi

-- The texts in use: yours (Options, "" switches a call off) or the defaults; EFC only where there
-- is a flag to carry.
function ns.ActiveTemplates(profile)
	local result = {}
	local custom = ns.db and ns.db.templates
	for _, sector in ipairs(ns.SECTORS) do
		local text = (custom and custom[sector.kind]) or ns.TEMPLATES[sector.kind] or ""
		if sector.flagOnly and not (profile and profile.flag) then
			text = ""
		end
		result[sector.kind] = text
	end
	return result
end

function ns.CountText(dist)
	local g = ns.GEOMETRY
	local n = math.floor((dist - g.dead) / g.band) + 1
	if n > g.maxCount then
		return g.maxCount .. "+", g.maxCount + 1
	end
	return tostring(n), n
end

-- Same rules as the release snippet in Secure.lua: returns the sector (or nil: cancel), the count
-- text for counted sectors, and the band index.
function ns.Classify(dx, dy, templates)
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist < ns.GEOMETRY.dead then
		return nil
	end
	local angle = math.atan2(dy, dx) * DEG
	if angle < 0 then
		angle = angle + 360
	end
	for _, sector in ipairs(ns.SECTORS) do
		if angle >= sector.from and angle < sector.to then
			local text = templates and templates[sector.kind]
			if not text or text == "" then
				return nil, nil, nil, sector
			end
			if sector.counted then
				local count, band = ns.CountText(dist)
				return sector, count, band
			end
			return sector
		end
	end
	return nil
end

-- Same substitution as the snippet (plain gsub, the place codes hold no "%").
function ns.FormatMessage(template, count, loc)
	local text = string.gsub(template, "<n>", count or "")
	text = string.gsub(text, "<loc>", loc or "")
	return text
end

---------------------------------------------------------------------------------------------------
-- Battlegrounds. A place has a code (what is sent), words that find it among the map's points of
-- interest (lower case, no accents: string.lower leaves "É" alone), and a built-in position used
-- when no point of interest matches. Positions are map coordinates (0..1, y down).
--
-- Built-in positions are rough. /bgc nodes shows them on the map, /bgc place moves them.

ns.PROFILES = {
	ab = {
		name = "Arathi Basin",
		instanceID = 529,
		-- Its map, for /bgc test ab: these IDs first (Forever uses Classic's map IDs: Stormwind is
		-- 1453), then a search by name.
		mapIDs = { 1461, 93, 1366 },
		mapNames = { "arathi basin", "bassin arathi", "bassin d'arathi", "bassin d’arathi" },
		flag = false,
		nodes = {
			{ code = "ST", match = { "stable", "curie" }, x = 0.374, y = 0.292 },
			{ code = "GM", match = { "gold mine", "mine d" }, x = 0.576, y = 0.309 },
			{ code = "BS", match = { "blacksmith", "forge" }, x = 0.466, y = 0.456 },
			{ code = "LM", match = { "lumber", "scierie" }, x = 0.406, y = 0.557 },
			{ code = "Farm", match = { "farm", "ferme" }, x = 0.560, y = 0.600 },
		},
	},
	wsg = {
		name = "Warsong Gulch",
		instanceID = 489,
		mapIDs = { 1460, 92, 1339 },
		mapNames = { "warsong gulch", "chanteguerre" },
		flag = true,
		-- No points of interest here. "our"/"their" depends on your faction (owner = whose base).
		-- Positions read on the map art (exported zone 3277, 1002x668, 2026-11-22): Silverwing Hold
		-- at the top, its graveyard hut west of it, a front corridor south and a side corridor east
		-- to a tower; Warsong Lumber Mill at the bottom, front exit north, a long walkway west, its
		-- graveyard east. Which exit players call "tun" and which "ramp" is a reading of that layout.
		nodes = {
			{ key = "ally-base", base = "base", owner = "Alliance", x = 0.490, y = 0.150 },
			{ key = "ally-ramp", base = "ramp", owner = "Alliance", x = 0.512, y = 0.268 },
			{ key = "ally-tun", base = "tun", owner = "Alliance", x = 0.590, y = 0.220 },
			{ key = "ally-gy", base = "GY", owner = "Alliance", x = 0.360, y = 0.210 },
			{ key = "mid", code = "mid", x = 0.510, y = 0.520 },
			{ key = "horde-base", base = "base", owner = "Horde", x = 0.525, y = 0.862 },
			{ key = "horde-ramp", base = "ramp", owner = "Horde", x = 0.497, y = 0.775 },
			{ key = "horde-tun", base = "tun", owner = "Horde", x = 0.420, y = 0.878 },
			{ key = "horde-gy", base = "GY", owner = "Horde", x = 0.665, y = 0.810 },
		},
	},
	av = {
		name = "Alterac Valley",
		instanceID = 30,
		mapIDs = { 1459, 91 },
		mapNames = { "alterac valley", "vallée d'alterac", "vallée d’alterac" },
		flag = false,
		extraPOIs = true, -- points of interest no code matches are kept, under their own name
		nodes = {
			{ code = "DBN", match = { "dun baldar north", "nord de dun baldar" } },
			{ code = "DBS", match = { "dun baldar south", "sud de dun baldar" } },
			{ code = "IWB", match = { "icewing bunker" } },
			{ code = "SHB", match = { "stonehearth bunker" } },
			{ code = "IBT", match = { "iceblood tower" } },
			{ code = "TP", match = { "tower point" } },
			{ code = "EFW", match = { "east frostwolf" } },
			{ code = "WFW", match = { "west frostwolf" } },
			{ code = "AID", match = { "aid station" } },
			{ code = "SPGY", match = { "stormpike graveyard" } },
			{ code = "SHGY", match = { "stonehearth graveyard" } },
			{ code = "SNOW", match = { "snowfall" } },
			{ code = "IBGY", match = { "iceblood graveyard" } },
			{ code = "FWGY", match = { "frostwolf graveyard" } },
			{ code = "HUT", match = { "relief hut" } },
			{ code = "IDM", match = { "irondeep" } },
			{ code = "CTM", match = { "coldtooth" } },
			{ code = "DB", match = { "dun baldar" } },
			{ code = "DREK", match = { "frostwolf keep" } },
		},
	},
	dsi = {
		-- Darkspear Islands (Iles des Sombrelances): 15v15, four bases and one flag in the middle,
		-- like Eye of the Storm. Alliance starts north, Horde south. Base names from guides.
		name = "Darkspear Islands",
		names = { "darkspear", "sombrelance" },
		mapNames = { "darkspear", "sombrelance" }, -- map ID unknown (16606 is its zone ID, not its map ID)
		flag = true,
		extraPOIs = true,
		-- Built-in positions (test mode only: in the battleground the map's points of interest win)
		-- are guesses on the map art (exported zone 16606): the north island's west clearing (ruins)
		-- and raised east side (tower, "east side of the northern island" in guides), the south
		-- island's east clearing (camp, "red hills of the southern island") and west coast (cove),
		-- the flag on the centre bridge.
		nodes = {
			{ code = "tower", match = { "tower", "tour" }, x = 0.600, y = 0.440 },
			{ code = "cove", match = { "cove", "crique", "wreck" }, x = 0.400, y = 0.620 },
			{ code = "ruins", match = { "ruin" }, x = 0.430, y = 0.355 },
			{ code = "camp", match = { "camp" }, x = 0.570, y = 0.700 },
			-- The map calls the flag's point "Bannière de Sombrelance" on French clients.
			{ code = "flag", match = { "banner", "banni", "flag", "drapeau" }, x = 0.510, y = 0.500 },
		},
	},
	generic = {
		-- Any other battleground: its points of interest, under their own names.
		name = "Battleground",
		flag = true,
		extraPOIs = true,
		nodes = {},
	},
	test = {
		-- /bgc test, outside battlegrounds: a compass grid on whatever map is shown.
		name = "Test",
		flag = true,
		poi = false,
		nodes = {
			{ code = "NW", x = 0.2, y = 0.2 }, { code = "N", x = 0.5, y = 0.2 }, { code = "NE", x = 0.8, y = 0.2 },
			{ code = "W", x = 0.2, y = 0.5 }, { code = "C", x = 0.5, y = 0.5 }, { code = "E", x = 0.8, y = 0.5 },
			{ code = "SW", x = 0.2, y = 0.8 }, { code = "S", x = 0.5, y = 0.8 }, { code = "SE", x = 0.8, y = 0.8 },
		},
	},
}

---------------------------------------------------------------------------------------------------
-- Where are we?

local function plainString(value)
	if ns.IsSecret(value) or type(value) ~= "string" then
		return nil
	end
	return value
end

local function plainNumber(value)
	if ns.IsSecret(value) or type(value) ~= "number" then
		return nil
	end
	return value
end

function ns.DetectContext()
	local ctx = {}
	local _, instanceType = IsInInstance()
	ctx.instanceType = plainString(instanceType)
	local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
	ctx.instanceName = plainString(name)
	ctx.instanceID = plainNumber(instanceID)
	ctx.inBG = (ctx.instanceType == "pvp")

	local key
	if ctx.inBG then
		for profileKey, profile in pairs(ns.PROFILES) do
			if profile.instanceID and profile.instanceID == ctx.instanceID then
				key = profileKey
			end
		end
		if not key and ctx.instanceName then
			local lower = string.lower(ctx.instanceName)
			for profileKey, profile in pairs(ns.PROFILES) do
				for _, word in ipairs(profile.names or {}) do
					if string.find(lower, word, 1, true) then
						key = profileKey
					end
				end
			end
		end
		key = key or "generic"
	elseif ns.db and ns.db.test ~= "off" then
		-- Test mode: a compass grid, or a battleground drawn over the map shown (/bgc test ab).
		local wanted = ns.db.testProfile
		if wanted and wanted ~= "grid" and ns.PROFILES[wanted] then
			key = wanted
			ctx.fake = true
			ctx.fakeMapID = ns.db.testMapID or ns.FindMapID(wanted)
		else
			key = "test"
		end
	end
	ctx.key = key
	ctx.profile = key and ns.PROFILES[key]
	ctx.active = key ~= nil
	ctx.faction = plainString((UnitFactionGroup("player")))
	return ctx
end

-- A battleground's map, found by name for test mode: every map whose name matches and that has
-- art. The first one is used; /bgc debug lists them all (/bgc test ab <mapID> picks another).
ns.fakeMaps = {}

local function hasArt(mapID)
	local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
	return ok and type(layers) == "table" and layers[1] ~= nil
end

local function mapName(mapID)
	local ok, info = pcall(C_Map.GetMapInfo, mapID)
	local name = ok and type(info) == "table" and info.name
	if type(name) == "string" and not ns.IsSecret(name) then
		return name
	end
	return nil
end

function ns.FindMapID(key)
	local cached = ns.fakeMaps[key]
	if cached then
		return cached.chosen
	end
	local profile = ns.PROFILES[key]
	local found = { candidates = {} }
	ns.fakeMaps[key] = found
	if not (profile and C_Map and C_Map.GetMapInfo and C_Map.GetMapArtLayers) then
		return nil
	end
	local seen = {}
	local function consider(mapID, name)
		if seen[mapID] then
			return
		end
		seen[mapID] = true
		local art = hasArt(mapID)
		found.candidates[#found.candidates + 1] = mapID .. " " .. tostring(name) .. (art and "" or " (no art)")
		if art and not found.chosen then
			found.chosen = mapID
		end
	end
	for _, mapID in ipairs(profile.mapIDs or {}) do
		consider(mapID, mapName(mapID))
	end
	if profile.mapNames and not found.chosen then
		-- Once per battleground per session; new Forever maps may have high IDs.
		for mapID = 1, 20000 do
			local name = mapName(mapID)
			if name then
				local lower = string.lower(name)
				for _, word in ipairs(profile.mapNames) do
					if string.find(lower, word, 1, true) then
						consider(mapID, name)
						break
					end
				end
			end
		end
	end
	ns.Log("fakemap", { key = key, chosen = found.chosen, candidates = found.candidates })
	return found.chosen
end

-- The map whose coordinates the clicks are in: the one the battlefield map shows.
function ns.ShownMapID()
	local map = _G.BattlefieldMapFrame
	if map and map.GetMapID then
		local ok, mapID = pcall(map.GetMapID, map)
		if ok and plainNumber(mapID) then
			return mapID
		end
	end
	if C_Map and C_Map.GetBestMapForUnit then
		return plainNumber(C_Map.GetBestMapForUnit("player"))
	end
	return nil
end

-- The map's points of interest: { id, name, lname, x, y }. Secret ones are counted, not kept.
function ns.ReadPOIs(mapID)
	local list, secret = {}, 0
	if not (mapID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then
		return list, secret
	end
	local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
	if not ok or type(ids) ~= "table" then
		return list, secret
	end
	for _, id in ipairs(ids) do
		if ns.IsSecret(id) then
			secret = secret + 1
		else
			local okInfo, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, id)
			if okInfo and type(info) == "table" then
				local name = info.name
				local x, y
				if info.position and info.position.GetXY then
					x, y = info.position:GetXY()
				end
				if ns.IsSecret(name) or ns.IsSecret(x) or ns.IsSecret(y) then
					secret = secret + 1
				elseif type(x) == "number" and type(y) == "number" then
					list[#list + 1] = {
						id = id,
						name = type(name) == "string" and name or nil,
						lname = type(name) == "string" and string.lower(name) or "",
						x = x,
						y = y,
					}
				end
			end
		end
	end
	return list, secret
end

local function matches(lname, words)
	for _, word in ipairs(words) do
		if string.find(lname, word, 1, true) then
			return true
		end
	end
	return false
end

local function round(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

local function nodeCode(def, faction)
	if def.code then
		return def.code
	end
	if def.owner and faction then
		return ((def.owner == faction) and "our " or "their ") .. def.base
	end
	return ((def.owner == "Alliance") and "ally " or "horde ") .. def.base
end

-- The places on this map, in profile order: { code, key, x, y, src }. Places with no position
-- are listed in ctx.unplaced (for /bgc debug).
function ns.BuildNodes(ctx, mapID)
	local nodes, unplaced = {}, {}
	local profile = ctx.profile
	if not profile then
		return nodes, unplaced, {}
	end
	local pois = {}
	if profile.poi ~= false then
		pois = ns.ReadPOIs(mapID)
	end
	local byKey = {}

	for _, def in ipairs(profile.nodes) do
		local node = { code = nodeCode(def, ctx.faction) }
		node.key = def.key or node.code
		if def.match then
			for _, poi in ipairs(pois) do
				if not poi.used and matches(poi.lname, def.match) then
					poi.used = true
					node.x, node.y, node.src = poi.x, poi.y, "poi " .. tostring(poi.id)
					break
				end
			end
		end
		if not node.x and def.x then
			node.x, node.y, node.src = def.x, def.y, "built-in"
		end
		nodes[#nodes + 1] = node
		byKey[node.key] = node
	end

	if profile.extraPOIs then
		for _, poi in ipairs(pois) do
			if not poi.used and poi.name and poi.name ~= "" then
				local code = string.sub(poi.name, 1, 24)
				if not byKey[code] then
					local node = { code = code, key = code, x = poi.x, y = poi.y, src = "poi " .. tostring(poi.id) }
					nodes[#nodes + 1] = node
					byKey[code] = node
				end
			end
		end
	end

	-- Positions set with /bgc place win, and can add places of your own.
	local places = mapID and ns.db.places[mapID]
	if type(places) == "table" then
		for key, place in pairs(places) do
			if type(place) == "table" and type(place.x) == "number" and type(place.y) == "number" then
				local node = byKey[key]
				if not node then
					node = { code = place.code or key, key = key }
					nodes[#nodes + 1] = node
					byKey[key] = node
				end
				node.x, node.y, node.src = place.x, place.y, "placed"
			end
		end
	end

	local placed = {}
	for _, node in ipairs(nodes) do
		if node.x and node.y then
			node.x, node.y = round(node.x), round(node.y)
			placed[#placed + 1] = node
		else
			unplaced[#unplaced + 1] = node.code
		end
	end
	return placed, unplaced, pois
end

---------------------------------------------------------------------------------------------------
-- The current state, refreshed by Secure.lua's tracker and on events. Fires NODES_CHANGED.

ns.current = { active = false, nodes = {}, unplaced = {}, templates = ns.ActiveTemplates(nil) }

local lastSignature

local function signature(ctx, mapID, nodes)
	local parts = { tostring(ctx.key), tostring(mapID), tostring(ns.db and ns.db.test) }
	for _, node in ipairs(nodes) do
		parts[#parts + 1] = node.code .. "@" .. node.x .. "," .. node.y
	end
	return table.concat(parts, ";")
end

function ns.Refresh()
	if not ns.db then
		return
	end
	local ctx = ns.DetectContext()
	-- In test mode with a battleground drawn, places and positions are that battleground's map's.
	local mapID = ctx.active and (ctx.fakeMapID or ns.ShownMapID()) or nil
	local nodes, unplaced, pois = ns.BuildNodes(ctx, mapID)
	local previousKey = ns.current.key
	ns.current = {
		active = ctx.active,
		key = ctx.key,
		ctx = ctx,
		fakeMapID = ctx.fakeMapID,
		mapID = mapID,
		nodes = nodes,
		unplaced = unplaced,
		poiCount = #pois,
		templates = ns.ActiveTemplates(ctx.profile),
	}
	local sig = signature(ctx, mapID, nodes)
	if sig ~= lastSignature then
		lastSignature = sig
		ns.Fire("NODES_CHANGED")
	end
	if ctx.key ~= previousKey then
		ns.Log("context", {
			key = ctx.key,
			instance = ctx.instanceName,
			instanceID = ctx.instanceID,
			mapID = mapID,
			nodes = #nodes,
			pois = #pois,
			lockdown = ns.ChatLockdown(),
		})
		if ctx.inBG then
			ns.Print((ctx.profile and ctx.profile.name or "battleground") .. ": " .. #nodes .. " places. "
				.. ns.ClickLabel() .. " on the battlefield map (Shift-M), drag, release."
				.. ((ns.db.test == "print") and " |cffff8000Test mode is on: nothing is sent (/bgc test off).|r" or ""))
		elseif ctx.fake then
			ns.Print("test: " .. ctx.profile.name .. " (" .. #nodes .. " places) "
				.. (ctx.fakeMapID and ("drawn from map " .. ctx.fakeMapID) or "|cffff8000map art not found|r, places over the map shown")
				.. ". Open Shift-M.")
		end
	end
end

function ns.ChatLockdown()
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, value = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and not ns.IsSecret(value) then
			return value and true or false
		end
		return ok and "<secret>" or "error"
	end
	return "missing"
end

-- Points of interest change (a base taken): only matters while active. It fires in cities too.
ns.On("AREA_POIS_UPDATED", function()
	if ns.current.active then
		ns.Refresh()
	end
end)

ns.Listen("WORLD", function()
	ns.Refresh()
end)

ns.Listen("SETTINGS_CHANGED", function()
	ns.Refresh()
end)

function ns.StatusLine()
	local cur = ns.current
	if not cur.active then
		return "Inactive: only in battlegrounds (or with /bgc test)."
	end
	local text = (cur.ctx and cur.ctx.profile and cur.ctx.profile.name or "?") .. ", map " .. tostring(cur.mapID)
		.. ": " .. #cur.nodes .. " places"
	if #cur.unplaced > 0 then
		text = text .. " (" .. #cur.unplaced .. " not found: " .. table.concat(cur.unplaced, ", ") .. ")"
	end
	if ns.db.test ~= "off" then
		text = text .. ". Test mode: " .. ns.db.test
	end
	return text .. "."
end

---------------------------------------------------------------------------------------------------
-- /bgc place CODE: the next click on the map (out of combat) puts CODE there. /bgc forget CODE.

local function findNode(code)
	local wanted = string.lower(code)
	for _, node in ipairs(ns.current.nodes) do
		if string.lower(node.code) == wanted then
			return node
		end
	end
	for _, name in ipairs(ns.current.unplaced) do
		if string.lower(name) == wanted then
			return { code = name, key = nil }
		end
	end
	return nil
end

-- The key a place is saved under: built-in places keep their profile key (WSG's "ally-tun" stays
-- the same place whichever faction you play), new places their code.
local function placeKey(code)
	local ctx = ns.current.ctx
	if ctx and ctx.profile then
		local wanted = string.lower(code)
		for _, def in ipairs(ctx.profile.nodes) do
			if string.lower(nodeCode(def, ctx.faction)) == wanted then
				return def.key or nodeCode(def, ctx.faction), nodeCode(def, ctx.faction)
			end
		end
	end
	local node = findNode(code)
	if node then
		return node.key or node.code, node.code
	end
	return code, code
end

function ns.StartPlacing(rest)
	local code = strtrim(rest or "")
	if code == "" or string.find(code, "[;,]") then
		local codes = {}
		for _, node in ipairs(ns.current.nodes) do
			codes[#codes + 1] = node.code
		end
		ns.Print("/bgc place CODE (no ; or ,). Places here: " .. (#codes > 0 and table.concat(codes, ", ") or "none"))
		return
	end
	if InCombatLockdown() then
		ns.Print("not in combat.")
		return
	end
	if not ns.current.active or not ns.current.mapID then
		ns.Print("only in a battleground, or with /bgc test.")
		return
	end
	ns.placing = code
	ns.Print(ns.ClickLabel() .. " on the battlefield map where '" .. code .. "' is.")
end

function ns.FinishPlacing(mx, my)
	local code = ns.placing
	ns.placing = nil
	if not code then
		return
	end
	if InCombatLockdown() or type(mx) ~= "number" or type(my) ~= "number" then
		ns.Print("place not set.")
		return
	end
	local mapID = ns.current.mapID
	if not mapID then
		return
	end
	local key, shown = placeKey(code)
	ns.db.places[mapID] = ns.db.places[mapID] or {}
	ns.db.places[mapID][key] = { x = round(mx), y = round(my), code = shown }
	ns.Log("place", { mapID = mapID, key = key, code = shown, x = round(mx), y = round(my) })
	ns.Print("'" .. shown .. "' set on map " .. mapID .. " at " .. round(mx) .. ", " .. round(my) .. ".")
	ns.Refresh()
end

function ns.ForgetPlace(rest)
	local code = strtrim(rest or "")
	local mapID = ns.current.mapID
	local places = mapID and ns.db.places[mapID]
	if code == "" or type(places) ~= "table" then
		ns.Print("/bgc forget CODE, for a place set with /bgc place on the map shown.")
		return
	end
	local key = placeKey(code)
	if places[key] then
		places[key] = nil
		ns.Print("'" .. code .. "' forgotten on map " .. mapID .. ".")
		ns.Refresh()
	else
		ns.Print("no place '" .. code .. "' set on map " .. mapID .. ".")
	end
end

---------------------------------------------------------------------------------------------------
-- /bgc debug: where we are, what the client restricts, and what the map offers.

ns.AddDebugPart("context", function()
	local ctx = ns.DetectContext()
	local mapID = ns.ShownMapID()
	local part = {
		ctx = { key = ctx.key, inBG = ctx.inBG, instanceType = ctx.instanceType, instanceName = ctx.instanceName,
			instanceID = ctx.instanceID, faction = ctx.faction },
		shownMapID = mapID,
		bestMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"),
		chatLockdown = ns.ChatLockdown(),
		subZone = GetSubZoneText and GetSubZoneText(),
		minimapZone = GetMinimapZoneText and GetMinimapZoneText(),
		slashInstance = { _G.SLASH_INSTANCE_CHAT1, _G.SLASH_INSTANCE_CHAT2, _G.SLASH_INSTANCE_CHAT3 },
		restrictions = {},
		nodes = ns.current.nodes,
		unplaced = ns.current.unplaced,
		templates = ns.current.templates,
		fake = { key = ctx.fake and ctx.key or nil, mapID = ctx.fakeMapID, maps = ns.fakeMaps },
	}
	if C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState and Enum and Enum.AddOnRestrictionType then
		for name, value in pairs(Enum.AddOnRestrictionType) do
			local ok, state = pcall(C_RestrictedActions.GetAddOnRestrictionState, value)
			part.restrictions[name] = ok and state or "error"
		end
	else
		part.restrictions = "missing"
	end
	local pois, secret = ns.ReadPOIs(mapID)
	part.pois = pois
	part.secretPOIs = secret
	if ctx.fakeMapID then
		part.fake.pois = ns.ReadPOIs(ctx.fakeMapID)
	end
	if C_PvP and C_PvP.GetBattlefieldFlagPosition and mapID then
		part.flags = {}
		for i = 1, 3 do
			local ok, x, y, texture = pcall(C_PvP.GetBattlefieldFlagPosition, i, mapID)
			part.flags[i] = ok and { x = x, y = y, texture = texture } or "error"
		end
	end
	return part
end)
