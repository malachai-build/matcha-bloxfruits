"""Build the paste-ready Solara script from the separate Solara chunks."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent
CHUNKS = (
    "00_core", "10_ui", "20_ui2", "30_esp", "40_combat",
    "50_farms", "60_afq", "70_misc", "80_misc2", "90_main",
)

header = "-- laced.club Blox Fruits, Solara single-file build.\n"
diagnostics = (ROOT / "diagnostics.lua").read_text(encoding="utf-8")
sections = []
for name in CHUNKS:
    source = (ROOT / "src" / f"{name}.lua").read_text(encoding="utf-8")
    sections.append(f'solaraDiag("chunk {name} begin")\n' + source + f'\nsolaraDiag("chunk {name} end")')
body = "\n\n".join(sections)
(ROOT / "full.lua").write_text(header + diagnostics + "\n" + body + "\n", encoding="utf-8", newline="\n")
