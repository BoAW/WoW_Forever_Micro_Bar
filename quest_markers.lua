local _, ns = ...

-- Quest mob markers on nameplates. The quest lines are read from the unit's tooltip
-- data, the same lines the game shows under the mob's name in its tooltip.
local QUEST_MARKER_SIZE = 18
local QUEST_MARKER_ATLAS = "QuestNormal"
local QUEST_MARKER_TEXTURE = "Interface\\GossipFrame\\AvailableQuestIcon"
local questMarkers = {}

local LINE_TYPES = Enum and Enum.TooltipDataLineType or {}

-- Characters can have a surname. The tooltip writes "First Surname" with a space; a name
-- that holds the surname separator is brought to that form.
local SURNAME_SEPARATOR = Constants and Constants.CharacterNameSeparatorConsts
    and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR

local function NormalizeName(name)
    name = (name or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if SURNAME_SEPARATOR and SURNAME_SEPARATOR ~= "" then
        name = name:gsub((SURNAME_SEPARATOR:gsub("%p", "%%%0")), " ")
    end
    return strtrim(name)
end

-- True when a quest player line in a tooltip names the player.
local function IsPlayerQuestLine(text, playerName, playerFirstName)
    text = NormalizeName(text)
    if text == playerName then
        return true
    end
    -- UnitName can give the first name alone while the tooltip adds the surname,
    -- so the first names are compared as well.
    return (text:match("^(%S+)") or text) == playerFirstName
end

-- True when the unit's tooltip has an objective of the player's own that is not done yet.
-- In a group the tooltip also lists other players' quests under their name; those
-- objectives are skipped.
local function HasOpenQuestObjective(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then
        return false
    end
    local data = C_TooltipInfo.GetUnit(unit)
    if not (data and data.lines) then
        return false
    end

    local playerName = NormalizeName(UnitName("player"))
    local playerFirstName = playerName:match("^(%S+)") or playerName
    local ownQuest = true
    for _, line in ipairs(data.lines) do
        if line.type == LINE_TYPES.QuestTitle then
            ownQuest = true
        elseif line.type == LINE_TYPES.QuestPlayer then
            ownQuest = IsPlayerQuestLine(line.leftText, playerName, playerFirstName)
        elseif line.type == LINE_TYPES.QuestObjective and ownQuest then
            if line.completed == nil then
                -- Without the flag, a "3/9" count tells whether it is done.
                local have, need = (line.leftText or ""):match("(%d+)/(%d+)")
                if not have or tonumber(have) < tonumber(need) then
                    return true
                end
            elseif not line.completed then
                return true
            end
        end
    end
    return false
end

local function GetQuestMarker(plate)
    local marker = questMarkers[plate]
    if not marker then
        marker = CreateFrame("Frame", nil, plate)
        marker:SetSize(QUEST_MARKER_SIZE, QUEST_MARKER_SIZE)
        local icon = marker:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        if C_Texture.GetAtlasInfo(QUEST_MARKER_ATLAS) then
            icon:SetAtlas(QUEST_MARKER_ATLAS)
        else
            icon:SetTexture(QUEST_MARKER_TEXTURE)
        end
        questMarkers[plate] = marker
    end
    return marker
end

-- Left of the health bar, which is where the bar starts on every nameplate size. When the
-- elite/rare icon is shown there, the marker goes left of that icon so it is not covered.
local function PlaceQuestMarker(plate, marker)
    local unitFrame = plate.UnitFrame
    local classification = unitFrame and unitFrame.ClassificationFrame
    local anchor
    if classification and classification:IsShown() then
        anchor = classification
    else
        anchor = unitFrame and (unitFrame.HealthBarsContainer or unitFrame.healthBar) or plate
    end
    marker:ClearAllPoints()
    marker:SetPoint("RIGHT", anchor, "LEFT", -2, 0)

    -- The icon can be shown or hidden after the marker is placed, so the marker follows it.
    if classification and not marker.followsClassification then
        marker.followsClassification = true
        local function Replace()
            if marker:IsShown() then
                PlaceQuestMarker(plate, marker)
            end
        end
        classification:HookScript("OnShow", Replace)
        classification:HookScript("OnHide", Replace)
    end
end

local function UpdateQuestMarker(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then
        return
    end

    local show = MiniTweakerDB.questMobMarkers and not UnitIsPlayer(unit) and HasOpenQuestObjective(unit)
    if not show then
        if questMarkers[plate] then
            questMarkers[plate]:Hide()
        end
        return
    end

    local marker = GetQuestMarker(plate)
    PlaceQuestMarker(plate, marker)
    marker:Show()
end

local function UpdateAllQuestMarkers()
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then
            UpdateQuestMarker(unit)
        elseif questMarkers[plate] then
            questMarkers[plate]:Hide()
        end
    end
end

local questMarkerEvents = CreateFrame("Frame")
questMarkerEvents:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        UpdateQuestMarker(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and questMarkers[plate] then
            questMarkers[plate]:Hide()
        end
    else
        -- The quest log changed: objectives may be done or new quests taken.
        UpdateAllQuestMarkers()
    end
end)

function ns.SetQuestMobMarkers(value)
    if value then
        questMarkerEvents:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        questMarkerEvents:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        questMarkerEvents:RegisterEvent("QUEST_LOG_UPDATE")
    else
        questMarkerEvents:UnregisterAllEvents()
    end
    UpdateAllQuestMarkers()
end
