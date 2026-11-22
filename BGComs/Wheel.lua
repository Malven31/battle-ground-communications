-- BGComs visuals, all plain (insecure) frames, free to change in combat:
--   the drag wheel shown while the middle button is held, the "sent" flash, the place codes drawn
--   on the battlefield map, and the battleground map art drawn over it in test mode.
-- The wheel uses ns.Classify, the same rules as the secure snippet, so what it highlights is what
-- the release sends.
--
-- Look: Blizzard's own radial wheel and ping art (Blizzard_RadialWheel, Blizzard_PingUI), drawn on
-- our own textures. Forever loads that art (its ping key binding exists), but which atlases
-- exist isn't known, so each one is checked and falls back (ns.art, in /bgc debug).
-- Cost: nothing runs while the wheel is closed; while open, work is done only when the cursor
-- moves, and textures and text change only when the selection changes.

local _, ns = ...

local G = ns.GEOMETRY
local DEG = 180 / math.pi
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local OUTER = G.dead + G.band * G.maxCount -- edge of the counted bands (132)
local DISC = 2 * (OUTER + 12) -- disc diameter
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0
-- Our own soft textures (scripts/make-bgcoms-media.ps1): a line with soft edges, and a round glow.
local SOFT_LINE = "Interface\\AddOns\\BGComs\\media\\softline"
local GLOW = "Interface\\AddOns\\BGComs\\media\\glow"
local SOFT = 2.4 -- a soft line is drawn this much thicker than its look, its edges being transparent

ns.art = {}

local function hasAtlas(name)
	if not (C_Texture and C_Texture.GetAtlasInfo) then
		return false
	end
	local ok, info = pcall(C_Texture.GetAtlasInfo, name)
	return ok and type(info) == "table"
end

-- Sets an atlas at its own size times `scale`; false if this client hasn't got it.
local function useAtlas(texture, atlas, key, scale)
	if not hasAtlas(atlas) then
		ns.art[key] = false
		return false
	end
	texture:SetAtlas(atlas, true)
	if scale then
		local w, h = texture:GetSize()
		texture:SetSize(w * scale, h * scale)
	end
	ns.art[key] = atlas
	return true
end

local function polar(radius, degrees)
	local a = degrees / DEG
	return radius * math.cos(a), radius * math.sin(a)
end

---------------------------------------------------------------------------------------------------
-- The wheel

local Wheel = {}
ns.Wheel = Wheel

local wheel = CreateFrame("Frame", "BGComsWheel", UIParent)
wheel:SetFrameStrata("TOOLTIP")
wheel:SetSize(DISC + 120, DISC + 120)
wheel:EnableMouse(false)
wheel:Hide()

-- Lines use the soft line texture, tinted: smooth edges instead of a hard flat colour.
local function newLine(x1, y1, x2, y2, thickness, r, g, b, a, sublevel)
	local line = wheel:CreateLine(nil, "ARTWORK", nil, sublevel or 0)
	line:SetStartPoint("CENTER", wheel, x1, y1)
	line:SetEndPoint("CENTER", wheel, x2, y2)
	line:SetThickness(thickness * SOFT)
	line:SetTexture(SOFT_LINE)
	line:SetVertexColor(r, g, b, a)
	return line
end

-- A line that fades out towards its start (the wheel's centre): transparent there, (r, g, b, a) at its end.
local function fadeIn(line, r, g, b, a)
	line:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a))
end

