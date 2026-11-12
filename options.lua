local _, ns = ...

-- Shown at the top of the Mini Tweaker page itself.
local DESCRIPTION = "Mini Tweaker makes small changes to the default interface. It can hide art you do not "
    .. "need, show the bag slots as circles, mark the mobs you still need for a quest and write the "
    .. "suggested levels on the world map. Each page under Mini Tweaker in the list holds the options "
    .. "for one part of the screen."

-- Every option of the addon. The functions they call live in the file for their area.
-- An option without an area is shown on the Mini Tweaker page itself, under its heading.
local OPTIONS = {
    {
        key = "showMinimapButton",
        heading = "Minimap",
        label = "Show minimap button",
        tooltip = "Shows a button on the edge of the minimap that opens these options. Drag it to move it.",
        default = true,
        apply = ns.SetMinimapButtonShown,
    },
    {
        key = "hideLeftGryphon",
        area = "Action bar",
        label = "Hide left gryphon",
        tooltip = "Removes the gryphon at the left end of the main action bar.",
        default = false,
        apply = function(value)
            ns.SetGryphonHidden("LeftEndCap", value)
        end,
    },
    {
        key = "hideRightGryphon",
        area = "Action bar",
        label = "Hide right gryphon",
        tooltip = "Removes the gryphon at the right end of the main action bar.",
        default = false,
        apply = function(value)
            ns.SetGryphonHidden("RightEndCap", value)
        end,
    },
    {
        key = "hideMicroMenuArt",
        area = "Micro menu",
        label = "Hide micro menu background",
        tooltip = "Removes the background and border behind the micro menu buttons.",
        default = true,
        apply = function(value)
            ns.SetArtHidden(MicroMenu, "MicroMenu", "BackgroundArt", value)
            ns.SetArtHidden(MicroMenu, "MicroMenu", "BorderArt", value)
        end,
    },
    {
        key = "hideBagBarArt",
        area = "Bag bar",
        label = "Hide bag bar background",
        tooltip = "Removes the background behind the bag slots and the lines between them.",
        default = true,
        apply = function(value)
            ns.SetArtHidden(BagsBar, "BagsBar", "BorderArt", value)
            -- The UpdateDividers hook in bag_bar.lua reads this option and hides the lines.
            BagsBar:UpdateDividers()
        end,
    },
    {
        key = "roundBagSlots",
        area = "Bag bar",
        label = "Round bag slots",
        tooltip = "Shows the bag slots as circles with round rings instead of squares.",
        default = true,
        apply = ns.SetBagSlotsRound,
    },
    {
        key = "hideMenuNotification",
        area = "Micro menu",
        label = "Hide marker on the ? button",
        tooltip = "Removes the small marker on the ? button that appears for new settings and unseen Edit Mode tips.",
        default = true,
        createPreview = ns.CreateMenuMarkerPreview,
        apply = ns.SetMenuNotificationHidden,
    },
    {
        key = "hideShopNotification",
        area = "Micro menu",
        label = "Hide marker on the shop button",
        tooltip = "Removes the small marker on the shop button that appears when the shop has new products.",
        default = true,
        createPreview = ns.CreateShopMarkerPreview,
        apply = ns.SetShopNotificationHidden,
    },
    {
        key = "hideChatChannelButton",
        area = "Chat",
        label = "Hide chat channel button",
        tooltip = "Removes the flashing chat channel button beside the chat window.",
        default = true,
        createPreview = ns.CreateChatChannelPreview,
        apply = ns.SetChatChannelButtonHidden,
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
        key = "sellJunkWithoutConfirmation",
        area = "Merchant",
        label = "Sell junk without asking",
        tooltip = "Sells all junk items at once when you click Sell All Junk Items, without the Yes/No question.",
        default = true,
        apply = ns.SetSellJunkWithoutConfirmation,
    },
    {
        key = "questMobMarkers",
        area = "Nameplates",
        label = "Mark quest mobs",
        tooltip = "Shows a quest icon beside the nameplate of mobs you still need for one of your quests.",
        default = true,
        apply = ns.SetQuestMobMarkers,
    },
    {
        key = "zoneLevelsOnMap",
        area = "World map",
        label = "Show zone levels",
        tooltip = "Shows the suggested levels in each zone on the continent map.",
        default = true,
        apply = function()
            ns.UpdateZoneLevels()
        end,
    },
    {
        key = "knownFlightPathsOnMap",
        area = "World map",
        label = "Show known flight paths",
        tooltip = "Shows the flight paths you know on the zone maps.",
        default = true,
        apply = function()
            ns.UpdateFlightPaths()
        end,
    },
    {
        key = "undiscoveredFlightPathsOnMap",
        area = "World map",
        label = "Show undiscovered flight paths",
        tooltip = "Shows the flight paths you have not found yet on the zone maps.",
        default = false,
        apply = function()
            ns.UpdateFlightPaths()
        end,
    },
}

