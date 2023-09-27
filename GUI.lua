local addonName = "BGHistorian"
local addonTitle = select(2, _G.GetAddOnInfo(addonName))
local BGH = _G.LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceGUI = _G.LibStub("AceGUI-3.0")
local f, scrollFrame, rows, stats, dropDown
local lblWinrate, lblDuration, lblKB, lblHK, lblDmgDone, lblHlgDone, lblHonor
local BGFilter = 0

function BGH:CreateGUI()
    f = AceGUI:Create("Frame")
    f:Hide()
    f:SetWidth(905)
    f:EnableResize(false)

    -- f:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    f:SetTitle(addonTitle)
    local frameName = addonName .."_MainFrame"
    _G[frameName] = f
    table.insert(_G.UISpecialFrames, frameName) -- Allow ESC close
    f:SetStatusText("Status Bar")
    f:SetLayout("Flow")

    -- STATS HEADER
    local statsHeader = AceGUI:Create("SimpleGroup")
    statsHeader:SetFullWidth(true)
    statsHeader:SetLayout("Flow")
    f:AddChild(statsHeader)

    lblWinrate = BGH:CreateHeaderButton(statsHeader, lblDuration, 0.1599, "Winrate", function(idx)
        return string.format("|cff777777%s|r : |cFFCFCFCF%i/%i (%.2f%%)|r", self:MapName(idx), stats["victories"][idx], stats["count"][idx], stats["winrate"][idx] * 100)
    end)
    lblDuration = BGH:CreateHeaderButton(statsHeader, lblDuration, 0.14, "Duration", function(idx)
        return string.format("|cff777777%s|r : |cFFCFCFCF%s (%s)|r", self:MapName(idx), self:HumanDuration(stats["averageRunTime"][idx]), self:HumanDuration(stats["runTime"][idx]))
    end)
    lblKB = BGH:CreateHeaderButton(statsHeader, lblKB, 0.14, "Killing Blows", function(idx)
        return string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(idx), stats["averageKillingBlows"][idx], stats["killingBlows"][idx])
    end)
    lblHK = BGH:CreateHeaderButton(statsHeader, lblHK, 0.14, "Honorable Kills", function(idx)
        return string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(idx), stats["averageHonorableKills"][idx], stats["honorableKills"][idx])
    end)
    lblDmgDone = BGH:CreateHeaderButton(statsHeader, lblDmgDone, 0.14, "Damage Done", function(idx)
        return string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(idx), stats["averageDamageDone"][idx], stats["damageDone"][idx])
    end)
    lblHlgDone = BGH:CreateHeaderButton(statsHeader, lblHlgDone, 0.14, "Healing Done", function(idx)
        return string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(idx), stats["averageHealingDone"][idx], stats["healingDone"][idx])
    end)
    lblHonor = BGH:CreateHeaderButton(statsHeader, lblHonor, 0.14, "Honor", function(idx)
        return string.format("|cff777777%s|r : |cFFCFCFCF%.1f (%i)|r", self:MapName(idx), stats["averageHonor"][idx], stats["honor"][idx])
    end)

    -- TABLE HEADER
    local tableHeader = AceGUI:Create("SimpleGroup")
    tableHeader:SetFullWidth(true)
    tableHeader:SetLayout("Flow")
    f:AddChild(tableHeader)

    local margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    BGH:CreateScoreButton(tableHeader, 145, "Date", "endTime")
    BGH:CreateScoreButton(tableHeader, 170, "Battleground", "mapName")
    BGH:CreateScoreButton(tableHeader, 94, "Duration", "runTime")
    BGH:CreateScoreButton(tableHeader, 60, "Winner", "battlefieldWinner")
    BGH:CreateScoreButton(tableHeader, 36, "KB", "killingBlows")
    BGH:CreateScoreButton(tableHeader, 90, "Damage", "damageDone")
    BGH:CreateScoreButton(tableHeader, 90, "Healing", "healingDone")
    BGH:CreateScoreButton(tableHeader, 40, "HK", "honorableKills")
    BGH:CreateScoreButton(tableHeader, 40, "Deaths", "deaths")
    BGH:CreateScoreButton(tableHeader, 40, "Honor", "honorGained")

    -- TABLE
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    f:AddChild(scrollContainer)

    scrollFrame = _G.CreateFrame("ScrollFrame", nil, scrollContainer.frame, "BGHHybridScrollFrame")
    _G.HybridScrollFrame_CreateButtons(scrollFrame, "BGHHybridScrollListItemTemplate")
    scrollFrame.update = function() BGH:UpdateTableView() end

    self:CreateBGFilterDropDown()
end

function BGH:CreateBGFilterDropDown()
    dropDown = _G.CreateFrame("Frame", "FilterDropDownMenu", f.frame, "UIDropDownMenuTemplate")
    dropDown:SetPoint("bottomright", f.frame, "bottomright", -115, 9)
    _G.UIDropDownMenu_SetWidth(dropDown, 150)
    _G.UIDropDownMenu_SetText(dropDown, self:MapIdFilterDisplayName(BGFilter))

    _G.UIDropDownMenu_Initialize(dropDown, function()
        local info = _G.UIDropDownMenu_CreateInfo()
        for i=0,7 do
            info.text = BGH:MapIdFilterDisplayName(i)
            info.arg1 = i
            info.value = i
            info.checked = i == BGFilter
            info.owner = dropDown
            info.fontObject = _G.GameFontHighlight
            info.padding = 10
            info.func = FilterDropDownMenu_OnClick
            if i > 0 then
                info.icon = BGH:MapIconId(i)
            end
            _G.UIDropDownMenu_AddButton(info)
        end
    end)
    
    function FilterDropDownMenu_OnClick(self, newValue)
        BGFilter = newValue
        _G.UIDropDownMenu_SetText(dropDown, BGH:MapIdFilterDisplayName(BGFilter))
        _G.CloseDropDownMenus()
        BGH:Filter()
    end
