local _, ns = ...

-- Suggested levels for each zone. This client reports 0 for every zone, so the classic
-- level ranges are kept here, keyed by the zone name the map gives. Cities and
-- sanctuaries have no entry. A zone with one number has the same lowest and highest level.
ns.ZONE_LEVELS = {
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
    ["Mount Hyjal"] = { 60 },
}
