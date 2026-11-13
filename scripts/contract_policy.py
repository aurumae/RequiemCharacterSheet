#!/usr/bin/env python3
"""Validate declared support, shared data and PR regressions; select one exchange plan.

No network or third-party packages. A declared gap is permitted only when it cannot
discard save data or silently replace an already-supported rule.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = "shared/fixtures/contracts.json"
CATALOG = "shared/catalog-contract.json"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read(root, path):
    return json.loads((root / path).read_text())


def test_reference(root, ref):
    require(set(ref) == {"file", "name"}, f"Invalid test reference: {ref}")
    path = root / ref["file"]
    require(path.is_file() and re.search(r"\b(?:fun|func)\s+" + re.escape(ref["name"]) + r"\s*\(", path.read_text()),
            f"Missing capability test: {ref}")


def supported(scenario, platform):
    return (scenario["schema"] is None or scenario["schema"] <= platform["readSchema"]) and set(scenario["requires"]) <= set(platform["capabilities"])


def select(manifest, strict=False):
    platforms = manifest["platforms"]
    pending = {p: v["pending"] for p, v in platforms.items() if v["pending"]}
    require(not strict or not pending, f"Strict parity has pending capabilities: {pending}")
    selected = [name for name, s in manifest["scenarios"].items()
                if s["roles"] and all(supported(s, p) for p in platforms.values())]
    excluded = [name for name, s in manifest["scenarios"].items() if s["roles"] and name not in selected]
    require(not strict or not excluded, f"Strict parity has unexercised scenarios: {excluded}")
    kinds = set.intersection(*(set(p["catalogKinds"]) for p in platforms.values()))
    return {"scenarios": selected, "catalogKinds": sorted(kinds), "pending": pending, "unexercised": excluded,
            "reject": {p: [name for name, s in manifest["scenarios"].items()
                            if name.startswith("characters/") and s["schema"] > v["readSchema"]]
                       for p, v in platforms.items()}}


def validate_manifest(root, m):
    require(m["format"] == 1 and set(m["platforms"]) == {"ios", "android"}, "Unknown contract manifest format/platform")
    capabilities = set(m["capabilities"])
    require(set(m["saveFields"].values()) <= capabilities, "Unknown save-field capability")
    for p, v in m["platforms"].items():
        declared = set(v["capabilities"])
        require(len(v["capabilities"]) == len(declared), f"Duplicate {p} capability")
        require(declared <= capabilities and set(v["pending"]) == capabilities - declared, f"Unclassified {p} capabilities")
        require(len(v["catalogKinds"]) == len(set(v["catalogKinds"])), f"Duplicate {p} catalog kind")
        for cap in declared:
            test_reference(root, m["capabilities"][cap]["tests"][p])
        for cap, gap in v["pending"].items():
            require(bool(gap.get("owner")) and bool(gap.get("handoff")), f"{p}/{cap} needs an owner and handoff")
            handoff = gap["handoff"].split("#")[0]
            require((root / handoff).is_file(), f"Missing handoff: {handoff}")
        require(v["readSchema"] >= max(v["writers"].values()), f"{p} writes unreadable saves")
    kotlin = next(root.glob("android/*/src/main/kotlin/ie/requiem/rules/CharacterSave.kt"))
    swift = root / "RequiemCharacterSheet/Models/Character.swift"
    for p, text, pattern in [("android", kotlin.read_text(), r"CURRENT_SCHEMA\s*=\s*(\d+)"),
                             ("ios", swift.read_text(), r"currentSchemaVersion\s*=\s*(\d+)")]:
        require(int(re.search(pattern, text)[1]) == m["platforms"][p]["readSchema"], f"{p} decoder disagrees with manifest")
    kotlin_catalog = next(root.glob("android/*/src/main/kotlin/ie/requiem/rules/Catalog.kt")).read_text()
    kotlin_kinds = re.search(r"enum class CatalogKind\s*\{([^}]+)", kotlin_catalog)[1]
    swift_kinds = re.findall(r"let (\w+): CatalogIndex<", (root / "RequiemCharacterSheet/Models/Catalog.swift").read_text())
    require(set(re.findall(r"\w+", kotlin_kinds)) == set(m["platforms"]["android"]["catalogKinds"]), "Android catalog declarations disagree")
    require(set(swift_kinds) == set(m["platforms"]["ios"]["catalogKinds"]), "iOS catalog declarations disagree")
    files = {str(p.relative_to(root / "shared/fixtures")) for p in (root / "shared/fixtures").rglob("*.json") if p.name != "contracts.json"}
    require(files == {p for p in m["scenarios"] if p.endswith(".json")}, "Every fixture/action file must be classified")
    for path, s in m["scenarios"].items():
        require(set(s["requires"]) <= capabilities, f"Unknown requirements: {path}")
        require(set(s["roles"]) <= {"current", "historical", "transfer", "action", "generated"}, f"Unknown scenario role: {path}")
        if path.startswith("characters/"):
            data = read(root, "shared/fixtures/" + path)
            require(data.get("schemaVersion", 1) == s["schema"], f"Wrong schema metadata: {path}")
            if "current" in s["roles"]:
                def fields(value, field=""):
                    if field:
                        require(field in m["saveFields"], f"Unclassified save field: {path}/{field}")
                        require(m["saveFields"][field] in s["requires"], f"Missing capability for {path}/{field}")
                        for p, v in m["platforms"].items():
                            require(s["schema"] > v["readSchema"] or m["saveFields"][field] in v["capabilities"],
                                    f"{p} would accept unsupported save state {path}/{field}; raise its required schema")
                    if isinstance(value, dict):
                        for k, v in value.items():
                            key = "*" if field == "paidDots" or field.startswith("paidDots.") or field in ("creation.attributePriorities", "creation.skillPriorities") else k
                            fields(v, f"{field}.{key}" if field else key)
                    elif isinstance(value, list):
                        for v in value: fields(v, field + ".[]")
                fields(data)
        if s["roles"]:
            require(any(supported(s, p) for p in m["platforms"].values()), f"No platform tests {path}")


def value_type(value):
    if value is None: return "null"
    if isinstance(value, bool): return "boolean"
    if isinstance(value, dict): return "object"
    if isinstance(value, list): return "array"
    if isinstance(value, (int, float)): return "number"
    return "string"


def validate_catalogs(root, manifest, contract):
    fields = contract["fields"]
    capabilities = manifest["capabilities"]
    def classified(cap, path):
        require(cap in capabilities, f"Unclassified catalog field: {path}")
        for p, v in manifest["platforms"].items():
            if cap not in v["capabilities"]:
                fallback = capabilities[cap].get("fallbacks", {}).get(p)
                require(fallback and fallback.get("behavior") == "advisory-text", f"{p}/{path} needs a tested safe fallback")
                test_reference(root, fallback["test"])
    for path, declaration in fields.items(): classified(declaration["capability"], path)
    for path, values in contract["enumCapabilities"].items():
        for value, cap in values.items(): classified(cap, f"{path}={value}")
    def walk(value, path=""):
        if path:
            require(path in fields, f"Unclassified catalog field: {path}")
            require(value_type(value) in fields[path]["types"], f"Invalid catalog type: {path}")
        if isinstance(value, dict):
            for k, v in value.items(): walk(v, f"{path}.{k}" if path else k)
        elif isinstance(value, list):
            for v in value: walk(v, path + ".[]")
        elif path in contract["enumCapabilities"]:
            enums = contract["enumCapabilities"][path]
            require(str(value) in enums, f"Unclassified rule value: {path}={value}")
            require(enums[str(value)] in capabilities, f"Unknown rule capability: {path}={value}")
    files = sorted((root / "RequiemCharacterSheet/Catalogs").glob("*.json"), key=lambda p: (p.name != "vtr2e-core.json", p.name))
    require(files and files[0].name == "vtr2e-core.json", "Missing Requiem core catalog")
    books, entries = {}, {}
    kinds = set().union(*(set(v["catalogKinds"]) for v in manifest["platforms"].values()))
    for f in files:
        data = json.loads(f.read_text())
        require(data.get("format") == "requiem-catalog" and data.get("version") == 1, f"Invalid catalog format: {f.name}")
        walk(data)
        book = data["book"]
        require(book["id"] not in books and book["name"].strip(), f"Duplicate/empty book: {f.name}")
        books[book["id"]] = book["name"]
        require(set(data) <= {"format", "version", "book"} | kinds, f"Unknown catalog category: {f.name}")
        for kind in kinds:
            seen = set()
            for e in data.get(kind, []):
                require(e.get("id") and e.get("name") and (e.get("summary") or (kind == "archetypes" and e.get("singleWillpower") and e.get("allWillpower"))), f"Incomplete entry: {f.name}/{kind}")
                require(e["id"] not in seen, f"Duplicate entry in {f.name}: {kind}/{e['id']}")
                seen.add(e["id"])
                require(isinstance(e.get("source"), dict), f"Missing citation: {e['id']}")
                page = e["source"].get("page")
                require(page is None or (type(page) is int and page > 0), f"Invalid page: {e['id']}")
                entries.setdefault(kind, {}).setdefault(e["id"], e)  # first/core wins, like both apps
    def reference(kind, value, where):
        require(value in entries.get(kind, {}), f"Unknown {kind} reference {value}: {where}")
    prerequisite_kinds = {"clan":"clans", "bloodline":"bloodlines", "covenant":"covenants", "notCovenant":"covenants", "merit":"merits", "discipline":"disciplines"}
    for kind, group in entries.items():
        for id, e in group.items():
            require(e["source"]["book"] in books, f"Unknown source book: {id}")
            for key, target in {"discipline":"disciplines", "mystery":"mysteries", "partOfMystery":"mysteries", "clan":"clans", "bloodline":"bloodlines", "requiredCovenant":"covenants", "statusCountsAs":"covenants"}.items():
                if key in e and not (kind == "scales" and key == "mystery" and e[key] == "any" and e.get("anyCoil", 0) > 0): reference(target, e[key], id)
            for key, target in {"disciplines":"disciplines", "parentClans":"clans", "teaches":"disciplines"}.items():
                for value in e.get(key, []): reference(target, value, id)
            for rule in e.get("prerequisites", []) + [p for group in e.get("prerequisitesAnyOf", []) for p in group]:
                if rule["kind"] in prerequisite_kinds: reference(prerequisite_kinds[rule["kind"]], rule["id"], id)
            for rule in e.get("meritAccess", []) + e.get("meritGroups", []):
                reference("clans" if "meritAccess" in e else "covenants", rule["inPlaceOf"], id)
                for merit in rule.get("merits", []): reference("merits", merit, id)
            for coil in e.get("prerequisiteCoils", []): reference("mysteries", coil["mystery"], id)
            if "ritualRules" in e: reference("covenants", e["ritualRules"]["covenant"], id)
    return {"books": list(books), **{k: list(entries.get(k, {})) for k in kinds}}


def check_base(root, base, m, catalog):
    def git(*args): return subprocess.check_output(["git", "-C", str(root), *args])
    paths = git("ls-tree", "-r", "--name-only", base, "shared/fixtures").decode().splitlines()
    for path in paths:
        if path != MANIFEST and path.endswith(".json"):
            require((root / path).is_file() and (root / path).read_bytes() == git("show", f"{base}:{path}"), f"Historical fixture changed: {path}; add a versioned example")
    if MANIFEST not in paths: return  # first adoption still protects historical fixtures
    old = json.loads(git("show", f"{base}:{MANIFEST}"))
    for p, v in old["platforms"].items():
        new = m["platforms"][p]
        require(v["readSchema"] <= new["readSchema"], f"{p} dropped readable schema support")
        for key in ("capabilities", "catalogKinds"):
            require(set(v[key]) <= set(new[key]), f"{p} removed promised {key}")
        require(v["writers"].items() <= new["writers"].items(), f"{p} changed an existing conditional writer")
    for path, scenario in old["scenarios"].items():
        require(m["scenarios"].get(path) == scenario, f"Scenario coverage changed: {path}; add a versioned scenario")
    require(old["saveFields"].items() <= m["saveFields"].items(), "Existing save-field coverage changed")
    for cap, definition in old["capabilities"].items():
        for p in old["platforms"]:
            if cap in old["platforms"][p]["capabilities"]:
                require(definition["tests"][p]["name"] == m["capabilities"][cap]["tests"][p]["name"], f"Removed capability test: {p}/{cap}")
    old_catalog = json.loads(git("show", f"{base}:{CATALOG}"))
    for path, declaration in old_catalog["fields"].items():
        require(catalog["fields"].get(path) == declaration, f"Existing catalog contract changed: {path}")
    for path, values in old_catalog["enumCapabilities"].items():
        require(values.items() <= catalog["enumCapabilities"].get(path, {}).items(), f"Existing rule classification changed: {path}")


def evidence(root, manifest, platform, reports):
    passed = set()
    for path in reports:
        for test in ET.parse(path).getroot().iter("testcase"):
            if not any(test.find(tag) is not None for tag in ("failure", "error", "skipped")):
                passed.add(test.get("name", "").split("(")[0])
    require(passed, f"No executed {platform} tests in evidence")
    expected = {manifest["capabilities"][cap]["tests"][platform]["name"] for cap in manifest["platforms"][platform]["capabilities"]}
    expected |= {"declarationsMatchActualReaderAndConditionalWriters", "everyNewerScenarioIsRejectedWithoutChangingStorage"}
    for cap in manifest["platforms"][platform]["pending"]:
        fallback = manifest["capabilities"][cap].get("fallbacks", {}).get(platform)
        if fallback: expected.add(fallback["test"]["name"])
    require(expected <= passed, f"Supported {platform} capabilities lack passing tests: {sorted(expected - passed)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--base")
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--evidence", choices=["ios", "android"])
    parser.add_argument("--reports", nargs="*", type=Path, default=[])
    args = parser.parse_args()
    m, catalog = read(args.root, MANIFEST), read(args.root, CATALOG)
    validate_manifest(args.root, m)
    inventory = validate_catalogs(args.root, m, catalog)
    if args.base: check_base(args.root, args.base, m, catalog)
    plan = select(m, args.strict)
    if args.evidence: evidence(args.root, m, args.evidence, args.reports)
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
        (args.output / "inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
        lines = ["# Compatibility report", "", f"Selected {len(plan['scenarios'])} shared scenarios and {len(plan['catalogKinds'])} catalog categories.", ""]
        for p, v in m["platforms"].items():
            lines.append(f"- {p}: reads schemas 1–{v['readSchema']}; {len(v['capabilities'])} supported capabilities; {len(v['pending'])} pending.")
            for cap, gap in v["pending"].items(): lines.append(f"  - {cap}: {gap['owner']} · [{gap['handoff']}]({gap['handoff']})")
        lines += ["", "Not exercised in bidirectional exchange: " + (", ".join(plan["unexercised"]) or "none"), "",
                  "Each platform must also pass safe rejection of newer saves and its complete local supported suite.",
                  "This report describes automated contract coverage, not physical-device or visual acceptance."]
        (args.output / "summary.md").write_text("\n".join(lines) + "\n")
    print(f"Contract policy passed: {len(inventory['books'])} books, {len(plan['scenarios'])} shared scenarios, {sum(len(x) for x in plan['pending'].values())} pending capabilities")


if __name__ == "__main__":
    try: main()
    except (ValueError, KeyError, StopIteration, json.JSONDecodeError) as error:
        print(f"Contract policy failed: {error}", file=sys.stderr)
        sys.exit(1)