end

function BGH:MapIdFilterDisplayName(mapID)
    local name = self:MapName(mapID)
    if not name then
        return L["All Battlegrounds"]
    end
    return name
end

function BGH:UpdateTableView()
    self:RefreshLayout()
end

function BGH:CreateHeaderButton(statsHeader, lblField, relativeWidth, localeStr, tooltipfunc)
    block = AceGUI:Create("SimpleGroup")
    block:SetRelativeWidth(relativeWidth)

    lbl = AceGUI:Create("Label")
    lbl:SetJustifyH("CENTER")
    lbl:SetFullWidth(true)
    lbl:SetText(L[localeStr])
    lbl:SetFontObject(GameFontHighlight)
    block:AddChild(lbl)

    lblField = AceGUI:Create("InteractiveLabel")
    lblField:SetJustifyH("CENTER")
    lblField:SetFullWidth(true)
    lblField:SetFontObject(GameFontHighlightLarge)
    lblField:SetText('0')
    lblField:SetCallback("OnEnter", function() self:ShowTooltip(lblField, {
        tooltipfunc(1),
        tooltipfunc(2),
        tooltipfunc(3),
        tooltipfunc(4),
    }) end)
    lblField:SetCallback("OnLeave", function() self:HideTooltip() end)
    block:AddChild(lblField)
    statsHeader:AddChild(block)
    return lblField
end

function BGH:CreateScoreButton(tableHeader, width, localeStr, sortfield)
    btn = AceGUI:Create("InteractiveLabel")
    btn:SetWidth(width)
    btn:SetText(string.format(" %s ", L[localeStr]))
    btn:SetJustifyH("LEFT")
    btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    btn:SetCallback("OnClick", function() BGH:Sort(sortfield) end)
    tableHeader:AddChild(btn)
    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)
end

function BGH:RefreshLayout()
    local buttons = _G.HybridScrollFrame_GetButtons(scrollFrame)
    local offset = _G.HybridScrollFrame_GetOffset(scrollFrame)

    f:SetStatusText(string.format(L["Recorded %i battlegrounds"], #rows))
    lblWinrate:SetText(string.format("%i/%i (%.2f%%)", stats["victories"][0], stats["count"][0], stats["winrate"][0] * 100))
    lblDuration:SetText(string.format("%s", self:HumanDuration(stats["averageRunTime"][0])))
    lblKB:SetText(string.format("%.1f", stats["averageKillingBlows"][0]))
    lblHK:SetText(string.format("%.1f", stats["averageHonorableKills"][0]))
    lblDmgDone:SetText(string.format("%.1f", stats["averageDamageDone"][0]))
    lblHlgDone:SetText(string.format("%.1f", stats["averageHealingDone"][0]))
    lblHonor:SetText(string.format("%.1f", stats["honor"][0]))

    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex]
        local itemIndex = buttonIndex + offset
        local row = rows[itemIndex]

        if (itemIndex <= #rows) then
            button:SetID(itemIndex)
            button.Icon:SetTexture(self:MapIconId(row["mapId"]))
            button.EndTime:SetText(_G.date(L["%F %T"], row["endTime"]))
            button.MapName:SetText(row["mapName"])
            button.RunTime:SetText(self:HumanDuration(row["runTime"]))
            button.BattlefieldWinner:SetTexture(132485 + row["battlefieldWinner"])
            button.KillingBlows:SetText(row["killingBlows"])
            button.Damage:SetText(row["damageDone"])
            button.Healing:SetText(row["healingDone"])
            button.HonorableKills:SetText(row["honorableKills"])
            button.Deaths:SetText(row["deaths"])
            button.Honor:SetText(row["honorGained"])

            button:SetWidth(scrollFrame.scrollChild:GetWidth())
            button:Show()
        else
            button:Hide()
        end
    end

    local buttonHeight = scrollFrame.buttonHeight
    local totalHeight = #rows * buttonHeight
    local shownHeight = #buttons * buttonHeight

    _G.HybridScrollFrame_Update(scrollFrame, totalHeight, shownHeight)
end

function BGH:Show()
    if not f then
        self:CreateGUI()
    end

    rows = BGH:BuildTable(nil, BGFilter)
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
    rows = BGH:BuildTable(column, BGFilter)
    self:RefreshLayout()
end

function BGH:Filter()
    scrollFrame:SetVerticalScroll(0)
    rows = BGH:BuildTable(nil, BGFilter)
    stats = BGH:CalcStats(rows)
    self:RefreshLayout()
end

function BGH:HumanDuration(seconds)
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
    elseif mapId == 4 then -- Eye of the Storm
        return 136032
	elseif mapId == 5 then -- Strand of the Ancients
		return 236394
	elseif mapId == 6 then -- Isle of Conquest
		return 236396
	elseif mapId == 7 then -- Wintergrasp
		return 135836
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
