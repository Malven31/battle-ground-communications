-- Options page (Options > AddOns > BGComs, /bgc, or the addon compartment).

local ADDON, ns = ...

local panel, category
local controls = {}
local ICON = "Interface\\AddOns\\BGComs\\media\\icon"

local function Refresh()
	for _, control in ipairs(controls) do
		control.Refresh()
	end
end

local function Tooltip(widget, title, text)
	if not text then
		return
	end
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		GameTooltip:AddLine(text, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function CheckBox(parent, label, tooltip, get, set)
	local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	c:SetSize(24, 24)
	c.label = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	c.label:SetPoint("LEFT", c, "RIGHT", 4, 0)
	c.label:SetText(label)
	c:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		Refresh()
	end)
	Tooltip(c, label, tooltip)
	c.Refresh = function()
		c:SetChecked(get() and true or false)
	end
	controls[#controls + 1] = c
	return c
end

local function Button(parent, text, width, onClick, tooltip)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	Tooltip(b, text, tooltip)
	return b
end

-- A message text: what the call sends. <n> is the count, <loc> the place; empty switches the call off.
local function Clean(text)
	text = string.gsub(text or "", "[|\r\n]", "")
	text = strtrim(text)
	return string.sub(text, 1, 120)
end

local function TemplateBox(parent, sector)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(190, 20)
	box:SetAutoFocus(false)
	box:SetMaxLetters(120)
	box.label = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	box.label:SetPoint("RIGHT", box, "LEFT", -10, 0)
	box.label:SetWidth(70)
	box.label:SetJustifyH("RIGHT")
	box.label:SetText(sector.label)
	local function save(self)
		local text = Clean(self:GetText())
		if text == (ns.TEMPLATES[sector.kind] or "") then
			ns.db.templates[sector.kind] = nil
		else
			ns.db.templates[sector.kind] = text
		end
		ns.Fire("SETTINGS_CHANGED")
	end
	box:SetScript("OnEnterPressed", function(self)
		save(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", save)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		self.Refresh()
	end)
	Tooltip(box, sector.label, "What this call sends. <n> is the count, <loc> the place. Leave it empty to switch the call off."
		.. (sector.flagOnly and " Only in battlegrounds with a flag." or ""))
	box.Refresh = function()
		if box:HasFocus() then
			return
		end
		local custom = ns.db.templates[sector.kind]
		box:SetText(custom or ns.TEMPLATES[sector.kind] or "")
		box:SetCursorPosition(0)
	end
	controls[#controls + 1] = box
	return box
end

local function SetupOptionsPage()
	panel = CreateFrame("Frame")
	panel.name = "BGComs"

	local y = -16
	local function place(widget, x, height, gapBefore)
		y = y - (gapBefore or 0)
		widget:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
		y = y - height
	end

	local function Text(template, text, width)
		local fs = panel:CreateFontString(nil, "ARTWORK", template)
		fs:SetJustifyH("LEFT")
		if width then
			fs:SetWidth(width)
		end
		fs:SetText(text)
		return fs
	end

	-- Header: the icon, the name, what it does.
	local icon = panel:CreateTexture(nil, "ARTWORK")
	icon:SetSize(44, 44)
	icon:SetTexture(ICON)
	place(icon, 16, 44)
	local title = Text("GameFontNormalLarge", "BGComs - Battle Ground Communications")
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -4)
	local subtitle = Text("GameFontHighlight", "On the battlefield map (Shift-M): click near a place with the middle button, drag "
		.. "towards a call, release. Everyone in the battleground reads it in chat, with or without the addon.", 520)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

	-- The click.
	place(Text("GameFontNormal", "Click"), 16, 16, 18)
	local choices = {
		{ "none", "Middle-click" },
		{ "alt", "Alt + middle-click" },
		{ "ctrl", "Ctrl + middle-click" },
		{ "shift", "Shift + middle-click" },
	}
	local previous
	for _, choice in ipairs(choices) do
		local c = CheckBox(panel, choice[2], nil,
			function() return ns.db.modifier == choice[1] end,
			function() ns.SetModifier(choice[1]) end)
		if previous then
			c:SetPoint("LEFT", previous.label, "RIGHT", 16, 0)
		else
			place(c, 14, 24, 4)
		end
		previous = c
	end

	-- The map.
	place(Text("GameFontNormal", "Battlefield map"), 16, 16, 14)
	place(CheckBox(panel, "Open the battlefield map (Shift-M) in battlegrounds",
		"When you enter a battleground, BGComs switches the battlefield map's own setting on, and Blizzard's map opens "
			.. "itself. If it was closed before, its setting goes back to closed when you leave: it won't open by itself "
			.. "outside battlegrounds, but it stays on screen until you press Shift-M (closing Blizzard's map from an "
			.. "addon could cause errors in it).",
		function() return ns.db.autoMap end,
		function(value) ns.db.autoMap = value end), 14, 24, 4)
	place(CheckBox(panel, "Show the place codes on the map",
		"The codes the callouts use (ST, GM, our tun...), drawn where the click picks them.",
		function() return ns.db.showNodes end,
		function(value)
			ns.db.showNodes = value
			ns.Fire("SETTINGS_CHANGED")
		end), 14, 24, 2)
	place(CheckBox(panel, "Map tooltips under the click area",
		"The invisible callout button over the map lets mouse movement through, so the map's tooltips still show. "
			.. "If middle-clicks on the map do nothing at all, untick this.",
		function() return not ns.db.motion end,
		function(value) ns.SetMotion(value and "off" or "on") end), 14, 24, 2)

	-- The messages.
	place(Text("GameFontNormal", "Messages"), 16, 16, 14)
	place(Text("GameFontDisableSmall", "<n> is the count, <loc> the place. Empty switches a call off.", 520), 16, 14, 2)
	y = y - 8
	local rowY = y
	for i, sector in ipairs(ns.SECTORS) do
		local box = TemplateBox(panel, sector)
		local column = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		box:SetPoint("TOPLEFT", panel, "TOPLEFT", 100 + column * 300, rowY - row * 28)
	end
	y = rowY - 3 * 28
	place(Button(panel, "Default messages", 150, function()
		wipe(ns.db.templates)
		ns.Fire("SETTINGS_CHANGED")
		Refresh()
	end), 16, 22, 4)

	-- Test.
	place(Text("GameFontNormal", "Try it outside battlegrounds"), 16, 16, 16)
	local testState = Text("GameFontHighlightSmall", "", 560)
	local testPrint = Button(panel, "Arathi Basin, chat only", 180, function()
		ns.SetTest("ab print")
		Refresh()
	end, "Draws Arathi Basin over your Shift-M map anywhere. Callouts are only shown in your chat.")
	place(testPrint, 16, 22, 4)
	local testSay = Button(panel, "Arathi Basin, send with /s", 190, function()
		ns.SetTest("ab say")
		Refresh()
	end, "Same, but the callouts are really sent, with /s, through the same path as in battlegrounds.")
	testSay:SetPoint("LEFT", testPrint, "RIGHT", 8, 0)
	local testOff = Button(panel, "Stop the test", 120, function()
		ns.SetTest("off")
		Refresh()
	end)
	testOff:SetPoint("LEFT", testSay, "RIGHT", 8, 0)
	place(testState, 18, 14, 4)
	testState.Refresh = function()
		local mode = ns.db.test
		if mode == "off" then
			testState:SetText("Test mode is off.")
		else
			testState:SetText("Test mode: " .. tostring(ns.db.testProfile) .. ", " .. (mode == "say" and "sent with /s" or "chat only") .. ".")
		end
	end
	controls[#controls + 1] = testState

	-- Tools.
	place(Text("GameFontNormal", "Checks"), 16, 16, 14)
	local perf = Button(panel, "Measure performance", 170, function()
		ns.StartPerf()
	end, "18 seconds: BGComs' time per frame normally, with the wheel open, and paused. Stand still. Results in chat.")
	place(perf, 16, 22, 4)
	local debug = Button(panel, "Save debug state", 150, function()
		ns.SaveDebug()
	end, "Saves what BGComs sees into its saved variables, for bug reports.")
	debug:SetPoint("LEFT", perf, "RIGHT", 8, 0)

	place(Text("GameFontDisableSmall",
		"Commands: /bgc help. /bgc place CODE moves a place with your next click on the map, /bgc forget CODE undoes it.", 560),
		16, 28, 12)

	panel:SetScript("OnShow", Refresh)

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		category = Settings.RegisterCanvasLayoutCategory(panel, "BGComs")
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end

function ns.OpenOptions()
	if not panel then
		ns.PrintHelp()
		return
	end
	if category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

function BGComs_OnAddonCompartmentClick()
	ns.SafeCall(ns.OpenOptions)
end

ns.Listen("SETTINGS_CHANGED", function()
	if panel and panel:IsShown() then
		Refresh()
	end
end)

ns.Listen("LOGIN", function()
	local ok, err = pcall(SetupOptionsPage)
	if not ok then
		ns.Print("options page failed: " .. tostring(err))
	end
end)
