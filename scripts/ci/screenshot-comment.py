#!/usr/bin/env python3
"""Baut den Markdown-Kommentar mit den Screenshots einer PR.

Aufruf: screenshot-comment.py <Ordner> <Basis-URL> <Commit> <Testergebnis>
"""
import pathlib
import sys

folder, base, sha, result = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
files = sorted(p.name for p in folder.glob("*.png"))


def img(name: str, width: int = 220) -> str:
    return f'<img src="{base}/{name}?raw=true" width="{width}" alt="{name}">'


def title(stem: str) -> str:
    return stem.split("-", 1)[1].replace("-", " ").capitalize() if "-" in stem else stem


status = "✅ Alle Tests grün" if result == "success" else f"⚠️ Tests: {result}"
lines = [
    "<!-- feins-screenshots -->",
    f"### 📸 Screenshots aus dem iOS-Simulator ({sha})",
    "",
    f"{status}. Automatisch erzeugt von den UI-Tests auf einem GitHub macOS-Runner.",
    "",
]

paired = {}
singles = []
for name in files:
    stem = name.rsplit(".", 1)[0]
    if stem.endswith("-light") or stem.endswith("-dark"):
        key, mode = stem.rsplit("-", 1)
        paired.setdefault(key, {})[mode] = name
    else:
        singles.append(name)

if paired:
    lines += ["| Screen | Hell | Dunkel |", "| --- | --- | --- |"]
    for key in sorted(paired):
        modes = paired[key]
        light = img(modes["light"]) if "light" in modes else ""
        dark = img(modes["dark"]) if "dark" in modes else ""
        lines.append(f"| {title(key)} | {light} | {dark} |")
    lines.append("")

if singles:
    lines += ["**Abläufe**", ""]
    for start in range(0, len(singles), 4):
        row = singles[start:start + 4]
        lines += ["| " + " | ".join(title(n.rsplit('.', 1)[0]) for n in row) + " |",
                  "| " + " | ".join("---" for _ in row) + " |",
                  "| " + " | ".join(img(n, 180) for n in row) + " |", ""]

if not files:
    lines.append("_Keine Screenshots vorhanden._")

print("\n".join(lines))
