# Android Forsaken ordinary-play candidate

Version `0.2.0-preview.2` (code 3) is the Android part of phase 3. It installs over
the phase 2 preview as `com.omccolgan.ForsakenCharacterSheet`, beside Requiem.
It enables blank sheets and ordinary-play edits. Guided creation is still read-only;
there is no guided-new-character action until phase 4.

**Phase 3 is not fully complete:** Forsaken has not joined the shared contract or
the bidirectional Xcode exchange. The coordination gate in
[the approved plan](android-forsaken-plan.md#proposal-for-the-shared-save-and-catalog-contract)
is still open. No fixture, catalog, policy, workflow, Xcode or Swift change is part
of this Android implementation. The existing exchange checks Requiem only.

## Try the candidate

1. Create a blank sheet, or import the unchanged `forsaken-v1-play.json` fixture
   from `ForsakenCharacterSheetTests/Fixtures/`. Ordinary edits save automatically;
   Save explicitly flushes pending edits. The library's Save to file and Export
   actions wait for writes and produce `.wtfcharacter` files.
2. With Mara, compare Strength in Dalu (7), Gauru (10) and Hishu (5). Inspect all
   five forms under Advantages. Switch an active Gift or rite, edit Favored Form,
   and check the affected totals. Shrinking Health folds overflow wounds as on iOS.
3. Inspect the intentionally overspent Totem: 6 Experiences spent against a budget
   of 3. Add a granted Merit: it gains a zero-owned-dot row and ignores prerequisites.
   Granted Specialties remain separate from bought ones. At 20 pack points the
   budget is 5, not 10. Uncounted bonus dots stay visible and faded, even above ten.
4. In XP Mode, raise Renown, learn an offered free Facet, remove it and lower the
   paid Renown. Inspect the ledger and refunds. Catalog pickers show first/further
   Facet prices, affinity and Renown credits. Extra Moon Gifts cost 5 then 2 per
   Facet; lodge lore costs outsiders triple and refunds the historical price.
5. Add or resolve a Condition, take a Beat, and choose Siskur-Dah's Ritemaster from
   the faction/lodge groups. Rename a Specialty used by Area of Expertise; the
   qualifier follows. Removing its last matching Specialty removes that Merit too.
6. Close and reopen, rotate with a dialog draft open, and test 150% text. Export an
   edited copy for iOS acceptance. Actual iOS consumption of Android's edits remains
   unverified until the coordinated exchange and device check run.
7. Import the creation fixture. It still exposes saved creation choices without
   applying grants or permitting edits. Its Save file action preserves original
   bytes. Both apps still reject the other game's files before mutation.

An untouched import exports its original bytes, including unknown keys. A partial
file without identity receives only an ID once. Keep Both changes only ID/name.
An actual edit writes the known schema-1 fields using iOS's conditional omissions,
uppercase UUIDs, fractional Foundation dates, visible tracks and historical keys.
Unknown future schemas are refused; unknown same-schema keys are not a supported
extension of the canonical writer. Inactive known state survives, including Pure
auspice/Moon values, extra Moon dots, free credits and Favored Form choices.

## Reference outcomes and evidence

Fixed synthetic catalogs drive rules-outcome tests so book updates do not silently
redefine them. The two submitted schema-1 fixtures stay byte-identical in place.
Numeric JSON equality treats `1` and `1.0` like Foundation's object comparison;
raw-transfer equality separately compares bytes.

| iOS reference outcomes | Android evidence |
| --- | --- |
| `SaveFormatTests`: every key, full-object write/read, play and creation semantics | `ForsakenSaveTest`: canonical equality for both fixtures, omissions/custom rows, array nulls, fractional dates, fixture calculations, creation refusal and no-op edits. Existing `ForsakenReaderTest` retains schema-1 field coverage. |
| New character defaults, forms, derived traits, Primal Urge caps, untrained Brawl, weapons with hands | `ForsakenRulesTest.newCharactersAndPrimalUrgeFollowTheReferenceTable`, `formsChangeAttributesAndAllDerivedTraits`, `dicePoolsAreWorkedOutInTheFormWornWithUntrainedPenalties`. |
| `shiftingToASmallerFormKeepsItsWounds`, Health shrink from active powers | `shiftingToASmallerFormKeepsItsWoundsAndTheyDoNotReturn`, `passiveAndActivePowersRespectRatingsAndForms`; encode/reopen checks prevent wounds returning. |
| `bonusDotsPastTheLimitStackBySource`, Totem budgets/rows/exemptions/Specialties | `bonusDotsPastTheLimitStackBySource`, `totemBudgetGrantsAndMeritRowsFollowTheReference`; `EffectiveRatingUiTest` checks the third row above ten, faded ink and legal base menu at large text. |
| Pure effective auspice/Moon suppression and saved Hunter's Aspect; custom Moon/Facet fields | `boughtMoonGiftPassiveFacetsAndPureInactiveValuesArePreserved`, reader/save tests and `identityEditsResetOnlyTheReferenceFields`; creation fixture grants are preserved, not corrected. |
| Passive/active Gifts, form restrictions, bought Moon passive Facets, lodge Essence, Fortified/Favored Form, Instinctive Defense, rite armor | `passiveAndActivePowersRespectRatingsAndForms`, `boughtMoonGiftPassiveFacetsAndPureInactiveValuesArePreserved`, `instinctiveDefenseFavoredFormAndArmorApplyOnlyWhereSpecified`, lodge tests. |
| `thePriceShownIsThePriceCharged`, Renown free Facets, historical refunds, `aSecondMoonGiftCostsFiveThenTwoAFacet` | `thePriceShownIsThePriceChargedAndRefundsKeepHistoricalCosts`, `aNewDotOfRenownOffersOnlyUnknownFacetsInUnlockedGifts`, `aSecondMoonGiftCostsFiveThenTwoAFacetsAndKeepsInactiveDots`; activity test buys, recreates, deletes and refunds exactly once. |
| `lodgeLoreCostsOutsidersThreeTimesAsMuch`, era replacement affinities, werewolf prerequisites, human-only Merits | `lodgeLoreCostsOutsidersThreeTimesAsMuchAndRefundsWhatWasPaid`, `eraReplacementAffinityAndWerewolfPrerequisitesAreGameSpecific`. No invented tribe eligibility gate. |
| Spirit Rank, Harmony and Kuruth triggers; Siskur-Dah groups and ungrouped notes | `spiritRankAndHarmonyBoundariesMatchTheReference`, `siskurDahGroupsExcludeUnsupportedFactionsAndPreservePlainChoices`; activity test chooses a Ritemaster and resolves the Condition. |
| Shared Conditions/Beats, Specialty-dependent Merits and history | `conditionEventsUseSharedBeatsAndPreserveHistoricalKeys`, `specialtiesRenameTheirDependentMeritAndRefundBothWhenRemoved`, and `ForsakenLogTest` for qualified Merit names, live/final Condition labels and unchanged historical keys; `PlayTransferTest` persists/restarts purchases and refunds. |
| Advisory rules, catalog grouping/unofficial visibility, source details, all heading resources | Existing reader/catalog tests and heading byte tests; `unknownMechanicsStayAdvisoryAndDoNotChangeNumbers`. Text-only rules are retained rather than invented as automation. |
| Library imports/exports, identity, duplicate choices, restart and no-op writes | `PlayTransferTest` uses the same `forsakenStore` factory as the app; `PreviewUiTest` covers the actual activity/file contracts and protection of guided saves. The phase-2 storage cases were retained and extended. |

All creation allocation/grant/finish tests remain phase 4. The existing questions
about creation-fixture grants, Pure prose, log keys and heading generation remain
open. A new question records Swift's custom-Wolf-Facet fallback price of 2; Android
matches that implementation, without changing the submitted catalogs or fixtures.
The handoff also asks about two benefits that Swift excludes for zero-owned-dot
Totem Merits: alternative Defense Skills and Embodiment of the Firstborn. Android
retains those exceptions pending clarification.

Physical-phone TalkBack, real cross-device exchange, and release signing/listing
remain acceptance/delivery work. Emulator and local checks are recorded in the
append-only handoff; they do not constitute iOS writer/consumer evidence.
