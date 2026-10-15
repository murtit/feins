#!/usr/bin/env python3
"""Exportiert die Screenshots (XCTAttachments) aus einem .xcresult-Bundle als PNG-Dateien.

Aufruf: export-screenshots.py <Tests.xcresult> <Zielordner>
"""
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

result, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
target.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory() as raw:
    subprocess.run(
        ["xcrun", "xcresulttool", "export", "attachments", "--path", str(result), "--output-path", raw],
        check=True,
    )
    manifest = json.loads((pathlib.Path(raw) / "manifest.json").read_text())
    count = 0
    for test in manifest:
        for attachment in test.get("attachments", []):
            exported = pathlib.Path(raw) / attachment["exportedFileName"]
            if exported.suffix.lower() not in {".png", ".jpg", ".jpeg", ".heic"}:
                continue
            # suggestedHumanReadableName sieht z.B. so aus: "10-gerichte-light_0_<UUID>.png"
            name = attachment.get("suggestedHumanReadableName") or exported.name
            stem = name.rsplit(".", 1)[0].split("_", 1)[0]
            shutil.copy(exported, target / f"{stem}{exported.suffix.lower()}")
            count += 1
print(f"{count} Screenshots exportiert nach {target}")
