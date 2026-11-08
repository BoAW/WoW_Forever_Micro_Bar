-- Art lives under a permanently hidden parent, so it stays hidden even if
-- Blizzard's code calls Show on it again later.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

local function SetArtHidden(bar, barName, artKey, hidden)
    local art = bar and bar[artKey]
    if art then
        art:SetParent(hidden and hiddenParent or bar)
    else
        print(("Mini Tweaker: %s.%s was not found."):format(barName, artKey))
    end
end

-- Same circular mask and atlases as the mainline bag buttons.
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local OVERLAY_KEYS = { "searchOverlay", "ItemContextOverlay" }

local BAG_STYLE = { normal = "bag-border", empty = "bag-border-empty", highlight = "bag-border-highlight", maskScale = 0.8 }
local REAGENT_STYLE = { normal = "bag-reagent-border", empty = "bag-reagent-border-empty", highlight = "bag-border-highlight", maskScale = 0.8 }
local BACKPACK_STYLE = { normal = "bag-main", empty = "bag-main", highlight = "bag-main-highlight", maskScale = 0.87 }
-- The key ring has no empty art of its own and always keeps a visible ring.
local KEYRING_STYLE = { normal = "bag-border", empty = "bag-border", highlight = "bag-border-highlight", maskScale = 0.8 }

local bagSlots = {}

local function CenterSquare(region, button, diameter)
    region:ClearAllPoints()
    region:SetPoint("CENTER", button, "CENTER")
    region:SetSize(diameter, diameter)
end

local function ApplyRoundArt(slot)
    local button, style = slot.button, slot.style
    local slots = ContainerFrame_GetContainerNumSlots(button:GetBagID())
    local ring = (slots and slots > 0) and style.normal or style.empty
    local diameter = math.min(button:GetSize())

    local normal, pushed, highlight = button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()
    normal:SetAtlas(ring)
    pushed:SetAtlas(ring)
    highlight:SetAtlas(style.highlight)
    button.SlotHighlightTexture:SetAtlas(style.highlight)

    CenterSquare(normal, button, diameter)
    CenterSquare(pushed, button, diameter)
    CenterSquare(highlight, button, diameter)
    CenterSquare(button.SlotHighlightTexture, button, diameter)
end

local function RestoreSquareArt(slot)
    local button = slot.button

    -- UpdateTextures adds its anchor without clearing the centred one first.
    button:GetNormalTexture():ClearAllPoints()
    button:GetPushedTexture():ClearAllPoints()
    button:UpdateTextures()

    button.SlotHighlightTexture:ClearAllPoints()
    button.SlotHighlightTexture:SetAllPoints(button)
end

local function SetSlotRound(slot, round)
    if slot.isRound == round then
        return
    end
    slot.isRound = round

    local button = slot.button
    local oldMask = round and button.SquareMask or slot.circleMask
    local newMask = round and slot.circleMask or button.SquareMask
    button.icon:RemoveMaskTexture(oldMask)
    button.icon:AddMaskTexture(newMask)

    -- Only the circle mask clips the overlays, the square mask clips just the icon.
    for _, key in ipairs(OVERLAY_KEYS) do
        if button[key] then
            if round then
                button[key]:AddMaskTexture(slot.circleMask)
            else
                button[key]:RemoveMaskTexture(slot.circleMask)
            end
        end
    end

    if round then
        ApplyRoundArt(slot)
    else
        RestoreSquareArt(slot)
    end
end

local function AddBagSlot(button, style)
    local diameter = math.min(button:GetSize())

    local circleMask = button:CreateMaskTexture()
    circleMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    circleMask:SetPoint("CENTER", button, "CENTER", -diameter / 30, diameter / 30)
    circleMask:SetSize(diameter * style.maskScale, diameter * style.maskScale)

    local slot = { button = button, style = style, circleMask = circleMask, isRound = false }
    table.insert(bagSlots, slot)

    -- Blizzard's UpdateTextures restores the square art each time it runs.
    hooksecurefunc(button, "UpdateTextures", function()
        if slot.isRound then
            ApplyRoundArt(slot)
        end
    end)
