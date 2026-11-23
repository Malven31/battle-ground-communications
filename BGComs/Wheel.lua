-- BGComs visuals, all plain (insecure) frames, free to change in combat:
--   the drag wheel shown while the middle button is held, the "sent" flash, the place codes drawn
--   on the battlefield map, and the battleground map art drawn over it in test mode.
-- The wheel uses ns.Classify, the same rules as the secure snippet, so what it highlights is what
-- the release sends.
--
-- Look: BGComs' own textures in media/, drawn by scripts/make-media.ps1 with the same code as the
-- CurseForge gallery pictures (scripts/wheel-art.ps1): a dark disc with its rim and six dividers, a
-- gold glow turned onto the selected wedge, and an icon per call. The count rings, the selected
-- wedge's gold rim and the pointer are soft lines.
-- Cost: nothing runs while the wheel is closed; while open, work is done only when the cursor
-- moves, and textures and text change only when the selection changes.

local _, ns = ...

local G = ns.GEOMETRY
local DEG = 180 / math.pi
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local OUTER = G.dead + G.band * G.maxCount -- edge of the counted bands (132)
local DISC = 2 * (OUTER + 12) -- disc diameter (288)
local ART = DISC + 8 -- side of the disc and wedge textures: the disc and a margin round it (make-media.ps1)
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0
local MEDIA = "Interface\\AddOns\\BGComs\\media\\"
-- White textures, tinted: a line with soft edges, a round glow, a rounded pill.
local SOFT_LINE = MEDIA .. "softline"
local GLOW = MEDIA .. "glow"
local PILL = MEDIA .. "pill"
local SOFT = 2.4 -- a soft line is drawn this much thicker than its look, its edges being transparent

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

