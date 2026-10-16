-- laced.club Blox Fruits menu for Solara: local diagnostic loader.
-- Reads laced_solara/src/ from Solara's workspace, one chunk at a time.
--
-- Usage: copy src/ into Solara's workspace as laced_solara/src/, then run
-- this small loader in Solara.
--
-- Solara loadstring returns nil and an error on compilation failure. Chunk
-- execution can yield, and each chunk must return after setting its end marker.
--
-- Each chunk records start/end markers. A failed download, compile, execution,
-- or marker check unloads only the state and menu created by this load.

-- Persist checkpoints even if Roblox or Solara closes before showing output.
local SOLARA_DIAG_PATH = "laced_solara_diag.txt"
local SOLARA_DIAG_LAST = {}
pcall(function() writefile(SOLARA_DIAG_PATH, "[laced/Solara] new local run\n") end)
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
solaraDiag("local loader entered")

local ENV = type(getgenv) == "function" and getgenv() or _G
local BASE = "laced_solara/src/"
local CHUNKS = {
    "00_core", "10_ui", "20_ui2", "30_esp", "40_combat",
    "50_farms", "60_afq", "70_misc", "80_misc2", "90_main",
}
local CHUNK_TIMEOUT = 30 -- s a chunk that yielded may take to reach its end marker
local clock = (type(os) == "table" and type(os.clock) == "function") and os.clock or tick

local function fetch(path)
    local body = ""
    local ok, res = pcall(function() return readfile(path) end)
    if ok and type(res) == "string" then body = res end
    return body
end

-- This load's marker table. A newer load replaces ENV.__lacedLoad; this one
-- then stops before its next chunk instead of running it against the newer
-- load's globals.
local LOAD = { started = {}, done = {}, failed = nil, shutdown = nil, state = nil }
ENV.__lacedLoad = LOAD

-- What existed before this load, so the cleanup only touches what this load
-- created (a previous copy of the script may still be running).
local before = {
    shutdown = shutdownScript,
    state = SCRIPT_STATE,
    ue = ENV.UELibrary,
}

local function cleanupThisLoad()
    -- shutdownScript is defined early in 00_core; once 00_core has run it is
    -- this load's own and does everything (idempotent).
    local own = LOAD.shutdown
    if type(own) ~= "function" and type(shutdownScript) == "function" and shutdownScript ~= before.shutdown then
        own = shutdownScript
    end
    if type(own) == "function" then
        pcall(own, "loader")
        return
    end
    local state = LOAD.state or SCRIPT_STATE
    if type(state) == "table" and state ~= before.state then state.unloaded = true end
    if type(mouse1release) == "function" then pcall(mouse1release) end
    local ue = ENV.UELibrary
    if type(ue) == "table" and ue ~= before.ue and not ue._unloaded and type(ue.Unload) == "function" then
        pcall(function() ue:Unload() end)
    end
end

local function fail(name, index, reason)
    LOAD.failed = name
    local message = "[laced.club] chunk " .. name .. " (" .. index .. "/" .. #CHUNKS .. ") failed: " .. tostring(reason)
    solaraDiag("FAILED " .. message)
    if type(warn) == "function" then warn(message .. " - unloading what this load started") end
    cleanupThisLoad()
    if ENV.__lacedLoad == LOAD then ENV.__lacedLoad = nil end
    assert(false, message)
end

local function superseded()
    return ENV.__lacedLoad ~= LOAD
        or (type(LOAD.state) == "table" and LOAD.state.unloaded == true)
end

for index, name in ipairs(CHUNKS) do
    if superseded() then
        fail(name, index, "a newer load (or an unload) took over before this chunk")
    end
    local url = BASE .. name .. ".lua"
    solaraDiag("chunk " .. name .. " fetch begin")
    local src = fetch(url)
    solaraDiag("chunk " .. name .. " fetched bytes=" .. tostring(#src))
    local marker = "-- @chunk " .. name
    -- Only the START of the body is checked for an error page: the chunks
    -- themselves legitimately contain the strings "<html" / "<!DOCTYPE" (the
    -- UE download validator in 10_ui), which is why a whole-body search
    -- rejected a good download.
    local head = string.sub(src, 1, 256)
    local looksHtml = string.find(head, "<html", 1, true) or string.find(head, "<!DOCTYPE", 1, true)
    if not (#src > 100 and not looksHtml and string.sub(src, 1, #marker) == marker) then
        local preview = string.gsub(string.sub(src, 1, 80), "%s+", " ")
        fail(name, index, "read from " .. url .. " was rejected (got " .. #src .. " bytes: " .. preview .. ")")
    end
    -- The end marker must be in the body too: a truncated download that kept
    -- its first line would otherwise run half a chunk.
    if not string.find(src, 'LACED_LOAD.done["' .. name .. '"]', 1, true) then
        fail(name, index, "download is truncated (no end marker)")
    end
    if superseded() then
        fail(name, index, "a newer load (or an unload) took over during the download")
    end
    local fn, compileError = loadstring(src, "laced.solara." .. name)
    if type(fn) ~= "function" then fail(name, index, "did not compile: " .. tostring(compileError)) end
    solaraDiag("chunk " .. name .. " compiled")
    if type(warn) == "function" and name ~= "90_main" then
        warn(("[laced.club] loading %s (%d/%d, %d bytes)"):format(name, index, #CHUNKS, #src))
    end
    LOAD.started[name] = nil
    LOAD.done[name] = nil
    -- 90_main starts its keep-alive loop in a separate task, then returns.
    solaraDiag("chunk " .. name .. " execution begin")
    local okRun, runError = pcall(fn)
    if not okRun then fail(name, index, "runtime error: " .. tostring(runError)) end
    if not LOAD.started[name] and not LOAD.done[name] then
        fail(name, index, "never started (syntax error? see the console line printed above)")
    end
    local deadline = clock() + CHUNK_TIMEOUT
    while not LOAD.done[name] and clock() < deadline do task.wait(0.05) end
    if not LOAD.done[name] then
        fail(name, index, "did not finish within " .. CHUNK_TIMEOUT .. " s (runtime error after a yield?)")
    end
    solaraDiag("chunk " .. name .. " execution end")
    if name == "00_core" then
        -- This load's own run: its shutdown and state, for the cleanup.
        LOAD.shutdown = shutdownScript
        LOAD.state = SCRIPT_STATE
    end
end
if ENV.__lacedLoad == LOAD and type(warn) == "function" then
    warn("[laced.club] all " .. #CHUNKS .. " chunks loaded")
end
solaraDiag("all chunks loaded")
