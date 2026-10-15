#!/usr/bin/env python3
"""Schreibt eine kurze Testzusammenfassung (Markdown) für den GitHub Job Summary."""
import json
import subprocess
import sys

raw = subprocess.run(
    ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", sys.argv[1], "--compact"],
    check=True, capture_output=True, text=True,
).stdout
summary = json.loads(raw)
icon = "✅" if summary.get("result") == "Passed" else "❌"
print(f"## {icon} Tests: {summary.get('result')}")
print()
print("| Gesamt | Bestanden | Fehlgeschlagen | Übersprungen |")
print("| --- | --- | --- | --- |")
print(f"| {summary.get('totalTestCount', 0)} | {summary.get('passedTests', 0)} | {summary.get('failedTests', 0)} | {summary.get('skippedTests', 0)} |")
for device in summary.get("devicesAndConfigurations", []):
    d = device.get("device", {})
    print(f"\nGerät: {d.get('deviceName', '?')} · {d.get('platform', '')} {d.get('osVersion', '')}")
failures = summary.get("testFailures", [])
if failures:
    print("\n### Fehlgeschlagen")
    for failure in failures:
        print(f"- **{failure.get('testName')}**: {failure.get('failureText', '').strip()}")
