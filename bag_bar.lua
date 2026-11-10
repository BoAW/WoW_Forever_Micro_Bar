local _, ns = ...

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

function ns.SetBagSlotsRound(round)
    local missingAtlas = round and FindMissingRoundArt()
    if missingAtlas then
        print(("Mini Tweaker: the art %s was not found, so the bag slots stay square."):format(missingAtlas))
        return
    end

    for _, slot in ipairs(bagSlots) do
        SetSlotRound(slot, round)
    end
end

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

function ns.SetupBagBar()
    AddBagSlot(MainMenuBarBackpackButton, BACKPACK_STYLE)
    AddBagSlot(CharacterBag0Slot, BAG_STYLE)
    AddBagSlot(CharacterBag1Slot, BAG_STYLE)
    AddBagSlot(CharacterBag2Slot, BAG_STYLE)
    AddBagSlot(CharacterBag3Slot, BAG_STYLE)
    AddBagSlot(CharacterReagentBag0Slot, REAGENT_STYLE)
    AddBagSlot(KeyRingButton, KEYRING_STYLE)

    hooksecurefunc(BagsBar, "UpdateDividers", HideBagDividers)
end
