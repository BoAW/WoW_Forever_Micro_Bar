local _, ns = ...

-- A round button on the edge of the minimap that opens the options. It can be dragged
-- along the edge; its place is kept as an angle around the minimap's centre.
local ICON = "Interface\\Icons\\INV_Misc_Wrench_01"
local DEFAULT_ANGLE = 225
-- How far outside the minimap's edge the button's centre sits.
local EDGE_OFFSET = 10

local button

local function PlaceButton()
    local angle = math.rad(MiniTweakerDB.minimapButtonAngle or DEFAULT_ANGLE)
    local radius = Minimap:GetWidth() / 2 + EDGE_OFFSET
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging, the button follows the cursor's direction from the minimap's centre.
local function FollowCursor()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
    MiniTweakerDB.minimapButtonAngle = angle % 360
    PlaceButton()
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Mini Tweaker")
    GameTooltip:AddLine("Click to open the options.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move the button around the minimap.", 1, 1, 1)
    GameTooltip:Show()
end

-- Same layout as the game's own round minimap buttons: icon, dark background and ring.
local function CreateButton()
    button = CreateFrame("Button", "MiniTweakerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function()
        ns.OpenSettings()
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    PlaceButton()
end

function ns.SetMinimapButtonShown(shown)
    if not button then
        CreateButton()
    end
    button:SetShown(shown)
end
