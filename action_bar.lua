local _, ns = ...

-- The gryphons at the ends of the main action bar.
function ns.SetGryphonHidden(capKey, hidden)
    local endCaps = MainActionBar and MainActionBar.EndCaps
    if not endCaps then
        print("Mini Tweaker: MainActionBar.EndCaps was not found.")
        return
    end
    ns.SetArtHidden(endCaps[capKey], "MainActionBar.EndCaps." .. capKey, "Texture", hidden)
end
