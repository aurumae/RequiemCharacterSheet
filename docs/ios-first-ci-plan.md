# CI for iOS-first development

Status: proposal, 13 November 2026; no workflow or repository ruleset is changed
by this document. Companion: [Android parity plan](android-current-parity-plan.md).

## What should count as a failure

There are two different problems today. Hardcoded book totals and a one-bloodline
assumption break on ordinary catalog growth. Separately, the exchange compares
both apps as if they always implement the same newest features. Visual iOS-only
changes do not inherently break Android; shared data and contract changes can.

Keep failures for broken builds, wrong implemented behavior and loss of supported
save data. Treat an explicitly recorded, safely unsupported new iOS feature as
pending Android work. A gap must be visible without being reported as a failing
test on every unrelated push.

## 1. Record what each platform promises

Introduce a small reviewed `shared/compatibility.json` (proposed path), plus fixture
metadata. Record each platform's highest readable schema, conditional writer rules,
supported catalog categories, implemented rule capabilities, and the features still
pending with an Android owner and handoff reference. Give each behavior an explicit
stable ID; schema versions alone do not describe rules or UI support.

At the inspected baseline, iOS reads through 12; Android on main reads through 10;
the unmerged beta-2 branch reads through 11. These values must describe code actually
in the tested checkout, not intended releases. After the parity port both read 12.

Each fixture/action scenario declares its schema and required capabilities. A
required validator checks that metadata agrees with actual encoder/decoder limits,
that every new shared feature is classified, and that all previously promised
capabilities remain tested. Compare against the PR base so a regression cannot be
hidden by removing a capability or relabelling an old test as pending. Contract
retirement or changed semantics requires an explicit versioned migration decision.

Keep immutable examples of previous contract versions. New features add examples;
they do not rewrite historical expectations to pretend older apps supported them.
Unknown data in a supported save must retain the established preservation behavior;
new save fields that an old app would discard need a new required schema version.

## 2. Separate the jobs by responsibility

| Check | Required behavior |
| --- | --- |
| iOS | Build and run Swift host/iOS unit tests for all iOS-supported features. Preserve `-skip-testing:RequiemCharacterSheetUITests`. |
| Android | Run Kotlin rules/storage tests, lint and debug/unsigned release packaging for Android's actual implementation. Continue testing all supported behavior even while newer features are pending. |
| Shared data | Independently validate catalog format, file inventory, references, supported effect/requirement declarations, citations, deterministic precedence and fixture metadata. A malformed shared file is a real failure. |
| Supported exchange | Required bidirectional tests for the contract both apps support, plus required safe-rejection tests for newer schemas on older consumers. Compare every entry in shared supported catalog categories, not just overlapping IDs. |
| Parity report | Report which newer iOS features/scenarios are pending on Android, with links and counts. Expected declared gaps are informational; unknown/unclassified gaps and regressions in supported features fail their required checks. |
| Parity/release acceptance | When Android claims a feature, it immediately becomes required in its local tests and exchange. A release claimed to match a given iOS baseline must pass all scenarios for that baseline. |

Do not implement this by adding `continue-on-error` to the existing exchange job or
ignoring arbitrary assertions. Split the orchestration into local feature tests,
supported exchange, forward-rejection cases and capability reporting. Preserve
`scripts/check-save-contract` as the entry point, with documented supported/strict
modes if useful. Its producers and consumers must choose the same scenario list;
no consumer should request a file an intentionally unsupported producer did not emit.
Upload JUnit/Swift exchange reports and capability summaries even when a test fails.

For catalog testing, derive the expected inventory independently of `Catalog.bundled`
from the authoritative catalog sources. Assert exact inventory for supported kinds,
source references and ordering. Test precedence/name matching with controlled small
catalogs, and validate real bundles with all current files. Never replace the failed
four-book assertion with a permanent eight-book assertion, or weaken it to checking
that a few familiar books still exist. Likewise, identify Morbus by ID in its test.

## 3. Example: iOS gains a new schema before Android

After both platforms support 12, suppose iOS adds a feature requiring schema 13:

1. The iOS PR adds its model/tests and a new fixture, declares schema 13 support,
   records Android as pending and appends the handoff. iOS continues writing the
   lowest schema actually required by each character.
2. Required exchange still round-trips supported schema-12-and-earlier characters
   through both apps. The iOS side tests the new schema-13 behavior locally.
