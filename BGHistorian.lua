local addonName = "BGHistorian"
local addonTitle = select(2, _G.GetAddOnInfo(addonName))
local BGH = _G.LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local libDBIcon = _G.LibStub("LibDBIcon-1.0")

function BGH:OnInitialize()
    self.db = _G.LibStub("AceDB-3.0"):New(addonName, {
        profile = {
            minimapButton = {
                hide = false,
            },
            maxHistory = 0,
        },
        char = {
            history = {},
        },
    })
    -- BGH:Print("OnInitialize")

    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    self:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
	self:RegisterEvent("CHAT_MSG_SYSTEM")

    self:DrawMinimapIcon()
    self:RegisterOptionsTable()

    self.battlegroundEnded = false
    self.sortColumn = "endTime"
    self.sortOrder = true
    self.current = {
        status = "none",
        battleFieldIndex = nil,
        stats = {},
    }
end

-- Wowpedia: Fired whenever joining a queue, leaving a queue, battlefield to join is changed, when you can join a battlefield, or if somebody wins the battleground.
-- Fired at enter BG | reload in BG | on game over | leave BG | queue BG | regularly while in queue | queue pops
function BGH:UPDATE_BATTLEFIELD_STATUS(eventName, battleFieldIndex)
    local status, mapName = _G.GetBattlefieldStatus(battleFieldIndex)
    -- status = ["queued", "confirm", "active", "none" = leave] -- active is also triggered on game over
    -- mapName = ["Alterac Valley"]
    -- instanceID = 0 queued & confirm & none / >0 active
    -- self:Print("GetBattlefieldStatus", status, mapName, instanceID, asGroup)

    if self.current["status"] == "none" and status == "active" then
        self.battlegroundEnded = false
        self.current = {
            status = "none",
            battleFieldIndex = nil,
            stats = {},
        }
        self.current["status"] = status
        self.current["battleFieldIndex"] = battleFieldIndex
        self.current["stats"]["startTime"] = _G.time()
        self.current["stats"]["honorGained"] = 0
        self.current["stats"]["mapId"] = self:MapId(mapName)
    elseif self.current["battleFieldIndex"] == battleFieldIndex and self.current["status"] == "active" and status == "none" then
        self.current["status"] = status
    end
end

-- Wowpedia: Fired whenever new battlefield score data has been recieved, this is usually fired after RequestBattlefieldScoreData is called.
-- This is pretty regular at around 1/sec (maybe linked to Capping ?)
function BGH:UPDATE_BATTLEFIELD_SCORE(eventName)
    -- Faction/team that has won the battlefield. Results are: nil if nobody has won, 0 for Horde and 1 for Alliance in a battleground
    local battlefieldWinner = _G.GetBattlefieldWinner()
    if battlefieldWinner == nil or self.battlegroundEnded then
        return
    end

    self.battlegroundEnded = true
    self:RecordBattleground()
end

-- chatMessage is either going to be one of two messages:
-- You have been awarded X honor points.
-- <Name> dies, honorable kill Rank: <rank> (X Honor Points)
function BGH:CHAT_MSG_COMBAT_HONOR_GAIN(_, chatMessage)
    local honor = self:ExtractHonorFromMessage(chatMessage)
    if honor == 0 then
        return
    end
    if self.current["stats"]["endTime"] then
        local endTime = self.current["stats"]["endTime"]
        if _G.time() - endTime > 5 then
            return
        end
    end
    -- Only attempt to record honor if we have initialized stats
    if not self.current["stats"]["honorGained"] then
        return
    end
    self.current["stats"]["honorGained"] = self.current["stats"]["honorGained"] + honor
end

function BGH:CHAT_MSG_SYSTEM(_, msg)
	local c = self.current
	if c and c.status == "active" then -- User is in a battleground
		-- TODO: This will only work on English clients
		if msg:sub(1, 18) == "You are now Away: " then
			self.battlegroundEnded = true
			self:RecordBattleground(1) -- Record a battleground loss
		end
	end
end

function BGH:ExtractHonorFromMessage(message)
    for token in string.gmatch(message, "[^%s]+") do
        local strToParse = token:gsub('%(', '')
        local honor = tonumber(strToParse)
        if not (honor == nil) then
            return honor
        end
    end

    return 0
end

