"""Static stability checks for the chunked build (run by check.sh).

Plain-text rules that the Oct 15 2026 stability pass relies on. Nothing here
runs Luau: Matcha is not touched and no Luau runtime is installed. Each rule
prints PASS/FAIL; the exit code is the number of failed rules.

Usage: python -I tests/static_stability.py [repo root]
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent)
SRC = sorted((ROOT / "src").glob("*.lua"))
CHUNKS = ["00_core", "10_ui", "20_ui2", "30_esp", "40_combat",
          "50_farms", "60_afq", "70_misc", "80_misc2", "90_main"]


def code_lines(text):
    """Lines with --[[ ]] block comments and -- comments stripped (good
    enough: the chunks have no '--' inside string literals on the lines these
    rules look at). Block comments keep their newlines, so numbers match."""
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    for number, line in enumerate(text.split("\n"), 1):
        yield number, line.split("--", 1)[0]


failures = 0


def rule(name, problems):
    global failures
    if problems:
        failures += 1
        print("FAIL", name)
        for p in problems[:20]:
            print("   ", p)
    else:
        print("PASS", name)


texts = {f.stem: f.read_text(encoding="utf-8") for f in SRC}

rule("all ten chunks present, in loader order",
     [] if list(texts) == CHUNKS else ["found: %s" % list(texts)])

loader = (ROOT / "loader.lua").read_text(encoding="utf-8")
order = re.findall(r'"(\d\d_[a-z0-9]+)"', loader.split("local CHUNKS", 1)[1].split("}", 1)[0])
rule("loader.lua lists the same chunks", [] if order == CHUNKS else ["loader: %s" % order])

problems = []
for name, text in texts.items():
    if not text.startswith("-- @chunk " + name):
        problems.append(name + ": first line is not '-- @chunk %s'" % name)
    if 'LACED_LOAD.started["%s"] = true' % name not in text:
        problems.append(name + ": no start marker")
    if 'LACED_LOAD.done["%s"] = true' % name not in text:
        problems.append(name + ": no end marker")
rule("chunk header and load markers", problems)

problems = []
for name, text in texts.items():
    if name == "90_main":
        continue
    tail = text.rstrip().split("\n")[-1]
    if 'LACED_LOAD.done["%s"]' % name not in tail:
        problems.append(name + ": end marker is not the last statement")
main = texts.get("90_main", "")
if main.find('LACED_LOAD.done["90_main"]') > main.find("while alive() do task.wait(1) end"):
    problems.append("90_main: end marker must come before the keep-alive loop")
rule("end markers are last (90_main: before the keep-alive loop)", problems)

problems = []
for name, text in texts.items():
    if b"\r\n" in text.encode() and text.count("\r\n") != text.count("\n"):
        problems.append(name + ": mixed line endings")
for f in SRC:
    raw = f.read_bytes()
    if raw.count(b"\r\n") != raw.count(b"\n"):
        problems.append(f.name + ": not CRLF throughout (%d CRLF / %d LF)" % (raw.count(b"\r\n"), raw.count(b"\n")))
rule("every src chunk is CRLF throughout", problems)

problems = []
patterns = [
    (re.compile(r"task\.wait\(\s*\)"), "bare task.wait() (resumes ~2,400/s in Matcha)"),
    (re.compile(r"(?<![\w.])wait\(\s*\)"), "bare wait()"),
    (re.compile(r"task\.(delay|defer)\s*\("), "task.delay/task.defer never run in Matcha"),
    (re.compile(r"task\.spawn\(\s*[\w.:]+\s*,"), "task.spawn(f, args): Matcha forwards no arguments"),
    (re.compile(r":IsA\("), "Instance:IsA is always true in Matcha (use isA)"),
    (re.compile(r"(?<![\w.])error\("), "error() only prints in Matcha (use assert)"),
    (re.compile(r"memory_(read|write)|getbase\("), "no raw memory access"),
    (re.compile(r"task\.wait\(\s*0?\.0[0-9]*1\s*\)"), "sub-frame wait (task.wait(0.01)); use frameWait()"),
]
for name, text in texts.items():
    for number, line in code_lines(text):
        for pattern, why in patterns:
            if pattern.search(line):
                problems.append("%s:%d %s: %s" % (name, number, why, line.strip()))
rule("no Matcha landmines (bare waits, delay/defer, spawn args, IsA, error, memory)", problems)

problems = []
for name, text in texts.items():
    for number, line in code_lines(text):
        if '"InvokeServer"' in line and name == "00_core":
            continue
        if '"InvokeServer"' in line:
            problems.append("%s:%d %s" % (name, number, line.strip()))
core = texts.get("00_core", "")
if 'pcall(safeRemote, tag, remote, "InvokeServer"' not in core:
    problems.append("00_core: quietInvoke no longer calls safeRemote InvokeServer")
rule("every InvokeServer goes through quietInvoke (00_core)", problems)

problems = []
for need in ["function writesPaused()", "function remoteInvokePending()", "function quietInvoke(",
             "if writesPaused() then return false end", "AFQ_REMOTE_QUIET_BEFORE", "AFQ_REMOTE_QUIET_AFTER",
             'method ~= "InvokeServer" and remoteInvokePending()']:
    if need not in core:
        problems.append("00_core lacks: " + need)
if "if remoteInvokePending() then return false end" not in texts.get("40_combat", ""):
    problems.append("40_combat: BasicM1.fire does not skip while a CommF_ invoke is pending")
if "writesPaused()" not in texts.get("30_esp", ""):
    problems.append("30_esp: tweenTo does not pause in the quiet window")
dbg = texts.get("20_ui2", "")
for key in ["quietAccept=true", "remoteAcceptOff=false"]:
    if key not in dbg:
        problems.append("20_ui2: AFQ_DEBUG lacks " + key)
rule("remote quiet window, serialisation and A/B switches wired", problems)

problems = []
if "function alive()\n        return not state.unloaded" not in core:
    problems.append("00_core: alive() is not a closure over the run's own state")
if "return not SCRIPT_STATE.unloaded" in core:
    problems.append("00_core: alive() still reads the global SCRIPT_STATE")
for name, text in texts.items():
    if name == "00_core":
        continue
    if "local alive = alive" not in text:
        problems.append(name + ": no 'local alive = alive'")
    if "\nlocal S = S\n" not in text and name != "90_main":
        problems.append(name + ": no 'local S = S'")
if "Library:OnUnload(function() shutdownScript(\"ui\") end)" not in texts.get("10_ui", ""):
    problems.append("10_ui: the unload hook is not registered right after the window")
if "local shutdownScript = shutdownScript" not in texts.get("10_ui", ""):
    problems.append("10_ui: the unload hook does not use this run's shutdownScript")
if "OnUnload(" in main:
    problems.append("90_main: still registers an OnUnload hook (registered twice)")
if "if state.shutdownStarted then return end" not in core:
    problems.append("00_core: shutdownScript is not idempotent")
rule("per-run binding: alive/S/shutdown and a single early unload hook", problems)

problems = []
for need in ["pcall(fn)", "LOAD.started[name]", "LOAD.done[name]", "cleanupThisLoad()", "assert(false, message)",
             "superseded()", 'pcall(own, "loader")', "before.shutdown", "before.ue"]:
    if need not in loader:
        problems.append("loader.lua lacks: " + need)
if re.search(r"^\s*fn\(\)\s*$", loader, re.M):
    problems.append("loader.lua: a chunk is still called without pcall")
rule("loader: pcall, markers, cleanup of its own run only", problems)

afq = texts.get("60_afq", "")
problems = []
body = afq.split("function afq_waitTrackerFor", 1)[1].split("\nend\n", 1)[0] if "function afq_waitTrackerFor" in afq else ""
if "if not afq_farming() then return false end" not in body:
    problems.append("afq_waitTrackerFor can report success after the farm stopped")
if 'return state=="same" or state=="unknown"' in body:
    problems.append("afq_waitTrackerFor still treats any unknown tracker as success")
if "task.wait(0.1)" in body:
    problems.append("afq_waitTrackerFor still polls at 10 Hz")
ab = afq.split("function afq_abandon()", 1)[1].split("\nend\n", 1)[0] if "function afq_abandon()" in afq else ""
first = [l.strip() for l in ab.split("\n") if l.strip()][:1]
if first and first[0].startswith("AFQ.current=nil"):
    problems.append("afq_abandon still wipes the quest state before the remote")
if "afq_clearHeld()\n    return true\nend" not in afq:
    problems.append("afq_abandon does not clear the state only after the tracker is gone")
for need in ["AFQ_REMOTE_MIN_INTERVAL", "afl_questRemoteWait", "afq_acceptWait", "adoptIfShown",
             "AFQ.stepGen==AFQ.gen", "afq_trackerGone", "afq_acceptByDialogue", "AFQ_DEBUG.remoteAcceptOff"]:
    if need not in afq:
        problems.append("60_afq lacks: " + need)
rule("Auto Farm Quest remote/quest-state hardening", problems)

misc2 = texts.get("80_misc2", "")
problems = []
for need in ["AUTO_STAT_CONFIRM_SECS", "resolvePending()", "next(pending)~=nil", "pcall(pass)"]:
    if need not in misc2:
        problems.append("80_misc2 lacks: " + need)
if "clock()-p.t>5 then pending[name]=nil" in misc2:
    problems.append("Auto Stat still forgets a pending spend after 5 s")
rule("Auto Stat confirmation and no blind re-spend", problems)

print("%d rule(s) failed" % failures)
sys.exit(failures)
