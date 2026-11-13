#!/usr/bin/env python3
"""Dependency routing and the always-running required CI result."""
import argparse
import json
import os
from pathlib import Path
import subprocess

JOBS = ("android", "exchange", "ios")


def route(paths, full=False):
    selected = {name: full for name in JOBS}
    for path in paths:
        if path.startswith("docs/") or ("/" not in path and path.endswith(".md")):
            continue
        if path.startswith(("RequiemCharacterSheet/Views/", "RequiemCharacterSheet/App/", "RequiemCharacterSheet/Assets.xcassets/", "Chronicles/UI/", "RequiemCharacterSheetUITests/")):
            selected["ios"] = True
        elif path.startswith("android/"):
            selected.update(android=True, exchange=True)
        elif path == "Package.swift" or path.startswith(("RequiemCharacterSheet/Models/", "RequiemCharacterSheet/Persistence/", "Chronicles/Core/", "RequiemCharacterSheetTests/")):
            selected.update(ios=True, exchange=True)
        else:
            # Shared inputs, Xcode/build configuration and unknown paths run everything.
            selected = dict.fromkeys(JOBS, True)
    return selected


def aggregate(needs):
    if needs.get("policy", {}).get("result") != "success":
        raise ValueError("Change detection/shared validation did not succeed")
    selected = json.loads(needs["policy"]["outputs"]["selection"])
    if set(selected) != set(JOBS) or any(type(v) is not bool for v in selected.values()):
        raise ValueError("Invalid or missing job selection")
    for name, required in selected.items():
        result = needs.get(name, {}).get("result")
        if result != "success" and not (not required and result == "skipped"):
            raise ValueError(f"{name}: expected {'success' if required else 'success or deliberate skip'}, got {result}")
    return "Selected checks passed" if any(selected.values()) else "Documentation/metadata change: no platform build required"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["route", "aggregate"])
    parser.add_argument("--base")
    parser.add_argument("--full", action="store_true")
    args = parser.parse_args()
    if args.command == "aggregate":
        print(aggregate(json.loads(os.environ["CI_NEEDS"])))
        return
    if not args.full and not args.base:
        raise ValueError("PR routing needs a base commit")
    paths = [] if args.full else subprocess.check_output(["git", "diff", "--name-only", "-z", f"{args.base}...HEAD"]).decode().split("\0")
    selected = route([p for p in paths if p], args.full)
    result = json.dumps(selected, separators=(",", ":"))
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write("selection=" + result + "\n")
            for job, enabled in selected.items(): output.write(f"{job}={str(enabled).lower()}\n")
    print(result)


if __name__ == "__main__":
    main()
