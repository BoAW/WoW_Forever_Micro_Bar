-- Shared helpers for the other files. Every file of the addon gets the same table as its
-- second argument, so functions put in it here can be used there.
local _, ns = ...

-- Art lives under a permanently hidden parent, so it stays hidden even if
-- Blizzard's code calls Show on it again later.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
ns.hiddenParent = hiddenParent

function ns.SetArtHidden(bar, barName, artKey, hidden)
    local art = bar and bar[artKey]
    if art then
        art:SetParent(hidden and hiddenParent or bar)
    else
        print(("Mini Tweaker: %s.%s was not found."):format(barName, artKey))
    end
end

-- Previews in the settings are built on demand from the real buttons' art.
function ns.CreatePreviewFrame(sourceButton, scale)
    local preview = CreateFrame("Frame", nil, hiddenParent)
    preview:SetScale(scale)
    preview:SetSize(sourceButton:GetSize())
    return preview
end

function ns.CopyTextureArt(target, source)
    if source:GetAtlas() then
        target:SetAtlas(source:GetAtlas())
    else
        target:SetTexture(source:GetTexture())
        target:SetTexCoord(source:GetTexCoord())
    end
end
