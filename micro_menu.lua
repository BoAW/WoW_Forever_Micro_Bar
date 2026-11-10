local _, ns = ...

local MENU_PREVIEW_SCALE = 0.65

-- A copy of the ? button with its marker.
function ns.CreateMenuMarkerPreview()
    local preview = ns.CreatePreviewFrame(MainMenuMicroButton, MENU_PREVIEW_SCALE)

    local icon = preview:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    ns.CopyTextureArt(icon, MainMenuMicroButton:GetNormalTexture())

    CreateFrame("Frame", nil, preview, "MainMenuBarMicroButtonNotificationTemplate"):Show()
    return preview
end

function ns.SetMenuNotificationHidden(hidden)
    if hidden then
        MainMenuMicroButton.NotificationOverlay:Hide()
    else
        MainMenuMicroButton:UpdateNotificationIcon()
    end
end

function ns.SetupMicroMenu()
    -- Blizzard shows the marker again each time it re-checks for news.
    hooksecurefunc(MainMenuMicroButton, "SetHasNotification", function(button)
        if MiniTweakerDB.hideMenuNotification then
            button.NotificationOverlay:Hide()
        end
    end)
end