-- Shows or hides lines, colouring them (and setting their look's thickness, if given) when shown.
local function setLines(lines, shown, r, g, b, a, thickness)
	for _, line in ipairs(lines) do
		if shown then
			line:SetVertexColor(r, g, b, a)
			if thickness then
				line:SetThickness(thickness * SOFT)
			end
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

-- Text readable at a glance: a thick outline and a drop shadow.
local function newShadowText(parent, size)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetDrawLayer("OVERLAY", 4)
	text:SetFont(FONT, size, "THICKOUTLINE")
	text:SetShadowColor(0, 0, 0, 0.9)
	text:SetShadowOffset(2, -2)
	return text
end

-- A dark pill behind a text of font size `size`: media/pill cut in three, so its round ends keep
-- their shape and only the middle stretches with the text.
local function newPill(parent, text, size, padX, padY, alpha, sublevel)
	local height = size + 2 * padY
	local cap = height / 2 -- each half of the square texture, at the pill's height
	local function piece(left, right)
		local t = parent:CreateTexture(nil, "BACKGROUND", nil, sublevel)
		t:SetTexture(PILL) -- before the coordinates: setting a texture can reset them
		t:SetTexCoord(left, right, 0, 1)
		t:SetVertexColor(0, 0, 0, alpha)
		return t
	end
	local leftEnd = piece(0, 0.5)
	leftEnd:SetSize(cap, height)
	leftEnd:SetPoint("LEFT", text, "LEFT", -padX, 0)
	local rightEnd = piece(0.5, 1)
	rightEnd:SetSize(cap, height)
	rightEnd:SetPoint("RIGHT", text, "RIGHT", padX, 0)
	local middle = piece(0.47, 0.53)
	middle:SetPoint("TOPLEFT", leftEnd, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", rightEnd, "BOTTOMLEFT")
end

-- Layers, bottom to top: the disc (BACKGROUND), the wedge glow (BORDER), the count rings and the
-- gold rim (ARTWORK 2), the centre's shade (4), the cancel glow (5), the pointer (6), the icons
-- and the texts (OVERLAY).

-- The disc, its rim and its six dividers fading out towards the centre.
local disc = wheel:CreateTexture(nil, "BACKGROUND", nil, 1)
disc:SetPoint("CENTER")
disc:SetSize(ART, ART)
disc:SetTexture(MEDIA .. "disc")

-- The selected wedge's gold glow. The texture is drawn pointing right and centred on the wheel,
-- so turning it about its own centre (SetRotation) turns it onto any wedge.
local wedgeGlow = wheel:CreateTexture(nil, "BORDER", nil, 1)
wedgeGlow:SetPoint("CENTER")
wedgeGlow:SetSize(ART, ART)
wedgeGlow:SetTexture(MEDIA .. "wedge")
wedgeGlow:Hide()

-- The centre, blurred: a soft dark glow behind the place code, over the first count ring.
local centerShade = wheel:CreateTexture(nil, "ARTWORK", nil, 4)
centerShade:SetPoint("CENTER")
centerShade:SetSize(G.dead * 2 + 56, G.dead * 2 + 56)
centerShade:SetTexture(GLOW)
centerShade:SetVertexColor(0, 0, 0, 0.8)

-- The centre while the cursor is in it (release = cancel).
local cancelGlow = wheel:CreateTexture(nil, "ARTWORK", nil, 5)
cancelGlow:SetPoint("CENTER")
cancelGlow:SetSize(G.dead * 2 + 24, G.dead * 2 + 24)
cancelGlow:SetTexture(GLOW)
cancelGlow:SetVertexColor(1, 1, 1, 0.25)
cancelGlow:Hide()

-- The pointer: a soft gold line from the centre, where it is invisible, to the cursor.
local pointerLine = newLine(0, 0, 1, 1, 3.5, GOLD_R, GOLD_G, GOLD_B, 0.92, 6)
fadeIn(pointerLine, GOLD_R, GOLD_G, GOLD_B, 0.92)
pointerLine:Hide()

-- Each call: its icon (EFC's is the enemy's flag, set on opening), its name, the gold rim of its
-- wedge, and for counted calls the count rings, shown while that wedge is selected.
-- An icon texture spans 1.5 times the drawing's size (34), its edges being transparent.
local ICON = 34 * 1.5
local ICON_FILES = { inc = "icon-inc", spotted = "icon-spotted", help = "icon-help", omw = "icon-omw", clear = "icon-clear" }
-- From an icon's centre to its name: above or below it, or beside it.
local LABEL_GAP_Y, LABEL_GAP_X = 26, 30

local parts = {}
for _, sector in ipairs(ns.SECTORS) do
	local part = {}
	parts[sector] = part
	local mid = (sector.from + sector.to) / 2
	part.mid = mid
	local ix, iy = polar(G.iconRadius, mid)
	part.icon = wheel:CreateTexture(nil, "OVERLAY", nil, 3)
	part.icon:SetPoint("CENTER", wheel, "CENTER", ix, iy)
	part.icon:SetSize(ICON, ICON)
	if ICON_FILES[sector.kind] then
		part.icon:SetTexture(MEDIA .. ICON_FILES[sector.kind])
	end
	part.flag = (sector.kind == "efc")

	-- The name on the outer side of the icon, at a set distance from its centre, so it stays put
	-- when the selected icon grows.
	part.label = newShadowText(wheel, 15)
	part.label:SetText(sector.label)
	-- A soft dark patch under the name: half of it lies over the map, past the disc.
	local shade = wheel:CreateTexture(nil, "ARTWORK", nil, 3)
	shade:SetTexture(GLOW)
	shade:SetVertexColor(0, 0, 0, 0.6)
	shade:SetPoint("TOPLEFT", part.label, "TOPLEFT", -14, 9)
	shade:SetPoint("BOTTOMRIGHT", part.label, "BOTTOMRIGHT", 14, -9)
	local a = mid / DEG
	local q = math.pi / 4
	if a > q and a <= math.pi - q then
		part.label:SetPoint("BOTTOM", wheel, "CENTER", ix, iy + LABEL_GAP_Y)
	elseif a > math.pi - q and a <= math.pi + q then
		part.label:SetPoint("RIGHT", wheel, "CENTER", ix - LABEL_GAP_X, iy)
	elseif a > math.pi + q and a <= 2 * math.pi - q then
		part.label:SetPoint("TOP", wheel, "CENTER", ix, iy - LABEL_GAP_Y)
	else
		part.label:SetPoint("LEFT", wheel, "CENTER", ix + LABEL_GAP_X, iy)
	end

	part.rim = newArc(DISC / 2 - 3, sector.from + 1, sector.to - 1, 4, GOLD_R, GOLD_G, GOLD_B, 1)
	setLines(part.rim, false)
	if sector.counted then
		part.bands = {}
		for band = 1, G.maxCount do
			part.bands[band] = newArc(G.dead + G.band * band, sector.from + 2, sector.to - 2, 1.5, 1, 1, 1, 0.27)
			setLines(part.bands[band], false)
		end
	end
end

local locText = newShadowText(wheel, 22)
locText:SetPoint("CENTER", wheel, "CENTER", 0, 5)
local countText = newShadowText(wheel, 16)
countText:SetPoint("CENTER", wheel, "CENTER", 0, -17)
countText:SetTextColor(GOLD_R, GOLD_G, GOLD_B)

-- The message that the release sends, on a dark pill under the disc.
local PREVIEW_SIZE = 18
local preview = newShadowText(wheel, PREVIEW_SIZE)
preview:SetPoint("CENTER", wheel, "CENTER", 0, -(DISC / 2 + 25))
newPill(wheel, preview, PREVIEW_SIZE, 14, 6, 0.69, 2)

local movedText = newText(10, 0, -(DISC / 2 + 52))
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
			part.label:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
			part.icon:SetSize(ICON * 1.15, ICON * 1.15)
		else
			local v = enabled and 0.92 or 0.45
			part.label:SetTextColor(v, v, v)
			part.icon:SetSize(ICON, ICON)
		end
		part.icon:SetDesaturated(not enabled)
		part.icon:SetAlpha(enabled and (selected and 1 or 0.8) or 0.3)
		setLines(part.rim, selected, GOLD_R, GOLD_G, GOLD_B, 1)
		if part.bands then
			-- The ring of the current count in gold and thicker, the others faint.
			for b, arc in ipairs(part.bands) do
				if selected and b == math.min(band or 0, G.maxCount) then
					setLines(arc, true, GOLD_R, GOLD_G, GOLD_B, 1, 3)
				else
					setLines(arc, selected, 1, 1, 1, 0.27, 1.5)
				end
			end
		end
	end
	if sector then
		wedgeGlow:SetRotation(parts[sector].mid / DEG)
		wedgeGlow:Show()
	else
		wedgeGlow:Hide()
	end
	cancelGlow:SetShown(not sector and not disabled)
	local v = sector and 1 or 0.6
	locText:SetTextColor(v, v, v)
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
		local reach = math.min(math.sqrt(dx * dx + dy * dy), OUTER + 8)
		pointerLine:SetEndPoint("CENTER", wheel, reach * math.cos(angle), reach * math.sin(angle))
		pointerLine:Show()
	else
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

-- EFC's icon: the enemy's flag, blue for a Horde player, red otherwise.
local function setFlagIcon()
	local file = (UnitFactionGroup("player") == "Horde") and "flag-blue" or "flag-red"
	for _, part in pairs(parts) do
		if part.flag and part.flagFile ~= file then
			part.flagFile = file
			part.icon:SetTexture(MEDIA .. file)
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
local flashText = newShadowText(flash, 18)
flashText:SetPoint("CENTER")
newPill(flash, flashText, 18, 14, 6, 0.6, 0)
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
	flashText:SetTextColor(r or 1, g or 1, b or 1)
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
		fakeArtMapID = artMapID,
		fakeArtLayer = artLayer,
		tiles = #tiles,
		fakeArtShown = art:IsShown(),
		labelsShown = labels:IsShown(),
	}
end)