-- Returns true if the specified aura id exists on the player.
function BGH:AuraExists(id)
    for i = 1, 40 do
        local aura_id = select(10, UnitAura("player", i))
        if aura_id == nil then break end
        if aura_id == id then return true end
        if id == select(10, UnitAura("player", i)) then return true end
    end
    return false
end

-- Faction of the player character domain[ 0: Horde, 1: Alliance ]
local player_faction = UnitFactionGroup("player") == "Horde" and 0 or 1

-- Returns true if the player is currently under the effects of disguised faction.
BGH.DisguisedFaction = (function()
    local disguise_id = player_faction and 81748 or 81744 -- Disguise buff IDs
    return function(self)
        return BGH:AuraExists(disguise_id) -- Check if we have the horde/alliance disguise.
    end
end)()

--[[
-- Records to the storage medium the winner of the current battleground
--
-- An override can be provided to dictate a different winner
-- @param override [number]
-- * -1->WIN, 0 DRAW, 1-> LOSS
--
-- https://wowpedia.fandom.com/wiki/API_GetBattlefieldWinner
-- _G.GetBattlefieldWinner() function returns:
-- * nil if nobody has won
-- * 0 for Horde
-- * 1 for Alliance
-- * 255 for a draw in a battleground
-- * 0 for Green Team and 1 for Yellow in an arena
--
]]--
function BGH:RecordBattleground(override)
	local winner
	if override then -- Caller is manually specifying the result
		if override == -1 then -- Win
			winner = player_faction
		elseif override == 1 then -- Loss
			winner = (player_faction + 1) % 2
		else winner = 255 end -- Draw
	else
		winner = _G.GetBattlefieldWinner()
		if winner == nil then return end -- BG is not yet over
		-- No draw occured and we have the disguised faction buff
		if (winner == 1 or winner == 0) and BGH:DisguisedFaction() then
			winner = (winner + 1) % 2 -- Flip the winner
		end
	end
	
    self.current["stats"]["battlefieldWinner"] = winner
    self.current["stats"]["endTime"] = _G.time()
    
    -- BG specific stats
    local numStatColumns = _G.GetNumBattlefieldStats()
    local numScores = _G.GetNumBattlefieldScores()
    local playerScore
    for i=1, numScores do
        name, killingBlows, honorableKills, deaths, _, _, _, _, _, _, damageDone, healingDone = _G.GetBattlefieldScore(i)
        if name == UnitName("player") then
            playerScore = {
                ["killingBlows"] = killingBlows,
                ["honorableKills"] = honorableKills,
                ["deaths"] = deaths,
                ["damageDone"] = damageDone,
                ["healingDone"] = healingDone,
            }
        end
    end
    self.current["stats"]["score"] = playerScore
    self:AddEntryToHistory(self.current["stats"])
end

