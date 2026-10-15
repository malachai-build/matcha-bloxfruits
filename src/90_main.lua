-- @chunk 90_main  (lines 8508-8537 of the single-file build)
local LACED_LOAD = type(_G.__lacedLoad) == "table" and _G.__lacedLoad or nil -- load marker (loader.lua)
if LACED_LOAD and type(LACED_LOAD.started) == "table" then LACED_LOAD.started["90_main"] = true end
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state (alive is a
-- closure over this run's state since the Oct 15 stability pass).
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE

-- ---------------------------------------------------------------------------
-- Unload: the UE "Unload UI" button (and re-executing the script, which
-- unloads the previous UE copy) used to remove only the menu while every
-- automation loop and ESP drawing kept running with no way to stop them.
-- Stability pass (Oct 15 2026): shutdownScript now lives in 00_core (bound to
-- this run's state, idempotent, safe before the later chunks exist) and is
-- registered with UE right after the window is created (10_ui), so a chunk
-- that fails to load in between can no longer leave loops that the menu
-- cannot stop. Cleanup steps of the later chunks are registered with
-- onShutdown().
-- ---------------------------------------------------------------------------
SCRIPT_LIBRARY = Library

-- Load marker before the keep-alive loop (it does not end while loaded).
if LACED_LOAD and type(LACED_LOAD.done) == "table" then LACED_LOAD.done["90_main"] = true end
while alive() do task.wait(1) end