end

local function FindMissingRoundArt()
    for _, style in ipairs({ BAG_STYLE, REAGENT_STYLE, BACKPACK_STYLE }) do
        for _, atlas in ipairs({ style.normal, style.empty, style.highlight }) do
            if not C_Texture.GetAtlasInfo(atlas) then
                return atlas
            end
        end
    end
end

local function SetBagSlotsRound(round)
    local missingAtlas = round and FindMissingRoundArt()
    if missingAtlas then
        print(("Mini Tweaker: the art %s was not found, so the bag slots stay square."):format(missingAtlas))
        return
    end

    for _, slot in ipairs(bagSlots) do
        SetSlotRound(slot, round)
    end
end

-- Previews are built on demand from the real buttons' art.
local MENU_PREVIEW_SCALE = 0.65
local CHAT_CHANNEL_PREVIEW_SCALE = 1

local function CreatePreviewFrame(sourceButton, scale)
    local preview = CreateFrame("Frame", nil, hiddenParent)
    preview:SetScale(scale)
    preview:SetSize(sourceButton:GetSize())
    return preview
end

local function CopyTextureArt(target, source)
    if source:GetAtlas() then
        target:SetAtlas(source:GetAtlas())
    else
        target:SetTexture(source:GetTexture())
        target:SetTexCoord(source:GetTexCoord())
    end
end

-- A copy of the ? button with its marker.
local function CreateMenuMarkerPreview()
    local preview = CreatePreviewFrame(MainMenuMicroButton, MENU_PREVIEW_SCALE)

    local icon = preview:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    CopyTextureArt(icon, MainMenuMicroButton:GetNormalTexture())

    CreateFrame("Frame", nil, preview, "MainMenuBarMicroButtonNotificationTemplate"):Show()
    return preview
end

-- A still copy of the chat channel button. Its flash is a child frame, so copying
-- only the button's own textures leaves the flash out.
local function CreateChatChannelPreview()
    local button = ChatFrameChannelButton
    if not button then
        return CreateFrame("Frame", nil, hiddenParent)
    end

    local preview = CreatePreviewFrame(button, CHAT_CHANNEL_PREVIEW_SCALE)
    local stateTextures = {
        [button:GetPushedTexture() or false] = true,
        [button:GetHighlightTexture() or false] = true,
        [button:GetDisabledTexture() or false] = true,
    }

    local copies = {}
    for _, region in ipairs({ button:GetRegions() }) do
        if region:GetObjectType() == "Texture" and region:IsShown() and not stateTextures[region] then
            local layer, subLevel = region:GetDrawLayer()
            local copy = preview:CreateTexture(nil, layer, nil, subLevel)
            CopyTextureArt(copy, region)
            copy:SetVertexColor(region:GetVertexColor())
            copy:SetSize(region:GetSize())
            copies[region] = copy
        end
    end

    -- Second pass, because a texture can be anchored to another texture of the button.
    for region, copy in pairs(copies) do
        for i = 1, region:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = region:GetPoint(i)
            copy:SetPoint(point, copies[relativeTo] or preview, relativePoint, x, y)
        end
    end

    return preview
end

-- Remembered the first time the button is hidden, so it can be put back.
local chatChannelButtonParent

-- Quest mob markers on nameplates. The quest lines are read from the unit's tooltip
-- data, the same lines the game shows under the mob's name in its tooltip.
local QUEST_MARKER_SIZE = 18
local QUEST_MARKER_ATLAS = "QuestNormal"
local QUEST_MARKER_TEXTURE = "Interface\\GossipFrame\\AvailableQuestIcon"
local questMarkers = {}

