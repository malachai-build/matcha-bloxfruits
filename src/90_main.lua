-- @chunk 90_main  (lines 8508-8537 of the single-file build)
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state.
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE

-- ---------------------------------------------------------------------------
-- Unload: the UE "Unload UI" button (and re-executing the script, which
-- unloads the previous UE copy) used to remove only the menu while every
-- automation loop and ESP drawing kept running with no way to stop them.
-- ---------------------------------------------------------------------------
SCRIPT_LIBRARY = Library
function shutdownScript()
    if SCRIPT_STATE.unloaded then return end
    -- Turn every feature toggle off through its own callback first, so each
    -- feature runs its normal "off" path (clears ESP, releases mouse, ...).
    -- Only while S is still this execution's table: during a re-run the
    -- callbacks would write into the new copy's S.
    if S == SCRIPT_STATE then
        for _, control in pairs(SCRIPT_LIBRARY.Controls or {}) do
            if type(control)=="table" and control.Type=="Toggle" and control.Value==true then
                pcall(function() control:SetValue(false) end)
            end
        end
    end
    SCRIPT_STATE.unloaded=true
    S.boatTweening=false
    S.boatTween=nil
    pcall(clearEspLabels); pcall(clearChamBoxes); pcall(clearChestEspLabels)
    pcall(clearBerryEspLabels); pcall(clearBoatEsp); pcall(clearFlowerEsp); pcall(clearMirageEsp)
    pcall(mouse1release)
end
Library:OnUnload(shutdownScript)

while alive() do task.wait(1) end
