# Maintaining iOS-first compatibility

The implemented contract is `shared/fixtures/contracts.json`. Both test suites read
it. `shared/catalog-contract.json` classifies catalog fields, their types and rule
values. `scripts/contract_policy.py` validates these declarations against the code,
catalogs, fixtures, PR base and executed test reports. Ordinary additive books need
no source-code count update.

Run `scripts/check-save-contract` for supported bidirectional exchange, or add
`--strict` when claiming current cross-platform parity. This runs the complete Swift
host suite, Kotlin rules and Android storage suites, then Swift consumption of real
Android exports. Reports, the selected scenarios and produced files stay under
`.contract-reports/`. `REQUIEM_REPORT_DIR` can choose another artifact directory.
The same generated plan controls both producers and consumers. Local supported tests
still run even when their external exchange is not selected.

## Keeping main green while iOS is ahead

New work lands on iOS first and is ported to Android later. A red `main` must mean something is broken, never that
Android hasn't caught up.

- `scripts/check-policy` is the policy job's check: the policy unit tests, then `contract_policy.py` with any
  arguments. It needs only Python. `swift test` runs it (`SaveContractTests.contractPolicyPasses`), so a stale
  contract fails on the Mac before it's pushed.
- Pushes to `main` and the weekly run are not strict: declared pending ports pass. Only `--strict` (the manual
  run's default) claims parity, and the policy unit tests must never assert it of the live manifest.
- A test named in the manifest can be renamed on iOS, with the manifest updated in the same commit. The PR-base
  comparison rejects a renamed capability test, so do it in a push to `main`.
- Forsaken is outside the contract until Android has a `:forsaken` module. Its catalogs aren't validated here and its
  fixtures must stay out of `shared/fixtures/`, where every file has to be classified as a Requiem scenario. Its
  own tests, with the fixtures that pin its save format (`docs/forsaken-save-format.md`), run in the `ios` job.

## Adding an iOS feature before its Android port

1. Give new behavior a stable capability ID. Add its iOS test reference and mark it
   supported by iOS. Record Android as pending with an owner and a handoff link.
   Append the normal cross-platform handoff.
2. Classify new fixture/action files and catalog fields/semantic values. Existing
   fixtures are immutable: add a versioned example instead of rewriting one. A new
   save field also needs a `saveFields` declaration and fixture requirement.
3. If an older app would discard that state, require a newer save schema and keep
   writing the lowest schema needed by each character. Update the actual iOS reader,
   writer probes and declared reader/writers together. Merely marking a readable
   but lossy save as pending is rejected.
4. For a live catalog mechanic without a schema change, an unsupported consumer needs
   a tested `advisory-text` fallback, referenced under the capability's `fallbacks`.
   This must describe and retain the rule rather than pretending to enforce it.
   If there is no safe fallback, stage the incompatible catalog change or implement
   the consumer boundary first. No book switches or separate handwritten catalogs.
5. Required tests exchange the shared supported scenarios and exercise refusal of
   every newer-schema fixture through the older app's real store. The capability
   report lists pending work and every scenario excluded from exchange. Strict mode
   fails while any capability/scenario remains pending.
6. The Android port adds its meaningful tests, removes its pending entry and claims
   support. Its local tests and expanded exchange become required immediately.

Tests named in the manifest must exist and have passed in the actual test reports.

Android rule-engine outcome tests use the fixed, test-only inputs in
`android/requiem/src/test/kotlin/ie/requiem/rules/RulesTestCatalog.kt`. These are
deliberately incomplete examples with familiar IDs, not copies of the shipped
books; do not update their values when correcting a production catalog. Shared
fixture/action exchanges, writer probes, storage tests and structural catalog
checks still use the authoritative bundled catalogs.

For a safe `advisory-text` fallback, iOS can cite
`CatalogFallbackTest.unknownCatalogFieldsAndRuleValuesRemainAdvisoryText` in
`android/requiem/src/test/kotlin/ie/requiem/rules/CatalogFallbackTest.kt`. It exercises
the actual catalog decoder, chooser, details, prerequisites, derived traits and
save round trip: unknown fields/effect types/prerequisite kinds/Humanity-rule
values do not prevent reading an entry, its summary and citation remain visible,
and unsupported mechanics are not enforced. The rule must have usable descriptive
text in the supported presentation fields. This test is not evidence of numeric
parity and does not make a lossy save field or unsafe editor an acceptable fallback.

Writer declarations are checked against real encoder output. Current canonical saves
must retain every field, while untouched file transfer and Keep Both preserve bytes
or all fields other than ID/name respectively. A synthetic next-version file always
tests safe refusal, even after a historical future fixture becomes readable.

The PR-base comparison rejects removed capabilities/catalog categories, reduced
reader limits, changed existing writer cases, weakened scenario requirements,
removed capability tests and changed old fixtures or field classifications. For an
intentional retirement/migration, introduce a versioned contract and review the
policy change explicitly; there is no general bypass flag.

## Job routing and required result

The workflow always starts. Documentation runs the policy checks; Swift UI changes
run iOS; Swift model/persistence/core/tests run iOS plus exchange; Android changes
run Android plus exchange. Shared inputs and unknown paths run all jobs. Main pushes,
weekly scheduled runs and manual runs also select all jobs. Manual strict mode is
enabled by default. iOS UI tests remain excluded from GitHub and stay in Xcode Cloud
and local runs.

`CI result` runs even after dependency failures. It fails on failed routing, a failed
selected job, unexpected skips, cancellation or missing results. Expected unselected
jobs can be skipped. Python policy tests cover these decisions and iOS-first schema
promotion. Capability summaries and test artifacts upload even when checks fail.

On 13 November 2026 GitHub reported no repository rulesets and no protection on
`main`. No protection setting was changed. Once the new workflow has passed on GitHub,
`CI result` is the stable check to require if branch protection is enabled.

Automated strict parity does not certify visual, physical-device, TalkBack or Play
delivery acceptance. Those remain recorded in the release handoff.