local function newArc(radius, from, to, thickness, r, g, b, a)
	local lines = {}
	local steps = math.max(2, math.ceil((to - from) / 3))
	for i = 0, steps - 1 do
		local x1, y1 = polar(radius, from + (to - from) * i / steps)
		local x2, y2 = polar(radius, from + (to - from) * (i + 1) / steps)
		lines[#lines + 1] = newLine(x1, y1, x2, y2, thickness, r, g, b, a, 2)
	end
	return lines
end

local function setLines(lines, shown, r, g, b, a)
	for _, line in ipairs(lines) do
		if shown then
			line:SetVertexColor(r, g, b, a)
			line:Show()
		else
			line:Hide()
		end
	end
end

local function newText(size, x, y, layer)
	local text = wheel:CreateFontString(nil, layer or "OVERLAY")
	text:SetFont(FONT, size, "OUTLINE")
	text:SetPoint("CENTER", wheel, "CENTER", x, y)
	return text
end

-- The disc. Blizzard's background, scaled so its size matches our bands.
local disc = wheel:CreateTexture(nil, "BACKGROUND", nil, 1)
disc:SetPoint("CENTER")
local artScale = 1
if hasAtlas("Radial_Wheel_BG") then
	disc:SetAtlas("Radial_Wheel_BG", true)
	local w = disc:GetWidth()
	artScale = (w and w > 0) and (DISC / w) or 1
	disc:SetSize(DISC, DISC)
	ns.art.disc = "Radial_Wheel_BG"
else
	-- A dark round disc: a colour masked by Blizzard's round portrait mask (wrap modes given, no
	-- filter: a filter mode with nil wrap modes crashes the client).
	disc:SetSize(DISC, DISC)
	disc:SetColorTexture(0.03, 0.03, 0.05, 0.72)
	local mask = wheel:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(disc)
	disc:AddMaskTexture(mask)
	ns.art.disc = false
end

-- The ring with six dividers, or thin divider lines.
local ring = wheel:CreateTexture(nil, "OVERLAY", nil, 1)
ring:SetPoint("CENTER")
if not useAtlas(ring, "Radial_Wheel_Frame_Count_6", "ring", artScale) then
	ring:Hide()
	-- Dividers fading out towards the centre, and a soft rim.
	for _, sector in ipairs(ns.SECTORS) do
		local x1, y1 = polar(G.dead - 6, sector.from)
		local x2, y2 = polar(OUTER + 8, sector.from)
		fadeIn(newLine(x1, y1, x2, y2, 1, 1, 1, 1, 0.3, 1), 1, 1, 1, 0.3)
	end
	newArc(OUTER + 8, 0, 360, 1.2, 1, 1, 1, 0.22)
end

-- The centre, blurred: a soft dark glow behind the place code, over the disc.
local centerShade = wheel:CreateTexture(nil, "BACKGROUND", nil, 3)
centerShade:SetPoint("CENTER")
centerShade:SetSize(G.dead * 2 + 56, G.dead * 2 + 56)
centerShade:SetTexture(GLOW)
centerShade:SetVertexColor(0, 0, 0, 0.8)

-- The selected wedge: Blizzard's wedge glow, rotated onto it (as Blizzard_RadialWheel places it,
-- 100 out along the wedge), or a gold arc on the rim.
local wedgeGlow = wheel:CreateTexture(nil, "ARTWORK", nil, 1)
local hasWedgeGlow = useAtlas(wedgeGlow, "Radial_Wheel_Select_Wedge_Count_6", "wedge", artScale)
wedgeGlow:Hide()

-- The pointer, rotated towards the cursor.
local pointer = wheel:CreateTexture(nil, "OVERLAY", nil, 2)
pointer:SetPoint("CENTER")
local hasPointer = useAtlas(pointer, "Radial_Wheel_Select_Pointer", "pointer", artScale)
-- Without Blizzard's pointer: a soft gold line from the centre to the cursor, invisible at the
-- centre and full at the cursor.
local pointerLine = newLine(0, 0, 1, 1, 2, GOLD_R, GOLD_G, GOLD_B, 0.9, 3)
fadeIn(pointerLine, GOLD_R, GOLD_G, GOLD_B, 0.9)
pointer:Hide()
pointerLine:Hide()

-- The centre while the cursor is in it (release = cancel).
local cancelGlow = wheel:CreateTexture(nil, "ARTWORK", nil, 2)
cancelGlow:SetPoint("CENTER")
if not useAtlas(cancelGlow, "Radial_Wheel_Select_Close", "cancel", artScale) then
	cancelGlow:SetSize(G.dead * 2 + 24, G.dead * 2 + 24)
	cancelGlow:SetTexture(GLOW)
	cancelGlow:SetVertexColor(1, 1, 1, 0.25)
end
cancelGlow:Hide()