3. Android must refuse the schema-13 file with its newer-version message, without
   changing storage, importing an empty character or stripping the new fields.
   That safe refusal is an explicit passing requirement, not a skipped test.
4. The report says the feature awaits Android. The new feature does not make every
   unrelated commit red; genuine schema-12 regressions still do.
5. The Android port adds the feature, raises its declared capability and proves
   full schema-13 exchange. Both platforms then share the new required coverage.

## 4. Catalog changes need their own compatibility rule

Both apps consume the same live JSON, and many new mechanics do not change save
schema. A feature manifest must therefore cover rule semantics as well as schemas.
Parsing a field successfully is not proof of implementing its behavior.

- Pure additive content using established categories/rules can load and be tested
  automatically. Book counts and list cardinality should not block it.
- An additive mechanic with an established safe text/advisory fallback can be
  explicitly pending in the report, retaining its source text. This does not certify
  that Android enforces it. Preserve the product's advisory-vs-enforced distinction.
- A shared change that breaks an existing consumer, loses data or silently alters
  promised behavior must still fail. Fix the compatible consumer boundary, or stage
  the incompatible data change until it is safe. A pending label cannot excuse it.
- If a future breaking catalog format truly must ship independently, use an explicit
  build-time catalog revision per platform, generated from the same authoritative
  source and validated against that revision's contract. Treat that as a separate
  design change; do not add parallel hand-maintained catalogs preemptively.

There are no user-facing book switches or hidden per-book exclusions in this
proposal. Android release acceptance must explicitly account for unsupported
mechanics in its shipped catalogs; a green supported-contract check alone is not
a claim of full feature parity.

## 5. Run the relevant jobs without losing required results

First stabilize the contract classification; path filtering alone cannot solve a
shared catalog or save incompatibility. Then use one always-triggered PR workflow
with change detection and conditional expensive jobs:

| Changed paths | Jobs to run |
| --- | --- |
| SwiftUI/app presentation only | iOS checks; cheap metadata/parity reporting. |
| Swift models, persistence, `Chronicles/Core`, `Package.swift` or Swift contract tests | iOS/host checks and supported exchange. |
| Android code/build/test configuration | Android checks and supported exchange. |
| Catalogs, fonts, shared fixtures, compatibility metadata, orchestration scripts or CI | Both affected platform suites, shared validation and exchange; default to both when uncertain. |
| Documentation only | Documentation/metadata validation and an explicit no-build-needed result. |

Use a stable required aggregate result that always runs, even when a dependency
fails. It must verify that every job selected by change detection completed
successfully, distinguish legitimate skips from unexpected skips/cancellation, and
fail if classification itself failed. Test the routing with representative path
changes before requiring the aggregate. Run the full supported suite on main and
on a schedule as a backstop; use manual strict parity checks for milestones.

GitHub warns that skipping a whole required workflow through path filters can leave
its checks pending, while conditionally skipped jobs report success. The aggregate
must therefore validate expected execution, not simply accept all skipped jobs.
See [required-check troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)
and [job conditions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions).

Inspect the current branch ruleset before implementation; no assumption is made
here that a particular check is already required. Switch required check names only
after the replacement has produced a valid result. Do not change repository
protection settings as part of this planning-only task.

## 6. Adopt the policy in small steps

1. Fix brittle catalog tests and revalidate the beta-2 integration baseline.
2. Add capability/fixture metadata and its validator, initially matching actual
   main/PR implementations. Record every pending schema/rule gap explicitly.
3. Split required supported exchange from full latest-feature parity. Add
   future-save rejection and regression protection for capability declarations.
4. Publish a clear job summary of supported and pending behavior. Expected gaps
   need no recurring failure notification; test errors must retain their normal
   failing status. The report must say what was not exercised.
5. Add dependency-aware job routing, artifact uploads and the tested aggregate.
6. Complete the Android port, promote each capability with passing tests, and run
   strict acceptance at the selected iOS baseline before claiming parity.

Acceptance examples: an iOS-only view change cannot fail on an unrelated Android
feature gap; a valid ninth book does not break an inventory assumption; a new schema
is safely refused by an older Android; a broken existing XP rule or damaged save
still blocks; a falsely declared capability fails; and a completed port expands
required exchange coverage rather than leaving permanent exclusions.
