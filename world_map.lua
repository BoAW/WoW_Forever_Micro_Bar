local _, ns = ...

-- Suggested levels on the continent map, written inside each zone.
local ZONE_LEVEL_FONT_SIZE = 13
local zoneLevelLayer
local zoneLevelLabels = {}

-- The game's own levels when it has them, otherwise the list in data/zone_levels.lua.
local function GetZoneLevels(zone)
    local minLevel, maxLevel = 0, 0
    if C_Map.GetMapLevels then
        minLevel, maxLevel = C_Map.GetMapLevels(zone.mapID)
    end
    if minLevel and minLevel > 0 then
        return minLevel, maxLevel
    end
    local levels = ns.ZONE_LEVELS[zone.name]
    if levels then
        return levels[1], levels[2] or levels[1]
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

function ns.UpdateZoneLevels()
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

    hooksecurefunc(WorldMapFrame, "OnMapChanged", ns.UpdateZoneLevels)
    zoneLevelLayer:SetScript("OnSizeChanged", ns.UpdateZoneLevels)
    WorldMapFrame:HookScript("OnShow", ns.UpdateZoneLevels)
    ns.UpdateZoneLevels()
end

-- Known and, if chosen, undiscovered flight paths on the zone maps where the game itself does not show them
-- (C_TaxiMap.ShouldMapShowTaxiNodes is false there on this server). Built on the
-- game's own provider and pins, so icons, tooltips and map tracking stay the same.
local flightPathProvider

local function SetupFlightPaths()
    flightPathProvider = CreateFromMixins(FlightPointDataProviderMixin)

    function flightPathProvider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate("MiniTweakerFlightPointPinTemplate")
    end

    function flightPathProvider:RefreshAllData()
        self:RemoveAllData()
        local showKnown = MiniTweakerDB.knownFlightPathsOnMap
        local showUndiscovered = MiniTweakerDB.undiscoveredFlightPathsOnMap
        if not (showKnown or showUndiscovered) then
            return
        end

        local mapID = self:GetMap():GetMapID()
        local mapInfo = mapID and C_Map.GetMapInfo(mapID)
        -- Where the game shows them, its own provider already draws them.
        if not (mapInfo and mapInfo.mapType == Enum.UIMapType.Zone)
            or C_TaxiMap.ShouldMapShowTaxiNodes(mapID) then
            return
        end

        local factionGroup = UnitFactionGroup("player")
        for _, taxiNodeInfo in ipairs(C_TaxiMap.GetTaxiNodesForMap(mapID) or {}) do
            local wanted = taxiNodeInfo.isUndiscovered and showUndiscovered
                or not taxiNodeInfo.isUndiscovered and showKnown
            if wanted and self:ShouldShowTaxiNode(factionGroup, taxiNodeInfo) then
                if taxiNodeInfo.isUndiscovered then
                    -- The same tooltip text as the game's own provider gives them.
                    if taxiNodeInfo.faction == Enum.FlightPathFaction.Horde then
                        taxiNodeInfo.description = UNDISCOVERED_FACTION_FLIGHTPOINT:format(FACTION_HORDE)
                    elseif taxiNodeInfo.faction == Enum.FlightPathFaction.Alliance then
                        taxiNodeInfo.description = UNDISCOVERED_FACTION_FLIGHTPOINT:format(FACTION_ALLIANCE)
                    else
                        taxiNodeInfo.description = UNDISCOVERED_NEUTRAL_FLIGHTPOINT
                    end
                end
                self:GetMap():AcquirePin("MiniTweakerFlightPointPinTemplate", taxiNodeInfo)
            end
        end
    end

    WorldMapFrame:AddDataProvider(flightPathProvider)
end

function ns.UpdateFlightPaths()
    if flightPathProvider and flightPathProvider:GetMap() then
        flightPathProvider:RefreshAllData()
    end
end

local function SetupMap()
    SetupZoneLevels()
    SetupFlightPaths()
end

function ns.SetupWorldMap()
    -- The world map is loaded on demand in some game versions.
    if WorldMapFrame then
        SetupMap()
    else
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", SetupMap)
    end
end