local LINE_TYPES = Enum and Enum.TooltipDataLineType or {}

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

    local playerName = UnitName("player")
    local ownQuest = true
    for _, line in ipairs(data.lines) do
        if line.type == LINE_TYPES.QuestTitle then
            ownQuest = true
        elseif line.type == LINE_TYPES.QuestPlayer then
            ownQuest = line.leftText == playerName
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
    -- Left of the health bar, which is where the bar starts on every nameplate size.
    local unitFrame = plate.UnitFrame
    local anchor = unitFrame and (unitFrame.HealthBarsContainer or unitFrame.healthBar) or plate
    marker:ClearAllPoints()
    marker:SetPoint("RIGHT", anchor, "LEFT", -2, 0)
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

local function SetQuestMobMarkers(value)
    if value then
        questMarkerEvents:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        questMarkerEvents:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        questMarkerEvents:RegisterEvent("QUEST_LOG_UPDATE")
    else
        questMarkerEvents:UnregisterAllEvents()
    end
    UpdateAllQuestMarkers()
end

-- Suggested levels on the continent map, written inside each zone.
local ZONE_LEVEL_FONT_SIZE = 13
local zoneLevelLayer
local zoneLevelLabels = {}

-- This client reports 0 for every zone, so the classic level ranges are kept here,
-- keyed by the zone name the map gives. Cities and sanctuaries have no entry.
local ZONE_LEVELS = {
    -- Eastern Kingdoms
    ["Dun Morogh"] = { 1, 10 },
    ["Elwynn Forest"] = { 1, 10 },
    ["Tirisfal Glades"] = { 1, 10 },
    ["Loch Modan"] = { 10, 20 },
    ["Silverpine Forest"] = { 10, 20 },
    ["Westfall"] = { 10, 20 },
    ["Redridge Mountains"] = { 15, 25 },
    ["Duskwood"] = { 18, 30 },
    ["Hillsbrad Foothills"] = { 20, 30 },
    ["Wetlands"] = { 20, 30 },
    ["Alterac Mountains"] = { 30, 40 },
    ["Arathi Highlands"] = { 30, 40 },
    ["Stranglethorn Vale"] = { 30, 45 },
    ["Badlands"] = { 35, 45 },
    ["Swamp of Sorrows"] = { 35, 45 },
    ["The Hinterlands"] = { 40, 50 },
    ["Searing Gorge"] = { 43, 50 },
    ["Blasted Lands"] = { 45, 55 },
    ["Burning Steppes"] = { 50, 58 },
    ["Western Plaguelands"] = { 51, 58 },
    ["Eastern Plaguelands"] = { 53, 60 },
    ["Deadwind Pass"] = { 55, 60 },
    -- Kalimdor
    ["Durotar"] = { 1, 10 },
    ["Mulgore"] = { 1, 10 },
    ["Teldrassil"] = { 1, 10 },
    ["Darkshore"] = { 10, 20 },
    ["The Barrens"] = { 10, 25 },
    ["Stonetalon Mountains"] = { 15, 27 },
    ["Ashenvale"] = { 18, 30 },
    ["Thousand Needles"] = { 25, 35 },
    ["Desolace"] = { 30, 40 },
    ["Dustwallow Marsh"] = { 35, 45 },
    ["Feralas"] = { 40, 50 },
    ["Tanaris"] = { 40, 50 },
    ["Azshara"] = { 45, 55 },
    ["Felwood"] = { 48, 55 },
    ["Un'Goro Crater"] = { 48, 55 },
    ["Silithus"] = { 55, 60 },
    ["Winterspring"] = { 55, 60 },
}

-- The game's own levels when it has them, otherwise the list above.
local function GetZoneLevels(zone)
    local minLevel, maxLevel = 0, 0
    if C_Map.GetMapLevels then
        minLevel, maxLevel = C_Map.GetMapLevels(zone.mapID)
    end
    if minLevel and minLevel > 0 then
        return minLevel, maxLevel
    end
    local levels = ZONE_LEVELS[zone.name]
    if levels then
        return levels[1], levels[2]
    end