-- Each area is its own page under Mini Tweaker in the settings list, in alphabetical order.
local function GetAreas()
    local areas, seen = {}, {}
    for _, option in ipairs(OPTIONS) do
        if option.area and not seen[option.area] then
            seen[option.area] = true
            table.insert(areas, option.area)
        end
    end
    table.sort(areas)
    return areas
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
            preview:SetParent(ns.hiddenParent)
        end
    end)
end

local function AddCheckbox(category, option)
    if option.cvar then
        -- A proxy setting, not RegisterCVarSetting: that one builds the setting in
        -- the addon's own code, and Blizzard reads every setting when an action
        -- button is clicked, so the tainted setting blocked the click.
        local cvar = option.key
        local defaultValue = GetCVarDefault(cvar) == "1"
        local setting = Settings.RegisterProxySetting(category, "MiniTweaker_" .. cvar,
            Settings.VarType.Boolean, option.label, defaultValue,
            function() return GetCVarBool(cvar) end,
            function(value) SetCVar(cvar, value and "1" or "0") end)
        Settings.CreateCheckbox(category, setting, option.tooltip)
    else
        local setting = Settings.RegisterAddOnSetting(category, "MiniTweaker_" .. option.key, option.key,
            MiniTweakerDB, type(option.default), option.label, option.default)
        local initializer = Settings.CreateCheckbox(category, setting, option.tooltip)
        if option.createPreview then
            AttachPreview(initializer, option.createPreview)
        end
        setting:SetValueChangedCallback(function(_, value)
            option.apply(value)
        end)
    end
end

-- A row of wrapping text, built on the template in templates.xml.
local function CreateTextInitializer(text)
    local initializer = Settings.CreateElementInitializer("MiniTweakerSettingsTextTemplate", {})
    hooksecurefunc(initializer, "InitFrame", function(_, frame)
        frame.Text:SetText(text)
    end)
    return initializer
end

local function RegisterSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("Mini Tweaker")

    -- The Mini Tweaker page: the description, then the options that have no area.
    layout:AddInitializer(CreateTextInitializer(DESCRIPTION))
    for _, option in ipairs(OPTIONS) do
        if not option.area then
            if option.heading then
                layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(option.heading))
            end
            AddCheckbox(category, option)
        end
    end

    -- The area each Mini Tweaker page belongs to; the Mini Tweaker page itself has none.
    local pageAreas = { [category] = false }
    local pagesByArea = {}

    for _, area in ipairs(GetAreas()) do
        local subcategory = Settings.RegisterVerticalLayoutSubcategory(category, area)
        pageAreas[subcategory] = area
        pagesByArea[area] = subcategory
        for _, option in ipairs(OPTIONS) do
            if option.area == area then
                AddCheckbox(subcategory, option)
            end
        end
    end

    Settings.RegisterAddOnCategory(category)

    -- Remember the last Mini Tweaker page chosen, also across reloads, so the
    -- minimap button and /mtw open it again instead of the Mini Tweaker page.
    EventRegistry:RegisterCallback("Settings.CategoryChanged", function(_, changedCategory)
        local area = pageAreas[changedCategory]
        if area ~= nil then
            MiniTweakerDB.lastSettingsPage = area or nil
        end
    end, pageAreas)

    function ns.OpenSettings()
        local page = pagesByArea[MiniTweakerDB.lastSettingsPage] or category
        Settings.OpenToCategory(page:GetID())
    end

    SLASH_MINITWEAKER1 = "/minitweaker"
    SLASH_MINITWEAKER2 = "/mtw"
    SlashCmdList.MINITWEAKER = ns.OpenSettings
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    MiniTweakerDB = MiniTweakerDB or {}

    ns.SetupBagBar()
    ns.SetupMicroMenu()
    ns.SetupWorldMap()
    ns.SetupMerchant()

    -- Registering a setting also fills in its default value in MiniTweakerDB.
    RegisterSettings()

    for _, option in ipairs(OPTIONS) do
        -- CVar options are applied by the game itself.
        if option.apply then
            option.apply(MiniTweakerDB[option.key])
        end
    end
end)
