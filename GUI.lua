local addonName = "BGHistorian"
local addonTitle = select(2, GetAddOnInfo(addonName))
local BGH = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceGUI = LibStub("AceGUI-3.0")
local f, scrollFrame, rows, stats
local lblWinrate, lblDuration, lblKB, lblHK

function BGH:CreateGUI()
    f = AceGUI:Create("Frame")
    f:Hide()
    f:EnableResize(false)

    -- f:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    f:SetTitle(addonTitle)
    local frameName = addonName .."_MainFrame"
	_G[frameName] = f
	table.insert(UISpecialFrames, frameName) -- Allow ESC close
    f:SetStatusText("Status Bar")
    f:SetLayout("Flow")

    -- STATS HEADER
    local statsHeader = AceGUI:Create("SimpleGroup")
	statsHeader:SetFullWidth(true)
	statsHeader:SetLayout("Flow")
    f:AddChild(statsHeader)

    -- WINRATE
    local block = AceGUI:Create("SimpleGroup")
    block:SetRelativeWidth(0.2)
    statsHeader:AddChild(block)

	local lbl = AceGUI:Create("Label")
    lbl:SetJustifyH("CENTER")
    lbl:SetFullWidth(true)
    lbl:SetText(L["Winrate"])
    lbl:SetFontObject(GameFontHighlight)
    block:AddChild(lbl)

	lblWinrate = AceGUI:Create("InteractiveLabel")
    lblWinrate:SetJustifyH("CENTER")
    lblWinrate:SetFullWidth(true)
    lblWinrate:SetFontObject(GameFontHighlightLarge)
    lblWinrate:SetText(string.format("%.2f%%", 0))
	lblWinrate:SetCallback("OnEnter", function() self:ShowTooltip(lblWinrate, {
        string.format("|cff777777%s|r : |cFFCFCFCF%i/%i (%.2f%%)|r", self:MapName(1), stats["victories"][1], stats["count"][1], stats["winrate"][1] * 100),
        string.format("|cff777777%s|r : |cFFCFCFCF%i/%i (%.2f%%)|r", self:MapName(2), stats["victories"][2], stats["count"][2], stats["winrate"][2] * 100),
        string.format("|cff777777%s|r : |cFFCFCFCF%i/%i (%.2f%%)|r", self:MapName(3), stats["victories"][3], stats["count"][3], stats["winrate"][3] * 100),
    }) end)
	lblWinrate:SetCallback("OnLeave", function() self:HideTooltip() end)
    block:AddChild(lblWinrate)

    -- DURATION
    block = AceGUI:Create("SimpleGroup")
    block:SetRelativeWidth(0.3)
    statsHeader:AddChild(block)

	lbl = AceGUI:Create("Label")
    lbl:SetJustifyH("CENTER")
    lbl:SetFullWidth(true)
    lbl:SetText(L["Duration"])
    lbl:SetFontObject(GameFontHighlight)
    block:AddChild(lbl)

	lblDuration = AceGUI:Create("InteractiveLabel")
    lblDuration:SetJustifyH("CENTER")
    lblDuration:SetFullWidth(true)
    lblDuration:SetFontObject(GameFontHighlightLarge)
    lblDuration:SetText(self:HumanDuration(0))
	lblDuration:SetCallback("OnEnter", function() self:ShowTooltip(lblDuration, {
        string.format("|cff777777%s|r : |cFFCFCFCF%s (%s)|r", self:MapName(1), self:HumanDuration(stats["averageRunTime"][1]), self:HumanDuration(stats["runTime"][1])),
        string.format("|cff777777%s|r : |cFFCFCFCF%s (%s)|r", self:MapName(2), self:HumanDuration(stats["averageRunTime"][2]), self:HumanDuration(stats["runTime"][2])),
        string.format("|cff777777%s|r : |cFFCFCFCF%s (%s)|r", self:MapName(3), self:HumanDuration(stats["averageRunTime"][3]), self:HumanDuration(stats["runTime"][3])),
    }) end)
	lblDuration:SetCallback("OnLeave", function() self:HideTooltip() end)
    block:AddChild(lblDuration)

    -- KB
    block = AceGUI:Create("SimpleGroup")
    block:SetRelativeWidth(0.25)
    statsHeader:AddChild(block)

    lbl = AceGUI:Create("Label")
    lbl:SetJustifyH("CENTER")
    lbl:SetFullWidth(true)
    lbl:SetText(L["Killing Blows"])
    lbl:SetFontObject(GameFontHighlight)
    block:AddChild(lbl)

    lblKB = AceGUI:Create("InteractiveLabel")
    lblKB:SetJustifyH("CENTER")
    lblKB:SetFullWidth(true)
    lblKB:SetFontObject(GameFontHighlightLarge)
    lblKB:SetText('0')
    lblKB:SetCallback("OnEnter", function() self:ShowTooltip(lblKB, {
        string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(1), stats["averageKillingBlows"][1], stats["killingBlows"][1]),
        string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(2), stats["averageKillingBlows"][2], stats["killingBlows"][2]),
        string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(3), stats["averageKillingBlows"][3], stats["killingBlows"][3]),
    }) end)
    lblKB:SetCallback("OnLeave", function() self:HideTooltip() end)
    block:AddChild(lblKB)

    -- HK
    block = AceGUI:Create("SimpleGroup")
    block:SetRelativeWidth(0.25)
    statsHeader:AddChild(block)

    lbl = AceGUI:Create("Label")
    lbl:SetJustifyH("CENTER")
    lbl:SetFullWidth(true)
    lbl:SetText(L["Honorable Kills"])
    lbl:SetFontObject(GameFontHighlight)
    block:AddChild(lbl)

    lblHK = AceGUI:Create("InteractiveLabel")
    lblHK:SetJustifyH("CENTER")
    lblHK:SetFullWidth(true)
    lblHK:SetFontObject(GameFontHighlightLarge)
    lblHK:SetText('0')
    lblHK:SetCallback("OnEnter", function() self:ShowTooltip(lblHK, {
        string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(1), stats["averageHonorableKills"][1], stats["honorableKills"][1]),
        string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(2), stats["averageHonorableKills"][2], stats["honorableKills"][2]),
        string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(3), stats["averageHonorableKills"][3], stats["honorableKills"][3]),
    }) end)
    lblHK:SetCallback("OnLeave", function() self:HideTooltip() end)
    block:AddChild(lblHK)

    -- TABLE HEADER
    local tableHeader = AceGUI:Create("SimpleGroup")
	tableHeader:SetFullWidth(true)
	tableHeader:SetLayout("Flow")
    f:AddChild(tableHeader)

    local margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    local btn
	btn = AceGUI:Create("InteractiveLabel")
    btn:SetWidth(145)
    btn:SetText(string.format(" %s ", L["Date"]))
    btn:SetJustifyH("LEFT")
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetCallback("OnClick", function() BGH:Sort("endTime") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(170)
	btn:SetText(string.format(" %s ", L["Battleground"]))
    btn:SetJustifyH("LEFT")
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetCallback("OnClick", function() BGH:Sort("mapName") end)
	tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(94)
	btn:SetText(string.format(" %s ", L["Duration"]))
    btn:SetJustifyH("LEFT")
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetCallback("OnClick", function() BGH:Sort("runTime") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(40)
	btn:SetText(string.format(" %s ", L["Winner"]))
    btn:SetJustifyH("CENTER")
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetCallback("OnClick", function() BGH:Sort("battlefieldWinner") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(36)
	btn:SetText(string.format(" %s ", L["KB"]))
    btn:SetJustifyH("RIGHT")
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetCallback("OnClick", function() BGH:Sort("killingBlows") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)
	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(40)
	btn:SetText(string.format(" %s ", L["HK"]))
    btn:SetJustifyH("RIGHT")
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetCallback("OnClick", function() BGH:Sort("honorableKills") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(40)
	btn:SetText(string.format(" %s ", L["Deaths"]))
    btn:SetJustifyH("RIGHT")
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetCallback("OnClick", function() BGH:Sort("deaths") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(44)
	btn:SetText(string.format(" %s ", L["Honor"]))
    btn:SetJustifyH("RIGHT")
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetCallback("OnClick", function() BGH:Sort("honorGained") end)
	tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    -- TABLE
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    f:AddChild(scrollContainer)

	scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer.frame, "BGHHybridScrollFrame")
	HybridScrollFrame_CreateButtons(scrollFrame, "BGHHybridScrollListItemTemplate")
	scrollFrame.update = function() BGH:UpdateTableView() end
end

function BGH:RefreshLayout()
	local buttons = HybridScrollFrame_GetButtons(scrollFrame)
    local offset = HybridScrollFrame_GetOffset(scrollFrame)

    f:SetStatusText(string.format(L["Recorded %i battlegrounds"], #rows))
    lblWinrate:SetText(string.format("%i/%i (%.2f%%)", stats["victories"][0], stats["count"][0], stats["winrate"][0] * 100))
    lblDuration:SetText(string.format("%s: %s | %s: %s", L["Avg"], self:HumanDuration(stats["averageRunTime"][0]), L["Sum"], self:HumanDuration(stats["runTime"][0])))
    lblKB:SetText(string.format("%s: %.1f | %s: %i", L["Avg"], stats["averageKillingBlows"][0], L["Sum"], stats["killingBlows"][0]))
    lblHK:SetText(string.format("%s: %.1f | %s: %i", L["Avg"], stats["averageHonorableKills"][0], L["Sum"], stats["honorableKills"][0]))

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
        local itemIndex = buttonIndex + offset
        local row = rows[itemIndex]

        if (itemIndex <= #rows) then
            button:SetID(itemIndex)
            button.Icon:SetTexture(self:MapIconId(row["mapId"]))
            button.EndTime:SetText(date(L["%F %T"], row["endTime"]))
            button.MapName:SetText(row["mapName"])
            button.RunTime:SetText(self:HumanDuration(row["runTime"]))
            button.BattlefieldWinner:SetTexture(132485 + row["battlefieldWinner"])
            button.KillingBlows:SetText(row["killingBlows"])
            button.HonorableKills:SetText(row["honorableKills"])
            button.Deaths:SetText(row["deaths"])
            button.HonorGained:SetText(row["honorGained"])

            button:SetWidth(scrollFrame.scrollChild:GetWidth())
			button:Show()
		else
			button:Hide()
		end
	end

	local buttonHeight = scrollFrame.buttonHeight
	local totalHeight = #rows * buttonHeight
	local shownHeight = #buttons * buttonHeight

	HybridScrollFrame_Update(scrollFrame, totalHeight, shownHeight)
end

function BGH:Show()
    if not f then
        self:CreateGUI()
    end

    rows = BGH:BuildTable()
    stats = BGH:CalcStats(rows)

    f:Show()
    self:RefreshLayout()
end

function BGH:Hide()
    f:Hide()
end

function BGH:Toggle()
    if f and f:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function BGH:Sort(column)
    scrollFrame:SetVerticalScroll(0)
    rows = BGH:BuildTable(column)
    self:RefreshLayout()
end

function BGH:HumanDuration(miliseconds)
    local seconds = math.floor(miliseconds / 1000)
    if seconds < 60 then
        return string.format(L["%is"], seconds)
    end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then
        return string.format(L["%im %is"], minutes, (seconds - minutes * 60))
    end
    local hours = math.floor(minutes / 60)
    return string.format(L["%ih %im"], hours, (minutes - hours * 60))
end

function BGH:MapIconId(mapId)
    if not mapId then
        return 136628
    end

    if mapId == 1 then -- Alterac Valley
        return 133308
    elseif mapId == 2 then -- Warsong Gulch
        return 134420
    elseif mapId == 3 then -- Arathi Basin
        return 133282
    end
end

function BGH:ShowTooltip(owner, lines)
    AceGUI.tooltip:SetOwner(owner.frame, "ANCHOR_TOP")
    AceGUI.tooltip:ClearLines()
    for i, line in ipairs(lines) do
        AceGUI.tooltip:AddLine(line)
    end
    AceGUI.tooltip:Show()
end

function BGH:HideTooltip()
    AceGUI.tooltip:Hide()
end
