#!/usr/bin/env bash
# Gibt die UDID eines iPhone-Simulators mit der neuesten iOS-Runtime aus.
# Bevorzugt SIMULATOR_NAME (Standard: "iPhone 17 Pro").
set -euo pipefail

preferred="${SIMULATOR_NAME:-iPhone 17 Pro}"
xcrun simctl list devices available --json | python3 -c '
import json, sys, re
preferred = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
def version(runtime):
    m = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?", runtime)
    return tuple(int(x or 0) for x in m.groups()) if m else None
runtimes = sorted((v, r) for r in devices if (v := version(r)))
if not runtimes:
    sys.exit("Keine iOS-Runtime gefunden")
for v, runtime in reversed(runtimes):
    phones = [d for d in devices[runtime] if d["name"].startswith("iPhone")]
    if not phones:
        continue
    match = next((d for d in phones if d["name"] == preferred), phones[0])
    print(match["udid"])
    print(match["name"] + " / iOS " + ".".join(map(str, v)), file=sys.stderr)
    break
' "$preferred"
