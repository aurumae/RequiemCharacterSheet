import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import ci_policy as ci
import contract_policy as policy


class RoutingTests(unittest.TestCase):
    def test_routing_tracks_dependencies(self):
        cases = {
            "docs/handoff.md": set(), "AGENTS.md": set(),
            "RequiemCharacterSheet/Views/Sheet.swift": {"ios"},
            "Chronicles/UI/Dots.swift": {"ios"},
            "Chronicles/Core/Merit.swift": {"ios", "exchange"},
            "RequiemCharacterSheet/Persistence/CharacterStore.swift": {"ios", "exchange"},
            "RequiemCharacterSheetTests/SaveContractTests.swift": {"ios", "exchange"},
            "android/app/src/main/Main.kt": {"android", "exchange"},
            "shared/fixtures/contracts.json": set(ci.JOBS),
            "RequiemCharacterSheet/Catalogs/new-book.json": set(ci.JOBS),
            "RequiemCharacterSheet/Fonts/font.ttf": set(ci.JOBS),
            ".github/workflows/save-contract.yml": set(ci.JOBS),
            "scripts/contract_policy.py": set(ci.JOBS), "unknown": set(ci.JOBS),
        }
        for path, expected in cases.items():
            with self.subTest(path=path):
                self.assertEqual(expected, {k for k, v in ci.route([path]).items() if v})
        self.assertTrue(all(ci.route([], full=True).values()))

    def needs(self, selected):
        return {"policy": {"result": "success", "outputs": {"selection": json.dumps(selected)}},
                **{name: {"result": "success" if value else "skipped"} for name, value in selected.items()}}

    def test_aggregate_accepts_only_explicit_skips(self):
        selected = ci.route(["docs/handoff.md"])
        self.assertIn("no platform build", ci.aggregate(self.needs(selected)))
        selected = ci.route(["android/app/Example.kt"])
        self.assertEqual("Selected checks passed", ci.aggregate(self.needs(selected)))
        for result in ["skipped", "failure", "cancelled", None]:
            needs = self.needs(selected); needs["exchange"]["result"] = result
            with self.assertRaises(ValueError): ci.aggregate(needs)

    def test_routing_failure_and_missing_outputs_cannot_pass(self):
        needs = self.needs(ci.route([], full=True))
        needs["policy"]["result"] = "failure"
        with self.assertRaises(ValueError): ci.aggregate(needs)
        needs = self.needs(ci.route([], full=True)); needs["policy"]["outputs"]["selection"] = '{}'
        with self.assertRaises(ValueError): ci.aggregate(needs)


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.m = policy.read(policy.ROOT, policy.MANIFEST)
        self.catalog = policy.read(policy.ROOT, policy.CATALOG)

    def test_current_contract_is_strict_and_fully_classified(self):
        policy.validate_manifest(policy.ROOT, self.m)
        policy.validate_catalogs(policy.ROOT, self.m, self.catalog)
        self.assertFalse(policy.select(self.m, True)["pending"])

    def test_ios_first_schema_is_selected_locally_and_refused_by_older_android(self):
        cap = "save.example-13"
        self.m["capabilities"][cap] = {"tests": {}}
        self.m["platforms"]["ios"]["readSchema"] = 13
        self.m["platforms"]["ios"]["capabilities"].append(cap)
        self.m["platforms"]["android"]["pending"][cap] = {"owner": "Android", "handoff": "docs/handoff.md"}
        path = "characters/v13-example.json"
        self.m["scenarios"][path] = {"schema": 13, "requires": [cap], "roles": ["current", "transfer"]}
        plan = policy.select(self.m)
        self.assertNotIn(path, plan["scenarios"])
        self.assertIn(path, plan["reject"]["android"])
        self.assertIn(path, plan["unexercised"])
        self.assertTrue(policy.supported(self.m["scenarios"][path], self.m["platforms"]["ios"]))
        with self.assertRaises(ValueError): policy.select(self.m, True)
        self.m["platforms"]["android"]["readSchema"] = 13
        self.m["platforms"]["android"]["capabilities"].append(cap)
        self.m["platforms"]["android"]["pending"].clear()
        self.assertIn(path, policy.select(self.m, True)["scenarios"])

    def test_false_capability_or_missing_tests_fail(self):
        self.m["platforms"]["android"]["readSchema"] += 1
        with self.assertRaisesRegex(ValueError, "decoder disagrees"): policy.validate_manifest(policy.ROOT, self.m)
        self.setUp()
        self.m["capabilities"]["rules.core"]["tests"]["android"]["name"] = "doesNotExist"
        with self.assertRaisesRegex(ValueError, "Missing capability test"): policy.validate_manifest(policy.ROOT, self.m)

    def test_unsupported_live_mechanic_needs_a_tested_fallback(self):
        cap = "rules.quintessence"
        self.m["platforms"]["android"]["capabilities"].remove(cap)
        self.m["platforms"]["android"]["pending"][cap] = {"owner": "Android", "handoff": "docs/handoff.md"}
        with self.assertRaisesRegex(ValueError, "safe fallback"):
            policy.validate_catalogs(policy.ROOT, self.m, self.catalog)
        self.m["capabilities"][cap]["fallbacks"] = {"android": {"behavior": "advisory-text", "test": self.m["capabilities"][cap]["tests"]["android"]}}
        policy.validate_catalogs(policy.ROOT, self.m, self.catalog)

    def test_new_enum_semantics_cannot_hide_behind_an_old_field(self):
        self.m["capabilities"]["new-rule"] = {"tests": {}}
        self.m["platforms"]["android"]["pending"]["new-rule"] = {"owner": "Android", "handoff": "docs/handoff.md"}
        self.m["platforms"]["ios"]["capabilities"].append("new-rule")
        self.catalog["enumCapabilities"]["disciplines.[].ritualRules.humanity"]["none"] = "new-rule"
        with self.assertRaisesRegex(ValueError, "safe fallback"): policy.validate_catalogs(policy.ROOT, self.m, self.catalog)

    def catalog_snapshot(self, directory):
        root = Path(directory)
        shutil.copytree(policy.ROOT / "RequiemCharacterSheet/Catalogs", root / "RequiemCharacterSheet/Catalogs")
        return root

    def test_additive_book_is_accepted_but_new_fields_and_broken_references_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.catalog_snapshot(directory)
            path = root / "RequiemCharacterSheet/Catalogs/z-new.json"
            book = {"format": "requiem-catalog", "version": 1, "book": {"id": "new", "name": "New book"},
                    "banes": [{"id": "new-bane", "name": "New bane", "summary": "A description.", "source": {"book": "new", "page": 1}}]}
            path.write_text(json.dumps(book))
            inventory = policy.validate_catalogs(root, self.m, self.catalog)
            self.assertEqual("new", inventory["books"][-1])
            book["banes"][0]["inventedMechanic"] = True; path.write_text(json.dumps(book))
            with self.assertRaisesRegex(ValueError, "Unclassified catalog field"): policy.validate_catalogs(root, self.m, self.catalog)
            del book["banes"][0]["inventedMechanic"]
            book["banes"][0]["source"]["book"] = "missing"; path.write_text(json.dumps(book))
            with self.assertRaisesRegex(ValueError, "Unknown source book"): policy.validate_catalogs(root, self.m, self.catalog)

    def test_base_protects_fixtures_capabilities_and_scenario_requirements(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(policy.ROOT / "shared", root / "shared")
            def git(*args): subprocess.run(["git", "-C", str(root), *args], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            git("init"); git("add", "shared")
            git("-c", "user.name=CI test", "-c", "user.email=ci@example.invalid", "commit", "-m", "Baseline")
            policy.check_base(root, "HEAD", self.m, self.catalog)
            self.m["platforms"]["android"]["capabilities"].remove("rules.elder-banes")
            with self.assertRaisesRegex(ValueError, "removed promised"): policy.check_base(root, "HEAD", self.m, self.catalog)
            self.setUp(); self.m["scenarios"]["characters/v12-elder-bane.json"]["requires"] = ["save.base"]
            with self.assertRaisesRegex(ValueError, "Scenario coverage changed"): policy.check_base(root, "HEAD", self.m, self.catalog)
            self.setUp(); (root / "shared/fixtures/characters/v12-elder-bane.json").write_text('{}')
            with self.assertRaisesRegex(ValueError, "Historical fixture changed"): policy.check_base(root, "HEAD", self.m, self.catalog)

    def test_missing_or_skipped_capability_evidence_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "tests.xml"
            report.write_text('<testsuite><testcase name="ordinaryPlayMatchesThePhoneEditor"><skipped/></testcase></testsuite>')
            with self.assertRaisesRegex(ValueError, "No executed"): policy.evidence(policy.ROOT, self.m, "ios", [report])
            report.write_text('<testsuite><testcase name="unrelated"/></testsuite>')
            with self.assertRaisesRegex(ValueError, "lack passing tests"): policy.evidence(policy.ROOT, self.m, "ios", [report])


if __name__ == "__main__": unittest.main()
