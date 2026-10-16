-- Diagnostic bootstrap. Keep this small: it runs before any feature code.
local SOLARA_DIAG_PATH = "laced_solara_diag.txt"
local SOLARA_DIAG_LAST = {}
pcall(function() writefile(SOLARA_DIAG_PATH, "[laced/Solara] new run\n") end)
function solaraDiag(stage, key, minInterval)
    local now = (type(os) == "table" and type(os.clock) == "function") and os.clock() or 0
    if key then
        local previous = SOLARA_DIAG_LAST[key]
        if previous and now - previous < (minInterval or 1) then return end
        SOLARA_DIAG_LAST[key] = now
    end
    local line = "[laced/Solara " .. tostring(now) .. "] " .. tostring(stage)
    pcall(print, line)
    pcall(function() appendfile(SOLARA_DIAG_PATH, line .. "\n") end)
end
solaraDiag("diagnostics ready")
