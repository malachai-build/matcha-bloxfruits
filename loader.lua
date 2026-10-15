-- laced.club Blox Fruits menu for Matcha: chunked loader.
-- Fetches the chunks in src/ one at a time and runs them in order, so the VM
-- compiles ten chunks of 30-1,400 lines instead of one 8,500-line chunk.
--
-- Usage (one line):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/loader.lua"))()
-- Override the base URL (dev/mirror) before running:
--   _G.LACED_BASE = "https://example.com/mybuild/src/"
--
-- Matcha notes: loadstring never returns nil (a syntax error only surfaces when
-- the chunk runs), top-level return values are dropped, and httpget/game:HttpGet
-- return "" or an error page on failure, so every body is validated first.

local BASE = _G.LACED_BASE or "https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/src/"
local CHUNKS = {
    "00_core", "10_ui", "20_ui2", "30_esp", "40_combat",
    "50_farms", "60_afq", "70_misc", "80_misc2", "90_main",
}

local function fetch(url)
    local body = ""
    if type(httpget) == "function" then
        local ok, res = pcall(httpget, url)
        if ok and type(res) == "string" then body = res end
    end
    if body == "" then
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and type(res) == "string" then body = res end
    end
    return body
end

local t0 = (type(tick) == "function") and tick() or 0
for index, name in ipairs(CHUNKS) do
    local url = BASE .. name .. ".lua"
    local src = fetch(url)
    local marker = "-- @chunk " .. name
    -- Only the START of the body is checked for an error page: the chunks
    -- themselves legitimately contain the strings "<html" / "<!DOCTYPE" (the
    -- UE download validator in 10_ui), which is why a whole-body search
    -- rejected a good download.
    local head = string.sub(src, 1, 256)
    local looksHtml = string.find(head, "<html", 1, true) or string.find(head, "<!DOCTYPE", 1, true)
    assert(#src > 100 and not looksHtml and string.sub(src, 1, #marker) == marker,
        "[laced.club] chunk " .. name .. " (" .. index .. "/" .. #CHUNKS .. ") failed to download from " .. url
        .. " (got " .. #src .. " bytes)")
    local fn = loadstring(src, "laced." .. name)
    assert(type(fn) == "function", "[laced.club] chunk " .. name .. " did not compile")
    if type(warn) == "function" and name ~= "90_main" then
        warn(("[laced.club] loaded %s (%d/%d, %d bytes)"):format(name, index, #CHUNKS, #src))
    end
    -- 90_main ends with the keep-alive loop and does not return while the
    -- script is loaded, exactly like the single-file build.
    fn()
end
