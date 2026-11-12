local _, ns = ...

local sellJunkWithoutConfirmation = false

-- The game's own click shows a Yes/No popup and only sells when Yes is clicked.
-- The popup uses the shared GENERIC_CONFIRMATION, so it cannot be answered by name
-- without risking other confirmations; the click itself is replaced instead.
function ns.SetupMerchant()
    local button = MerchantSellAllJunkButton
    if not button or not (C_MerchantFrame and C_MerchantFrame.SellAllJunkItems) then
        print("Mini Tweaker: the sell all junk button was not found.")
        return
    end

    local originalOnClick = button:GetScript("OnClick")
    button:SetScript("OnClick", function(...)
        if sellJunkWithoutConfirmation then
            GameTooltip:Hide()
            C_MerchantFrame.SellAllJunkItems()
        elseif originalOnClick then
            originalOnClick(...)
        end
    end)
end

function ns.SetSellJunkWithoutConfirmation(value)
    sellJunkWithoutConfirmation = value
end
