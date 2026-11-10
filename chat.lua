local _, ns = ...

local CHAT_CHANNEL_PREVIEW_SCALE = 1

-- A still copy of the chat channel button. Its flash is a child frame, so copying
-- only the button's own textures leaves the flash out.
function ns.CreateChatChannelPreview()
    local button = ChatFrameChannelButton
    if not button then
        return CreateFrame("Frame", nil, ns.hiddenParent)
    end

    local preview = ns.CreatePreviewFrame(button, CHAT_CHANNEL_PREVIEW_SCALE)
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
            ns.CopyTextureArt(copy, region)
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

function ns.SetChatChannelButtonHidden(hidden)
    if not ChatFrameChannelButton then
        print("Mini Tweaker: ChatFrameChannelButton was not found.")
        return
    end
    chatChannelButtonParent = chatChannelButtonParent or ChatFrameChannelButton:GetParent()
    ChatFrameChannelButton:SetParent(hidden and ns.hiddenParent or chatChannelButtonParent)
end
