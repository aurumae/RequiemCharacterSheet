# Android Forsaken ordinary-play candidate

Version `0.2.0-preview.3` (code 4) is the Android part of phase 3. It installs over
the phase 2 preview as `com.omccolgan.ForsakenCharacterSheet`, beside Requiem.
It enables blank sheets and ordinary-play edits. Guided creation is still read-only;
there is no guided-new-character action until phase 4.

**Phase 3 is not fully complete:** Forsaken has not joined the shared contract or
the bidirectional SwiftPM exchange. Claude agreed the registry and revised host
exchange on 18 November; implementation and the coordinated fixture/test move are
still outstanding in [the plan](android-forsaken-plan.md#proposal-for-the-shared-save-and-catalog-contract).
The existing exchange checks Requiem only. This candidate includes the two confirmed
iOS-main rule corrections: custom Wolf Facets cost 1 Experience, and Totem-granted
Defensive Combat/Embodiment activate with zero owned dots. Historical refunds retain
the recorded purchase price.

**Visual correction candidate:** preview 3 applies the supplied iOS references to
fonts, logo, fields/counters, rated rows, Forms/Advantages, Gifts, pickers and Condition
cards. [The visual reference](android-forsaken-visual-reference.md) records the
comparison procedure and evidence. User/device appearance acceptance is still open.

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
5. Swipe between Condition cards and tap one for full details, edits, Beat/End/Resolve
   actions. Add or resolve a Condition, and choose Siskur-Dah's Ritemaster from
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

All creation allocation/grant/finish tests remain phase 4. Claude's 18 November
reply resolves the creation-fixture grants, Pure prose, historical/new log keys and
heading-loader questions; see the plan for the exact expectations. The fixtures
remain unchanged. `customFacetPricesMatchChargesAndPreserveHistoricalRefunds` covers
Wolf 1/Shadow 2 and refunding an older Wolf purchase at its recorded cost of 2.
`meritsTheTotemGrantsDoWhatBoughtOnesDo` covers zero-owned Defensive Combat and
Embodiment, stacked caps, encode/reopen and removal. `advantagesRemindersFollowTheCurrentFormAndTribe`
checks the form and Pure-only notes. Activity tests cover the visible custom price,
purchase/recreation/refund, and Condition carousel editing/removal/Beat history.

Physical-phone TalkBack, real cross-device exchange, and release signing/listing
remain acceptance/delivery work. Emulator and local checks are recorded in the
append-only handoff; they do not constitute iOS writer/consumer evidence.