end

local function HideZoneLevels()
    for _, label in ipairs(zoneLevelLabels) do
        label:Hide()
    end
end

local function GetZoneLevelLabel(index)
    local label = zoneLevelLabels[index]
    if not label then
        label = zoneLevelLayer:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, ZONE_LEVEL_FONT_SIZE, "THICKOUTLINE")
        zoneLevelLabels[index] = label
    end
    return label
end

-- Each continent is sampled once in a grid, to learn which zone covers which point.
-- A zone's possible label spots are its own grid points, best first: the points
-- furthest from the zone's edges.
local ZONE_GRID_SIZE = 80
local zoneSpotsCache = {}

local function GetZoneAt(continentID, x, y)
    local info = C_Map.GetMapInfoAtPosition(continentID, x, y)
    -- A point can belong to a map below the zone; walk up to the continent's child.
    while info and info.parentMapID and info.parentMapID ~= continentID and info.parentMapID ~= 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    return info and info.parentMapID == continentID and info.mapID or false
end

local function GetZoneSpots(continentID)
    if zoneSpotsCache[continentID] then
        return zoneSpotsCache[continentID]
    end

    local size = ZONE_GRID_SIZE
    local cells = {}
    for row = 0, size - 1 do
        for col = 0, size - 1 do
            cells[row * size + col + 1] = GetZoneAt(continentID, (col + 0.5) / size, (row + 0.5) / size)
        end
    end

    local function ZoneAt(col, row)
        if col < 0 or row < 0 or col >= size or row >= size then
            return false
        end
        return cells[row * size + col + 1]
    end

    -- Distance to the zone's edge, as the shortest straight run of the zone's own
    -- points to the left, right, up or down.
    local function EdgeDistance(col, row, zoneID)
        local shortest = size
        for _, step in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
            local run = 0
            while run < shortest and ZoneAt(col + step[1] * (run + 1), row + step[2] * (run + 1)) == zoneID do
                run = run + 1
            end
            shortest = math.min(shortest, run)
        end
        return shortest
    end

    local spots = {}
    for row = 0, size - 1 do
        for col = 0, size - 1 do
            local zoneID = ZoneAt(col, row)
            if zoneID then
                spots[zoneID] = spots[zoneID] or {}
                table.insert(spots[zoneID], {
                    x = (col + 0.5) / size,
                    y = (row + 0.5) / size,
                    score = EdgeDistance(col, row, zoneID),
                })
            end
        end
    end
    for _, list in pairs(spots) do
        table.sort(list, function(a, b) return a.score > b.score end)
    end

    zoneSpotsCache[continentID] = spots
    return spots
end

local function BoxAt(x, y, width, height)
    return { left = x - width / 2, right = x + width / 2, top = y - height / 2, bottom = y + height / 2 }
end

local function OverlapsAny(box, boxes)
    for _, other in ipairs(boxes) do
        if box.left < other.right and box.right > other.left and box.top < other.bottom and box.bottom > other.top then
            return true
        end
    end
    return false
end

-- Room kept free around each city icon, in screen pixels.
local CITY_ICON_SIZE = 24
local LABEL_PADDING = 2