function BGH:AddEntryToHistory(stats)
    if self:VerifyStats(stats) then
        table.insert(self.db.char.history, stats)

        if self.db.profile.maxHistory > 0 then
            -- Shift array until we get under threshold
            while (#self.db.char.history > self.db.profile.maxHistory) do
                table.remove(self.db.char.history, 1)
            end
        end
    end
end

function BGH:VerifyStats(stats)
    if not stats then
        return false
    end
    if not stats["mapId"] then
        return false
    end
    if not stats["endTime"] then
        return false
    end
    if not stats["battlefieldWinner"] then
        return false
    end
    if not stats["score"] then
        return false
    end
    if not stats["score"]["damageDone"] then
        return false
    end
    if not stats["score"]["deaths"] then
        return false
    end
    if not stats["score"]["killingBlows"] then
        return false
    end
    if not stats["score"]["healingDone"] then
        return false
    end
    if not stats["score"]["honorableKills"] then
        return false
    end
    if not stats["honorGained"] then
        return false
    end
    if not stats["startTime"] then
        return false
    end
    return true
end

function BGH:DrawMinimapIcon()
    libDBIcon:Register(addonName, _G.LibStub("LibDataBroker-1.1"):NewDataObject(addonName,
    {
        type = "data source",
        text = addonName,
        icon = "interface/icons/inv_misc_book_03",
        OnClick = function(self, button)
            if (button == "RightButton") then
                _G.InterfaceOptionsFrame_OpenToCategory(addonName)
                _G.InterfaceOptionsFrame_OpenToCategory(addonName)
            else
                BGH:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(string.format("%s |cff777777v%s|r", addonTitle, "0.7.6"))
            tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Left Click"], L["to open the main window"]))
            tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Right Click"], L["to open options"]))
            tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Drag"], L["to move this button"]))
        end
    }), self.db.profile.minimapButton)
end

function BGH:ToggleMinimapButton()
    self.db.profile.minimapButton.hide = not self.db.profile.minimapButton.hide
    if self.db.profile.minimapButton.hide then
        libDBIcon:Hide(addonName)
    else
        libDBIcon:Show(addonName)
    end
end

function BGH:BuildTable(sortColumn, BGFilter)
    -- self:Print("Rebuilding data table")
    local tbl = {}

    for _, row in ipairs(self.db.char.history) do
        if BGFilter > 0 then
            if BGFilter == row["mapId"] then
                local honorGained = 0
                if not (row["honorGained"] == nil) then
                    honorGained = row["honorGained"]
                end
                table.insert(tbl, {
                    ["endTime"] = row["endTime"],
                    ["mapId"] = row["mapId"],
                    ["mapName"] = self:MapName(row["mapId"]),
                    ["runTime"] = (row["endTime"] - row["startTime"]),
                    ["battlefieldWinner"] = row["battlefieldWinner"],
                    ["killingBlows"] = row["score"]["killingBlows"],
                    ["honorableKills"] = row["score"]["honorableKills"],
                    ["deaths"] = row["score"]["deaths"],
                    ["honorGained"] = honorGained,
                    ["damageDone"] = row["score"]["damageDone"],
                    ["healingDone"] = row["score"]["healingDone"],
                })
            end
        else
            local honorGained = 0
            if not (row["honorGained"] == nil) then
                honorGained = row["honorGained"]
            end
            table.insert(tbl, {
                ["endTime"] = row["endTime"],
                ["mapId"] = row["mapId"],
                ["mapName"] = self:MapName(row["mapId"]),
                ["runTime"] = (row["endTime"] - row["startTime"]),
                ["battlefieldWinner"] = row["battlefieldWinner"],
                ["killingBlows"] = row["score"]["killingBlows"],
                ["honorableKills"] = row["score"]["honorableKills"],
                ["deaths"] = row["score"]["deaths"],
                ["honorGained"] = honorGained,
                ["damageDone"] = row["score"]["damageDone"],
                ["healingDone"] = row["score"]["healingDone"],
            })
        end
    end

    if sortColumn then
        if self.sortColumn == sortColumn then
            self.sortOrder = not self.sortOrder
        else
            self.sortColumn = sortColumn
            self.sortOrder = true
        end
    end

    table.sort(tbl, function(a, b)
        if self.sortOrder then
            return a[self.sortColumn] > b[self.sortColumn]
        else
            return b[self.sortColumn] > a[self.sortColumn]
        end
    end)

    return tbl
end

local function init_tbl(indexes, value) -- Helper function
	local t = { }
	for i = 0, indexes do
		t[i] = value end
	return t
end

function BGH:CalcStats(rows)
	local NUM_BATTLEGROUNDS = 7
    local s = {
        count = init_tbl(NUM_BATTLEGROUNDS, 0),
        victories = init_tbl(NUM_BATTLEGROUNDS, 0),
        winrate = init_tbl(NUM_BATTLEGROUNDS, 0),
        runTime = init_tbl(NUM_BATTLEGROUNDS, 0),
        averageRunTime = init_tbl(NUM_BATTLEGROUNDS, 0),
        killingBlows = init_tbl(NUM_BATTLEGROUNDS, 0),
        averageKillingBlows = init_tbl(NUM_BATTLEGROUNDS, 0),
        honorableKills = init_tbl(NUM_BATTLEGROUNDS, 0),
        averageHonorableKills = init_tbl(NUM_BATTLEGROUNDS, 0),
        damageDone = init_tbl(NUM_BATTLEGROUNDS, 0),
        averageDamageDone = init_tbl(NUM_BATTLEGROUNDS, 0),
        healingDone = init_tbl(NUM_BATTLEGROUNDS, 0),
        averageHealingDone = init_tbl(NUM_BATTLEGROUNDS, 0),
        honor = init_tbl(NUM_BATTLEGROUNDS, 0),
        averageHonor = init_tbl(NUM_BATTLEGROUNDS, 0),
    }

    if #rows == 0 then
        return s
    end

    local playerFactionId = (_G.UnitFactionGroup("player") == "Alliance" and 1 or 0)
    for _, row in ipairs(rows) do
        local id = row["mapId"]
        if id > 0 then
            s["count"][id] = s["count"][id] + 1

            if row["battlefieldWinner"] == playerFactionId then
                s["victories"][id] = s["victories"][id] + 1
            end

            s["runTime"][id] = s["runTime"][id] + row["runTime"]
            s["killingBlows"][id] = s["killingBlows"][id] + row["killingBlows"]
            s["honorableKills"][id] = s["honorableKills"][id] + row["honorableKills"]
            s["damageDone"][id] = s["damageDone"][id] + row["damageDone"]
            s["healingDone"][id] = s["healingDone"][id] + row["healingDone"]
            s["honor"][id] = s["honor"][id] + row["honorGained"]
        end
    end

    -- summarize overall values
    for id = 1, NUM_BATTLEGROUNDS do
        if s["count"][id] > 0 then
            s["count"][0] = s["count"][0] + s["count"][id]
            s["victories"][0] = s["victories"][0] + s["victories"][id]
            s["runTime"][0] = s["runTime"][0] + s["runTime"][id]
            s["killingBlows"][0] = s["killingBlows"][0] + s["killingBlows"][id]
            s["honorableKills"][0] = s["honorableKills"][0] + s["honorableKills"][id]
            s["damageDone"][0] = s["damageDone"][0] + s["damageDone"][id]
            s["healingDone"][0] = s["healingDone"][0] + s["healingDone"][id]
            s["honor"][0] = s["honor"][0] + s["honor"][id]

            s["winrate"][id] = s["victories"][id] / s["count"][id]
            s["averageRunTime"][id] = s["runTime"][id] / s["count"][id]
            s["averageKillingBlows"][id] = s["killingBlows"][id] / s["count"][id]
            s["averageHonorableKills"][id] = s["honorableKills"][id] / s["count"][id]
            s["averageDamageDone"][id] = s["damageDone"][id] / s["count"][id]
            s["averageHealingDone"][id] = s["healingDone"][id] / s["count"][id]
            s["averageHonor"][id] = s["honor"][id] / s["count"][id]
        end
    end

    -- calc overall averages
    s["winrate"][0] = s["victories"][0] / s["count"][0]
    s["averageRunTime"][0] = s["runTime"][0] / s["count"][0]
    s["averageKillingBlows"][0] = s["killingBlows"][0] / s["count"][0]
    s["averageHonorableKills"][0] = s["honorableKills"][0] / s["count"][0]
    s["averageDamageDone"][0] = s["damageDone"][0] / s["count"][0]
    s["averageHealingDone"][0] = s["healingDone"][0] / s["count"][0]
    s["averageHonor"][0] = s["honor"][0] / s["count"][0]
    return s
end

function BGH:MapId(mapName) -- This ideally should just be a map
    if mapName == L["Alterac Valley"] then
        return 1
    elseif mapName == L["Warsong Gulch"] then
        return 2
    elseif mapName == L["Arathi Basin"] then
        return 3
    elseif mapName == L["Eye of the Storm"] then
        return 4
	elseif mapName == L["Strand of the Ancients"] then
		return 5
	elseif mapName == L["Isle of Conquest"] then
		return 6
	elseif mapName == L["Wintergrasp"] then
		return 7
    end

    return nil
end

function BGH:MapName(mapId)
    if mapId == 1 then
        return L["Alterac Valley"]
    elseif mapId == 2 then
        return L["Warsong Gulch"]
    elseif mapId == 3 then
        return L["Arathi Basin"]
    elseif mapId == 4 then
        return L["Eye of the Storm"]
	elseif mapId == 5 then
		return L["Strand of the Ancients"]
	elseif mapId == 6 then
		return L["Isle of Conquest"]
	elseif mapId == 7 then
		return L["Wintergrasp"]
    end

    return nil
end

function BGH:ResetDatabase()
    self.db:ResetDB()
    self:Print(L["Database reset"])
end

function BGH:OptimizeDatabase()
    local newHistory = {}
    local stats
    for i, row in ipairs(self.db.char.history) do
        if self:VerifyStats(self.db.char.history[i]) then
            table.insert(newHistory, self.db.char.history[i])
        end
    end
    self.db.char.history = newHistory
    self:Print(L["Database optimized"])
end
