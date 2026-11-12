local _, ns = ...

local MENU_PREVIEW_SCALE = 0.65

-- A copy of a micro menu button with its marker.
local function CreateMarkerPreview(button)
    local preview = ns.CreatePreviewFrame(button, MENU_PREVIEW_SCALE)

    local icon = preview:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    ns.CopyTextureArt(icon, button:GetNormalTexture())

    CreateFrame("Frame", nil, preview, "MainMenuBarMicroButtonNotificationTemplate"):Show()
    return preview
end

function ns.CreateMenuMarkerPreview()
    return CreateMarkerPreview(MainMenuMicroButton)
end

function ns.CreateShopMarkerPreview()
    return CreateMarkerPreview(StoreMicroButton)
end

function ns.SetMenuNotificationHidden(hidden)
    if hidden then
        MainMenuMicroButton.NotificationOverlay:Hide()
    else
        MainMenuMicroButton:UpdateNotificationIcon()
    end
end

function ns.SetShopNotificationHidden(hidden)
    -- Same check as Blizzard's StoreMicroButtonMixin:UpdateMicroButton, without calling
    -- that function, which also enables and disables the other micro buttons.
    StoreMicroButton.NotificationOverlay:SetShown(not hidden and C_CatalogShop.HasNewProducts())
end

function ns.SetupMicroMenu()
    -- Blizzard shows the marker again each time it re-checks for news.
    hooksecurefunc(MainMenuMicroButton, "SetHasNotification", function(button)
        if MiniTweakerDB.hideMenuNotification then
            button.NotificationOverlay:Hide()
        end
    end)

    -- The shop button shows its marker for new products each time it is updated.
    hooksecurefunc(StoreMicroButton, "UpdateMicroButton", function(button)
        if MiniTweakerDB.hideShopNotification then
            button.NotificationOverlay:Hide()
        end
    end)
end