-- Each call: an icon (Blizzard's ping icons where they fit), its name, and for counted calls the
-- band edges, shown while that wedge is selected.
local ICONS = {
	inc = { atlas = "Ping_Wheel_Icon_Warning", file = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" },
	spotted = { atlas = "Ping_Wheel_Icon_Attack", file = "Interface\\Icons\\Ability_EyeOfTheOwl", trim = true },
	help = { atlas = "Ping_Wheel_Icon_Assist", file = "Interface\\Icons\\Spell_Holy_SealOfProtection", trim = true },
	omw = { atlas = "Ping_Wheel_Icon_OnMyWay", file = "Interface\\Icons\\Ability_Rogue_Sprint", trim = true },
	clear = { file = "Interface\\RaidFrame\\ReadyCheck-Ready" },
	efc = { flag = true },
}
local ICON_SIZE = 34

local parts = {}
for _, sector in ipairs(ns.SECTORS) do
	local part = {}
	parts[sector] = part
	local mid = (sector.from + sector.to) / 2
	part.mid = mid
	local ix, iy = polar(G.iconRadius, mid)
	part.icon = wheel:CreateTexture(nil, "OVERLAY", nil, 3)
	part.icon:SetPoint("CENTER", wheel, "CENTER", ix, iy)
	local spec = ICONS[sector.kind] or {}
	if spec.atlas and useAtlas(part.icon, spec.atlas, "icon_" .. sector.kind) then
		local w, h = part.icon:GetSize()
		local fit = math.min(1, (ICON_SIZE + 10) / math.max(w, h, 1))
		part.icon:SetSize(w * fit, h * fit)
	elseif spec.file then
		part.icon:SetTexture(spec.file)
		part.icon:SetSize(ICON_SIZE, ICON_SIZE)
		if spec.trim then
			part.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
	else
		part.icon:SetSize(ICON_SIZE, ICON_SIZE)
	end
	part.flag = spec.flag
	part.baseW, part.baseH = part.icon:GetSize()

	-- The name on the outer side of the icon (Blizzard_RadialWheel's rule).
	part.label = wheel:CreateFontString(nil, "OVERLAY")
	part.label:SetFont(FONT, 12, "OUTLINE")
	part.label:SetText(sector.label)
	local a = mid / DEG
	local q = math.pi / 4
	if a > q and a <= math.pi - q then
		part.label:SetPoint("BOTTOM", part.icon, "TOP", 0, 2)
	elseif a > math.pi - q and a <= math.pi + q then
		part.label:SetPoint("RIGHT", part.icon, "LEFT", -2, 0)
	elseif a > math.pi + q and a <= 2 * math.pi - q then
		part.label:SetPoint("TOP", part.icon, "BOTTOM", 0, -2)
	else
		part.label:SetPoint("LEFT", part.icon, "RIGHT", 2, 0)
	end

	if not hasWedgeGlow then
		part.rim = newArc(OUTER + 8, sector.from + 1, sector.to - 1, 3, GOLD_R, GOLD_G, GOLD_B, 0.9)
		setLines(part.rim, false)
	end
	if sector.counted then
		part.bands = {}
		for band = 1, G.maxCount do
			part.bands[band] = newArc(G.dead + G.band * band, sector.from + 2, sector.to - 2, 1, 1, 1, 1, 0.3)
			setLines(part.bands[band], false)
		end
	end
end

local locText = newText(17, 0, 3)
local countText = newText(14, 0, -12)
countText:SetTextColor(GOLD_R, GOLD_G, GOLD_B, 1)

-- The message that the release sends, on a dark pill under the disc.
local pill = wheel:CreateTexture(nil, "BACKGROUND", nil, 2)
pill:SetColorTexture(0, 0, 0, 0.65)
local preview = newText(15, 0, -(DISC / 2 + 16))
pill:SetPoint("TOPLEFT", preview, "TOPLEFT", -8, 4)
pill:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", 8, -4)

local movedText = newText(10, 0, -(DISC / 2 + 36))
movedText:SetTextColor(1, 0.5, 0, 1)
movedText:SetText("map zoomed or moved in combat: the place may be off (release in the centre to cancel)")

-- A short fade and grow on opening.
local intro = wheel:CreateAnimationGroup()
local introAlpha = intro:CreateAnimation("Alpha")
introAlpha:SetFromAlpha(0)
introAlpha:SetToAlpha(1)
introAlpha:SetDuration(0.09)
local introScale = intro:CreateAnimation("Scale")
introScale:SetScaleFrom(0.9, 0.9)
introScale:SetScaleTo(1, 1)
introScale:SetDuration(0.09)

local centerX, centerY = 0, 0
local location
local lastSector, lastBand, lastCancel
local lastX, lastY
local upSince
local sweepStart -- set by the performance test: a simulated cursor

local function paint(sector, band, disabled)
	for s, part in pairs(parts) do
		local text = ns.current.templates[s.kind]
		local enabled = text and text ~= ""
		local selected = (s == sector)
		if selected then
			part.label:SetTextColor(GOLD_R, GOLD_G, GOLD_B, 1)
			part.icon:SetSize(part.baseW * 1.15, part.baseH * 1.15)
		else
			part.label:SetTextColor(1, 1, 1, enabled and 0.85 or 0.3)
			part.icon:SetSize(part.baseW, part.baseH)
		end
		part.icon:SetDesaturated(not enabled)
		part.icon:SetAlpha(enabled and (selected and 1 or 0.8) or 0.3)
		if part.rim then
			setLines(part.rim, selected, GOLD_R, GOLD_G, GOLD_B, 0.9)
		end
		if part.bands then
			for b, arc in ipairs(part.bands) do
				local current = selected and b == math.min(band or 0, G.maxCount)
				setLines(arc, selected, current and GOLD_R or 1, current and GOLD_G or 1, current and GOLD_B or 1, current and 0.9 or 0.25)
			end
		end
	end
	if hasWedgeGlow and sector then
		local a = ((sector.from + sector.to) / 2) / DEG
		wedgeGlow:ClearAllPoints()
		wedgeGlow:SetPoint("CENTER", wheel, "CENTER", math.cos(a) * 100 * artScale, math.sin(a) * 100 * artScale)
		wedgeGlow:SetRotation(a)
		wedgeGlow:Show()
	else
		wedgeGlow:Hide()
	end
	cancelGlow:SetShown(not sector and not disabled)
	locText:SetAlpha(sector and 1 or 0.55)
end

local function track()
	local x, y
	if sweepStart then
		-- /bgc perf: a cursor sweeping round and in and out, so the wheel repaints all the time.
		local t = GetTime() - sweepStart
		local radius = 10 + (OUTER + 30) * (0.5 + 0.5 * math.sin(t * 2.3))
		x, y = centerX + radius * math.cos(t * 3.1), centerY + radius * math.sin(t * 3.1)
	else
		local scale = UIParent:GetEffectiveScale()
		x, y = GetCursorPosition()
		x, y = x / scale, y / scale

		-- The release is the secure button's; if it never comes (button released elsewhere),
		-- close. A short grace, so a release whose click is on its way isn't taken for an abandon.
		if IsMouseButtonDown("MiddleButton") then
			upSince = nil
		else
			upSince = upSince or GetTime()
			if GetTime() - upSince > 0.25 then
				Wheel.Close()
				ns.Fire("WHEEL_ABANDONED")
				return
			end
		end
	end
	if x == lastX and y == lastY then
		return
	end
	lastX, lastY = x, y

	local dx, dy = x - centerX, y - centerY
	local sector, count, band, disabled = ns.Classify(dx, dy, ns.current.templates)

	if dx * dx + dy * dy >= G.dead * G.dead then
		local angle = math.atan2(dy, dx)
		if hasPointer then
			pointer:SetRotation(angle)
			pointer:Show()
		else
			local reach = math.min(math.sqrt(dx * dx + dy * dy), OUTER + 8)
			pointerLine:SetEndPoint("CENTER", wheel, reach * math.cos(angle), reach * math.sin(angle))
			pointerLine:Show()
		end
	else
		pointer:Hide()
		pointerLine:Hide()
	end

	local cancel = not sector
	if sector ~= lastSector or band ~= lastBand or cancel ~= lastCancel then
		lastSector, lastBand, lastCancel = sector, band, cancel
		paint(sector, band, disabled)
		if sector then
			preview:SetText(ns.FormatMessage(ns.current.templates[sector.kind], count, location))
			preview:SetTextColor(1, 1, 1, 1)
			countText:SetText(count and ("x" .. count) or "")
		elseif disabled then
			preview:SetText(disabled.label .. ": not in this battleground")
			preview:SetTextColor(0.6, 0.6, 0.6, 1)
			countText:SetText("")
		else
			preview:SetText("release here to cancel")
			preview:SetTextColor(0.75, 0.75, 0.75, 1)
			countText:SetText("")
		end
	end
end

wheel:SetScript("OnUpdate", function()
	local t0, kb0 = ns.PerfBegin()
	ns.SafeCall(track)
	ns.PerfEnd(t0, kb0, "wheel")
end)

local function setFlagIcon()
	for _, part in pairs(parts) do
		if part.flag then
			local faction = UnitFactionGroup("player")
			local enemy = (faction == "Horde") and "AllianceFlag" or "HordeFlag"
			if part.flagName ~= enemy then
				part.flagName = enemy
				part.icon:SetTexture("Interface\\WorldStateFrame\\" .. enemy)
				part.icon:SetSize(ICON_SIZE, ICON_SIZE)
				part.baseW, part.baseH = ICON_SIZE, ICON_SIZE
			end
		end
	end
end

-- Opens the wheel at the cursor (or at the screen centre with a simulated cursor: `sweep`).
function Wheel.Open(loc, sweep)
	local scale = UIParent:GetEffectiveScale()
	if sweep then
		centerX, centerY = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
		sweepStart = GetTime()
	else
		local x, y = GetCursorPosition()
		centerX, centerY = x / scale, y / scale
		sweepStart = nil
	end
	location = loc or "?"
	locText:SetText(location)
	countText:SetText("")
	movedText:SetShown(ns.mapMoved and true or false)
	setFlagIcon()
	lastSector, lastBand, lastCancel, lastX, lastY, upSince = false, false, nil, nil, nil, nil
	wheel:ClearAllPoints()
	wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
	wheel:Show()
	intro:Restart()
	track()
end

function Wheel.Close()
	sweepStart = nil
	wheel:Hide()
end

function Wheel.IsOpen()
	return wheel:IsShown()
end

---------------------------------------------------------------------------------------------------
-- The flash: the message sent (or "cancelled") on a pill, fading where the wheel was.

local flash = CreateFrame("Frame", "BGComsFlash", UIParent)
flash:SetFrameStrata("TOOLTIP")
flash:SetSize(10, 10)
flash:EnableMouse(false)
flash:Hide()
local flashText = flash:CreateFontString(nil, "OVERLAY")
flashText:SetFont(FONT, 16, "OUTLINE")
flashText:SetPoint("CENTER")
local flashPill = flash:CreateTexture(nil, "BACKGROUND")
flashPill:SetColorTexture(0, 0, 0, 0.6)
flashPill:SetPoint("TOPLEFT", flashText, "TOPLEFT", -10, 5)
flashPill:SetPoint("BOTTOMRIGHT", flashText, "BOTTOMRIGHT", 10, -5)
local flashLeft = 0
local FLASH_TIME = 1.4

flash:SetScript("OnUpdate", function(self, elapsed)
	flashLeft = flashLeft - elapsed
	if flashLeft <= 0 then
		self:Hide()
		return
	end
	self:SetAlpha(math.min(1, flashLeft / 0.5))
end)

function Wheel.Flash(text, r, g, b)
	flashText:SetText(text or "")
	flashText:SetTextColor(r or 1, g or 1, b or 1, 1)
	flash:ClearAllPoints()
	flash:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
	flashLeft = FLASH_TIME
	flash:SetAlpha(1)
	flash:Show()
end

---------------------------------------------------------------------------------------------------
-- On the battlefield map: the place codes, and in test mode the battleground's own map art.
-- Secure.lua's tracker calls MapVisuals.Update(rects) with the map's visible area (c) and its
-- canvas (v) in UIParent units, or nil when the map isn't shown or BGComs is inactive. Layout work
-- is done only when one of those values changes.

local MapVisuals = {}
ns.MapVisuals = MapVisuals

local art = CreateFrame("Frame", "BGComsFakeMap", UIParent)
art:SetFrameStrata("HIGH")
art:SetFrameLevel(800)
art:EnableMouse(false)
if art.SetClipsChildren then
	art:SetClipsChildren(true)
end
art:Hide()
local artBackground = art:CreateTexture(nil, "BACKGROUND")
artBackground:SetAllPoints()
artBackground:SetColorTexture(0, 0, 0, 1)
local artTitle = art:CreateFontString(nil, "OVERLAY")
artTitle:SetFont(FONT, 11, "OUTLINE")
artTitle:SetPoint("TOP", art, "TOP", 0, -4)
artTitle:SetTextColor(1, 0.5, 0, 1)
local tiles = {}
local artMapID, artLayer

-- Load the art of a map: tile file IDs, row by row (as Blizzard_MapCanvasDetailLayer lays them).
local function loadArt(mapID)
	artMapID, artLayer = mapID, nil
	for _, tile in ipairs(tiles) do
		tile:Hide()
	end
	if not (mapID and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then
		return
	end
	local okLayers, layers = pcall(C_Map.GetMapArtLayers, mapID)
	local okTextures, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
	if not (okLayers and okTextures and type(layers) == "table" and layers[1] and type(textures) == "table") then
		return
	end
	local info = layers[1]
	artLayer = {
		width = info.layerWidth,
		height = info.layerHeight,
		tileWidth = info.tileWidth,
		tileHeight = info.tileHeight,
		cols = math.ceil(info.layerWidth / info.tileWidth),
		rows = math.ceil(info.layerHeight / info.tileHeight),
	}
	for i, fileID in ipairs(textures) do
		local tile = tiles[i]
		if not tile then
			tile = art:CreateTexture(nil, "ARTWORK")
			tiles[i] = tile
		end
		-- File ID only: a filter mode with nil wrap modes crashes the client.
		tile:SetTexture(fileID)
		tile:Show()
	end
end

local function layoutArt(rects)
	local c, v = rects.c, rects.v
	art:ClearAllPoints()
	art:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", c.l, c.b)
	art:SetSize(c.w, c.h)
	if not artLayer then
		return
	end
	local scaleX, scaleY = v.w / artLayer.width, v.h / artLayer.height
	local originX = v.l - c.l
	local originY = (v.b + v.h) - (c.b + c.h)
	for row = 1, artLayer.rows do
		for col = 1, artLayer.cols do
			local tile = tiles[(row - 1) * artLayer.cols + col]
			if tile then
				tile:ClearAllPoints()
				tile:SetPoint("TOPLEFT", art, "TOPLEFT", originX + (col - 1) * artLayer.tileWidth * scaleX,
					originY - (row - 1) * artLayer.tileHeight * scaleY)
				tile:SetSize(artLayer.tileWidth * scaleX, artLayer.tileHeight * scaleY)
			end
		end
	end
end

-- Shown above the map while it has changed during combat (see Secure.lua's tick).
local warning = CreateFrame("Frame", "BGComsMapWarning", UIParent)
warning:SetFrameStrata("HIGH")
warning:SetFrameLevel(950)
warning:SetSize(10, 10)
warning:EnableMouse(false)
warning:Hide()
local warningText = warning:CreateFontString(nil, "OVERLAY")
warningText:SetFont(FONT, 10, "OUTLINE")
warningText:SetTextColor(1, 0.5, 0, 1)
warningText:SetPoint("BOTTOM")
warningText:SetText("BGComs: map opened, zoomed or moved in combat. Callouts follow it after the fight.")

local labels = CreateFrame("Frame", "BGComsMapLabels", UIParent)
labels:SetFrameStrata("HIGH")
labels:SetFrameLevel(900)
labels:SetAllPoints(UIParent)
labels:EnableMouse(false)
labels:Hide()
local marks = {}

local function getMark(i)
	local mark = marks[i]
	if not mark then
		mark = {}
		mark.text = labels:CreateFontString(nil, "OVERLAY")
		mark.text:SetFont(FONT, 10, "OUTLINE")
		mark.text:SetTextColor(GOLD_R, GOLD_G, GOLD_B, 1)
		mark.bg = labels:CreateTexture(nil, "ARTWORK")
		mark.bg:SetColorTexture(0, 0, 0, 0.45)
		mark.bg:SetPoint("TOPLEFT", mark.text, "TOPLEFT", -3, 1)
		mark.bg:SetPoint("BOTTOMRIGHT", mark.text, "BOTTOMRIGHT", 3, -1)
		marks[i] = mark
	end
	return mark
end

-- The name only, above the place: the map's own icon there (a base's red or blue owner) stays
-- uncovered.
local LABEL_LIFT = 9

local function layoutLabels(rects)
	local c, v = rects.c, rects.v
	local nodes = ns.current.nodes
	for i, node in ipairs(nodes) do
		local mark = getMark(i)
		local x = v.l + node.x * v.w
		local y = v.b + (1 - node.y) * v.h
		local inside = x >= c.l and x <= c.l + c.w and y >= c.b and y <= c.b + c.h
		if inside then
			mark.text:ClearAllPoints()
			mark.text:SetPoint("BOTTOM", labels, "BOTTOMLEFT", x, y + LABEL_LIFT)
			mark.text:SetText(node.code)
			mark.text:Show()
			mark.bg:Show()
		else
			mark.text:Hide()
			mark.bg:Hide()
		end
	end
	for i = #nodes + 1, #marks do
		marks[i].text:Hide()
		marks[i].bg:Hide()
	end
end

-- Last layout inputs, compared value by value (no string built every tick).
local laid = {}

local function layoutChanged(rects, cur)
	local c, v = rects.c, rects.v
	if laid.cl == c.l and laid.cb == c.b and laid.cw == c.w and laid.ch == c.h and laid.vl == v.l and laid.vb == v.b
		and laid.vw == v.w and laid.vh == v.h and laid.fake == cur.fakeMapID and laid.nodes == ns.nodesVersion then
		return false
	end
	laid.cl, laid.cb, laid.cw, laid.ch, laid.vl, laid.vb, laid.vw, laid.vh = c.l, c.b, c.w, c.h, v.l, v.b, v.w, v.h
	laid.fake, laid.nodes = cur.fakeMapID, ns.nodesVersion
	return true
end

local shownState -- what is shown, to call Show/Hide only on changes

function MapVisuals.Update(rects)
	if not rects then
		if shownState ~= "none" then
			shownState = "none"
			art:Hide()
			labels:Hide()
			warning:Hide()
			wipe(laid)
		end
		return
	end
	local cur = ns.current
	local wantArt = cur.fakeMapID ~= nil
	if wantArt and cur.fakeMapID ~= artMapID then
		loadArt(cur.fakeMapID)
		wipe(laid)
	end
	if layoutChanged(rects, cur) then
		if wantArt then
			layoutArt(rects)
			artTitle:SetText("BGComs test: " .. (cur.ctx and cur.ctx.profile and cur.ctx.profile.name or "?")
				.. (artLayer and "" or " (map art not found)"))
		end
		layoutLabels(rects)
		if ns.mapMoved then
			warning:ClearAllPoints()
			warning:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", rects.c.l + rects.c.w / 2, rects.c.b + rects.c.h + 16)
		end
	end
	local state = (wantArt and "a" or "") .. (ns.db.showNodes and "l" or "") .. (ns.mapMoved and "w" or "")
	if state ~= shownState then
		shownState = state
		art:SetShown(wantArt)
		labels:SetShown(ns.db.showNodes and true or false)
		if ns.mapMoved then
			local c = rects.c
			warning:ClearAllPoints()
			warning:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", c.l + c.w / 2, c.b + c.h + 16)
		end
		warning:SetShown(ns.mapMoved and true or false)
	end
end

ns.nodesVersion = 0
ns.Listen("NODES_CHANGED", function()
	ns.nodesVersion = ns.nodesVersion + 1
end)

ns.AddDebugPart("visuals", function()
	return {
		art = ns.art,
		artScale = artScale,
		fakeArtMapID = artMapID,
		fakeArtLayer = artLayer,
		tiles = #tiles,
		fakeArtShown = art:IsShown(),
		labelsShown = labels:IsShown(),
	}
end)