local function UpdateZoneLevels()
    HideZoneLevels()
    if not (zoneLevelLayer and MiniTweakerDB.zoneLevelsOnMap) then
        return
    end

    local mapID = WorldMapFrame:GetMapID()
    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    if not (mapInfo and mapInfo.mapType == Enum.UIMapType.Continent) then
        return
    end

    local width, height = zoneLevelLayer:GetSize()
    local playerLevel = UnitLevel("player")
    local spots = GetZoneSpots(mapID)
    local taken = {}
    local entries = {}

    for _, zone in ipairs(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone) or {}) do
        local minLevel, maxLevel = GetZoneLevels(zone)
        local left, right, top, bottom = C_Map.GetMapRectOnMap(zone.mapID, mapID)
        if left and not minLevel then
            -- Zones without levels are the cities; their icon sits in the middle.
            local iconSize = CITY_ICON_SIZE * UIParent:GetEffectiveScale() / zoneLevelLayer:GetEffectiveScale()
            table.insert(taken, BoxAt((left + right) / 2 * width, (top + bottom) / 2 * height, iconSize, iconSize))
        elseif left then
            local zoneSpots = spots[zone.mapID] or { { x = (left + right) / 2, y = (top + bottom) / 2 } }
            table.insert(entries, { minLevel = minLevel, maxLevel = maxLevel, spots = zoneSpots })
        end
    end

    -- Zones with the fewest spots choose first, as they have the least room.
    table.sort(entries, function(a, b) return #a.spots < #b.spots end)

    for index, entry in ipairs(entries) do
        local label = GetZoneLevelLabel(index)
        local minLevel, maxLevel = entry.minLevel, entry.maxLevel
        label:SetText(minLevel == maxLevel and tostring(minLevel) or ("%d-%d"):format(minLevel, maxLevel))
        -- The game's quest colours: yellow while the player is inside the range,
        -- orange or red below it, green or grey above it.
        local color = GetQuestDifficultyColor(math.min(math.max(playerLevel, minLevel), maxLevel))
        label:SetTextColor(color.r, color.g, color.b)

        local labelWidth = label:GetStringWidth() + LABEL_PADDING * 2
        local labelHeight = label:GetStringHeight() + LABEL_PADDING * 2
        -- The best spot that is free; if none is, the best spot anyway.
        local spot, box = entry.spots[1], nil
        for _, candidate in ipairs(entry.spots) do
            local candidateBox = BoxAt(candidate.x * width, candidate.y * height, labelWidth, labelHeight)
            if not OverlapsAny(candidateBox, taken) then
                spot, box = candidate, candidateBox
                break
            end
        end
        table.insert(taken, box or BoxAt(spot.x * width, spot.y * height, labelWidth, labelHeight))

        label:ClearAllPoints()
        label:SetPoint("CENTER", zoneLevelLayer, "TOPLEFT", spot.x * width, -spot.y * height)
        label:Show()
    end
end

local function SetupZoneLevels()
    -- The layer covers the map canvas, so it zooms and pans with the map.
    local canvas = WorldMapFrame:GetCanvas()
    zoneLevelLayer = CreateFrame("Frame", nil, canvas)
    zoneLevelLayer:SetAllPoints(canvas)
    zoneLevelLayer:SetFrameLevel(canvas:GetFrameLevel() + 1000)

    hooksecurefunc(WorldMapFrame, "OnMapChanged", UpdateZoneLevels)
    zoneLevelLayer:SetScript("OnSizeChanged", UpdateZoneLevels)
    WorldMapFrame:HookScript("OnShow", UpdateZoneLevels)
    UpdateZoneLevels()
end

local OPTIONS = {
    {
        key = "hideMicroMenuArt",
        area = "Micro menu",
        label = "Hide micro menu background",
        tooltip = "Removes the background and border behind the micro menu buttons.",
        default = true,
        apply = function(value)
            SetArtHidden(MicroMenu, "MicroMenu", "BackgroundArt", value)
            SetArtHidden(MicroMenu, "MicroMenu", "BorderArt", value)
        end,
    },
    {
        key = "hideBagBarArt",
        area = "Bag bar",
        label = "Hide bag bar background",
        tooltip = "Removes the background behind the bag slots and the lines between them.",
        default = true,
        apply = function(value)
            SetArtHidden(BagsBar, "BagsBar", "BorderArt", value)
            -- The UpdateDividers hook below reads this option and hides the lines.
            BagsBar:UpdateDividers()
        end,
    },
    {
        key = "roundBagSlots",
        area = "Bag bar",
        label = "Round bag slots",
        tooltip = "Shows the bag slots as circles with round rings instead of squares.",
        default = true,
        apply = SetBagSlotsRound,
    },
    {
        key = "hideMenuNotification",
        area = "Micro menu",
        label = "Hide marker on the ? button",
        tooltip = "Removes the small marker on the ? button that appears for new settings and unseen Edit Mode tips.",
        default = true,
        createPreview = CreateMenuMarkerPreview,
        apply = function(value)
            if value then
                MainMenuMicroButton.NotificationOverlay:Hide()
            else
                MainMenuMicroButton:UpdateNotificationIcon()
            end
        end,
    },
    {
        key = "hideChatChannelButton",
        area = "Chat",
        label = "Hide chat channel button",
        tooltip = "Removes the flashing chat channel button beside the chat window.",
        default = true,
        createPreview = CreateChatChannelPreview,
        apply = function(value)
            if not ChatFrameChannelButton then
                print("Mini Tweaker: ChatFrameChannelButton was not found.")
                return
            end
            chatChannelButtonParent = chatChannelButtonParent or ChatFrameChannelButton:GetParent()
            ChatFrameChannelButton:SetParent(value and hiddenParent or chatChannelButtonParent)
        end,
    },
    {
        -- Reads and writes the game's own CVar, so the addon keeps no copy of its own and
        -- the checkbox shows what is actually set, also after /console changes.
        key = "threatShowNumeric",
        area = "Target frame",
        cvar = true,
        label = "Show threat percentage",
        tooltip = "Shows your threat on the target frame as a percentage while you are in combat with it.",
    },
    {
        key = "questMobMarkers",
        area = "Nameplates",
        label = "Mark quest mobs",
        tooltip = "Shows a quest icon beside the nameplate of mobs you still need for one of your quests.",
        default = true,
        apply = SetQuestMobMarkers,
    },
    {
        key = "zoneLevelsOnMap",
        area = "World map",
        label = "Show zone levels",
        tooltip = "Shows the suggested levels in each zone on the continent map.",
        default = true,
        apply = function()
            UpdateZoneLevels()
        end,
    },
}

-- Each area is its own page under Mini Tweaker in the settings list, in this order.
local AREA_ORDER = { "Micro menu", "Bag bar", "Chat", "Target frame", "Nameplates", "World map" }

-- Runs after Blizzard's UpdateDividers, which shows the lines between the bag slots
-- again on every layout. Only the frames are hidden, so Blizzard's pools stay untouched.
local function HideBagDividers(bar)
    if not MiniTweakerDB.hideBagBarArt then
        return
    end
    for _, pool in ipairs({ bar.HorizontalDividersPool, bar.VerticalDividersPool }) do
        for divider in pool:EnumerateActive() do
            divider:Hide()
        end
    end
end

-- The settings list reuses its row frames, so the preview follows the option's own
-- row while it is on screen and is taken off again before the row is reused.
local function AttachPreview(initializer, createPreview)
    local preview

    hooksecurefunc(initializer, "InitFrame", function(_, row)
        preview = preview or createPreview()
        preview:SetParent(row)
        preview:ClearAllPoints()
        preview:SetPoint("LEFT", row.Checkbox, "RIGHT", 12, 0)
    end)

    hooksecurefunc(initializer, "Resetter", function()
        if preview then
            preview:SetParent(hiddenParent)
        end
    end)
end

local function RegisterSettings()
    local category = Settings.RegisterVerticalLayoutCategory("Mini Tweaker")
    -- The Mini Tweaker page itself is empty, so an area is shown in its place: the
    -- last one chosen since login or reload, or else the first.
    local firstSubcategory, lastSubcategory
    local isSubcategory = {}

    for _, area in ipairs(AREA_ORDER) do
        local subcategory = Settings.RegisterVerticalLayoutSubcategory(category, area)
        firstSubcategory = firstSubcategory or subcategory
        isSubcategory[subcategory] = true

        for _, option in ipairs(OPTIONS) do
            if option.area == area then
                if option.cvar then
                    -- A proxy setting, not RegisterCVarSetting: that one builds the setting in
                    -- the addon's own code, and Blizzard reads every setting when an action
                    -- button is clicked, so the tainted setting blocked the click.
                    local cvar = option.key
                    local defaultValue = GetCVarDefault(cvar) == "1"
                    local setting = Settings.RegisterProxySetting(subcategory, "MiniTweaker_" .. cvar,
                        Settings.VarType.Boolean, option.label, defaultValue,
                        function() return GetCVarBool(cvar) end,
                        function(value) SetCVar(cvar, value and "1" or "0") end)
                    Settings.CreateCheckbox(subcategory, setting, option.tooltip)
                else
                    local setting = Settings.RegisterAddOnSetting(subcategory, "MiniTweaker_" .. option.key, option.key,
                        MiniTweakerDB, type(option.default), option.label, option.default)
                    local initializer = Settings.CreateCheckbox(subcategory, setting, option.tooltip)
                    if option.createPreview then
                        AttachPreview(initializer, option.createPreview)
                    end
                    setting:SetValueChangedCallback(function(_, value)
                        option.apply(value)
                    end)
                end
            end
        end
    end

    Settings.RegisterAddOnCategory(category)

    local function Remember(selected)
        if isSubcategory[selected] then
            lastSubcategory = selected
        end
    end

    -- Clicking Mini Tweaker in the settings list moves on to the last chosen area.
    hooksecurefunc(SettingsPanel, "SelectCategory", function(panel, selected)
        if selected == category then
            panel:SelectCategory(lastSubcategory or firstSubcategory)
        else
            Remember(selected)
        end
    end)
    -- A click in the list may change the page without SelectCategory, so the page
    -- that is open when the window closes is remembered as well.
    if SettingsPanel.SetCurrentCategory then
        hooksecurefunc(SettingsPanel, "SetCurrentCategory", function(_, selected)
            Remember(selected)
        end)
    end
    SettingsPanel:HookScript("OnHide", function(panel)
        if panel.GetCurrentCategory then
            Remember(panel:GetCurrentCategory())
        end
    end)

    SLASH_MINITWEAKER1 = "/minitweaker"
    SLASH_MINITWEAKER2 = "/mtw"
    SlashCmdList.MINITWEAKER = function()
        Settings.OpenToCategory((lastSubcategory or firstSubcategory):GetID())
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    MiniTweakerDB = MiniTweakerDB or {}

    AddBagSlot(MainMenuBarBackpackButton, BACKPACK_STYLE)
    AddBagSlot(CharacterBag0Slot, BAG_STYLE)
    AddBagSlot(CharacterBag1Slot, BAG_STYLE)
    AddBagSlot(CharacterBag2Slot, BAG_STYLE)
    AddBagSlot(CharacterBag3Slot, BAG_STYLE)
    AddBagSlot(CharacterReagentBag0Slot, REAGENT_STYLE)
    AddBagSlot(KeyRingButton, KEYRING_STYLE)

    hooksecurefunc(BagsBar, "UpdateDividers", HideBagDividers)

    -- Blizzard shows the marker again each time it re-checks for news.
    hooksecurefunc(MainMenuMicroButton, "SetHasNotification", function(button)
        if MiniTweakerDB.hideMenuNotification then
            button.NotificationOverlay:Hide()
        end
    end)

    -- The world map is loaded on demand in some game versions.
    if WorldMapFrame then
        SetupZoneLevels()
    else
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", SetupZoneLevels)
    end

    -- Registering a setting also fills in its default value in MiniTweakerDB.
    RegisterSettings()

    for _, option in ipairs(OPTIONS) do
        -- CVar options are applied by the game itself.
        if option.apply then
            option.apply(MiniTweakerDB[option.key])
        end
    end
end)
