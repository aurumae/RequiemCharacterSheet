package ie.forsaken.rules

import ie.chronicles.core.*
import org.junit.Assert.*
import org.junit.Test

class ForsakenRulesTest {
    private val catalog = ForsakenTestCatalog.catalog
    private val codec = ForsakenCodec(catalog)
    private val edits = ForsakenEdits(catalog)
    private fun source(id: String) = TraitSource(catalog = id)
    private fun rules(s: ForsakenState) = ForsakenRules(s, catalog)
    private fun ForsakenState.attr(id: String, dots: Int) = copy(attributes = attributes.map { if (it.attribute == id) it.copy(rating = dots) else it })
    private fun ForsakenState.sk(id: String, dots: Int) = copy(skills = skills.map { if (it.skill == id) it.copy(rating = dots) else it })
    private fun hunter() = codec.character(ForsakenState(auspice = source("seer"), tribe = source("hunters"),
        renown = Renown.entries.associate { it.name to 1 }, xpMode = true, experiences = 30))

    @Test fun newCharactersAndPrimalUrgeFollowTheReferenceTable() {
        val s = ForsakenState(); assertEquals(7, s.essence); assertEquals(7, s.harmony); assertEquals(Form.hishu, s.form)
        assertEquals(6, rules(s).health()); assertEquals(10, rules(s).essenceMaximum)
        assertEquals(listOf(5,5,5,5,5,6,7,8,9,10), (1..10).map { PrimalUrgeLevel.level(it).traitMaximum })
        assertEquals(listOf(10,11,12,13,15,20,25,30,50,75), (1..10).map { PrimalUrgeLevel.level(it).essenceMaximum })
        assertEquals(PrimalUrgeLevel.level(1), PrimalUrgeLevel.level(-1)); assertEquals(PrimalUrgeLevel.level(10), PrimalUrgeLevel.level(12))
    }
    @Test fun formsChangeAttributesAndAllDerivedTraits() {
        val s = ForsakenState().attr("strength",2).attr("stamina",2).attr("dexterity",3).attr("wits",2).attr("composure",2).sk("athletics",2)
        val r = rules(s)
        assertEquals(7, r.health()); assertEquals(11, r.health(Form.gauru)); assertEquals(4, r.size(Form.urhan))
        assertEquals(4, r.defense()); assertEquals(5, r.initiative()); assertEquals(10, r.speed())
        assertEquals(14, r.speed(Form.gauru)); assertEquals(6, r.initiative(Form.gauru))
        assertEquals(15, r.speed(Form.urhan)); assertEquals(7, r.initiative(Form.urhan))
        assertEquals("+3 in Gauru", rules(s.copy(form = Form.gauru)).attributeNote("strength"))
    }
    @Test fun shiftingToASmallerFormKeepsItsWoundsAndTheyDoNotReturn() {
        var c = codec.character(ForsakenState(form = Form.dalu, healthTrack = List(9) { Damage.lethal }).attr("stamina",3))
        assertEquals(10, rules(c.state).health())
        c = edits.change(c) { it.copy(form = Form.hishu) }
        assertEquals(listOf(Damage.aggravated) + List(7) { Damage.lethal }, c.state.healthTrack)
        c = edits.change(c) { it.copy(form = Form.dalu) }
        assertEquals(listOf(Damage.none, Damage.none), c.state.healthTrack.visibleTrack(rules(c.state).health(), Damage.none).takeLast(2))
        val other = codec.character(ForsakenState(healthTrack = List(8) { Damage.bashing }).attr("stamina",3))
        val smaller = edits.change(other) { it.attr("stamina",1) }
        assertEquals(listOf(Damage.lethal,Damage.lethal) + List(4) { Damage.bashing }, smaller.state.healthTrack)
        assertEquals(smaller.state.healthTrack, codec.decode(codec.encode(smaller)).state.healthTrack)
    }
    @Test fun bonusDotsPastTheLimitStackBySource() {
        var s = ForsakenState(totem = Totem(advantages = listOf(TotemAdvantage(TotemKind.attribute,"strength", dots=2)))).attr("strength",5)
        assertEquals(7, rules(s).totalAttribute("strength")); assertEquals(6, rules(s).attribute("strength"))
        s = s.copy(merits = listOf(Merit(source("embodiment-of-the-firstborn"),"Strength",5)))
        assertEquals(8, rules(s).totalAttribute("strength")); assertEquals(7, rules(s).attribute("strength"))
        s = s.copy(primalUrge = 6); assertEquals(8, rules(s).attribute("strength"))
        s = s.attr("strength",6); assertEquals(9, rules(s).totalAttribute("strength")); assertEquals(8, rules(s).attribute("strength"))
        assertEquals(11, rules(s).attribute("strength",Form.gauru))
    }
    @Test fun totemBudgetGrantsAndMeritRowsFollowTheReference() {
        assertEquals(listOf(0,1,1,3,3,5,5,10), listOf(0,1,8,9,14,15,20,21).map { Totem(packPoints=it).experienceBudget })
        assertEquals(setOf("totem","dedicated-locus"), totemMeritsNeverGranted)
        val advantages = listOf(TotemAdvantage(TotemKind.attribute,"strength"), TotemAdvantage(TotemKind.merit,"fleet"),
            TotemAdvantage(TotemKind.skill,"brawl", dots=2), TotemAdvantage(TotemKind.specialty,"brawl",detail="Claws"))
        var c = codec.character(ForsakenState(xpMode=true).sk("brawl",5))
        c = edits.change(c) { it.copy(totem=Totem(packPoints=9,advantages=advantages)) }
        assertEquals(10, c.state.totem.experiencesSpent); assertEquals(3,c.state.totem.experienceBudget)
        assertEquals(6,rules(c.state).skill("brawl")); assertEquals(listOf("Claws"),rules(c.state).grantedSpecialties("brawl"))
        assertEquals(9,rules(c.state).speed()); assertEquals(0,c.state.merits.single().rating)
        assertFalse(rules(c.state).prerequisitesApply(c.state.merits.single())); assertTrue(c.state.changeLog.isEmpty())
        c = edits.change(c) { it.copy(totem=it.totem.copy(advantages=emptyList())) }; assertTrue(c.state.merits.isEmpty())
        c = edits.change(c) { it.copy(totem=it.totem.copy(advantages=advantages)) }
        c = edits.change(c) { it.copy(merits=it.merits.map { row -> row.copy(rating=1) }) }
        c = edits.change(c) { it.copy(totem=it.totem.copy(advantages=emptyList())) }
        assertEquals(1,c.state.merits.single().rating); assertEquals(1,rules(c.state).experiencesSpent)
        // These two Swift helpers test owned rating > 0, even when a Totem grants the Merit.
        // Preserve the submitted behavior while the handoff asks whether that exception is intended.
        val exceptions=edits.change(codec.character()) { it.copy(totem=Totem(advantages=listOf(
            TotemAdvantage(TotemKind.merit,"defensive",detail="Brawl"),
            TotemAdvantage(TotemKind.merit,"embodiment-of-the-firstborn",detail="Strength",dots=5),
        ))) }
        assertTrue(rules(exceptions.state).alternativeDefenseSkills.isEmpty())
        assertEquals(0,rules(exceptions.state).attributeBonus("strength"))
    }
    @Test fun passiveAndActivePowersRespectRatingsAndForms() {
        var s=ForsakenState(auspice=source("seer"),renown=mapOf("purity" to 3,"glory" to 2)).attr("strength",5)
        assertEquals(9,rules(s).health())
        s=s.copy(facets=listOf(OwnedFacet(source("power-passive")), OwnedFacet(source("power-strength")), OwnedFacet(source("power-speed"),active=true)))
        assertEquals(5,rules(s).willpower); assertEquals(13,rules(s).essenceMaximum); assertEquals(5,rules(s).attribute("strength"))
        val hishu=rules(s).speed(); val urhan=rules(s).speed(Form.urhan)
        s=s.copy(facets=s.facets.map { if(it.source.catalog=="power-strength") it.copy(active=true) else it })
        assertEquals(8,rules(s).attribute("strength")); assertEquals(7,rules(s).brawlPool())
        assertEquals(hishu+3,rules(s).speed()); assertEquals(urhan+3,rules(s).speed(Form.urhan))
        s=s.copy(rites=listOf(OwnedRite(source("empower"),active=true)))
        assertEquals(2,rules(s).attribute("dexterity")); assertEquals(18,rules(s).essenceMaximum)
        assertTrue(codec.decode(codec.encode(codec.character(s))).state.rites.single().active)
        val base = rules(s).health()
        val c=edits.change(codec.character(s.copy(healthTrack=List(base){Damage.bashing}))) { it.copy(rites=emptyList()) }
        assertEquals(base-1,rules(c.state).health()); assertEquals(Damage.lethal,c.state.healthTrack.first())
    }
    @Test fun boughtMoonGiftPassiveFacetsAndPureInactiveValuesArePreserved() {
        val extra=OwnedMoonGift(source("moon"),dots=2)
        val s=ForsakenState(auspice=source("singer"),renown=mapOf("glory" to 2),extraMoonGifts=listOf(extra))
        assertEquals(8,rules(s).health())
        val pure=s.copy(tribe=source("pure"),huntersAspect="Primal")
        assertTrue(rules(pure).isPure); assertNull(rules(pure).effectiveAuspice); assertNull(rules(pure).moonGift)
        assertEquals(0,rules(pure).moonGiftDots); assertEquals(6,rules(pure).health())
        assertEquals(setOf("other"),rules(pure).affinityGifts); assertEquals("instinctive",rules(pure).huntersAspect?.text("condition"))
        assertEquals(extra,codec.decode(codec.encode(codec.character(pure))).state.extraMoonGifts.single())
    }
    @Test fun spiritRankAndHarmonyBoundariesMatchTheReference() {
        assertEquals(listOf(1,2,2,3,3,4,4,5),listOf(0,4,7,8,12,13,18,19).map { rules(ForsakenState(renown=mapOf("glory" to it))).spiritRank })
        assertEquals(TriggerKind.entries,TriggerKind.entries.filter { it.applies(0) })
        assertEquals(listOf(TriggerKind.common,TriggerKind.specific),TriggerKind.entries.filter { it.applies(9) })
        assertEquals(listOf(TriggerKind.specific),TriggerKind.entries.filter { it.applies(3) })
        assertTrue(TriggerKind.entries.none { it.applies(5) })
        assertEquals("Taste",rules(ForsakenState(kuruthTriggerSet=source("blood"))).kuruthTrigger(TriggerKind.common))
        assertEquals("No Kuruth triggers · Control for 15 minutes",harmonyDescription(5))
    }
    @Test fun instinctiveDefenseFavoredFormAndArmorApplyOnlyWhereSpecified() {
        var s=ForsakenState(merits=listOf(Merit(source("instinctive-defense"),rating=2))).attr("wits",4)
        assertEquals(4,rules(s).defense(Form.urhan)); assertEquals(4,rules(s).defense(Form.urshul)); assertEquals(1,rules(s).defense(Form.hishu)); assertEquals(2,rules(s).defense(Form.gauru))
        s=ForsakenState(merits=listOf(Merit(source("favored-form"),"Gauru",4)), favoredForm=FavoredForm(listOf("strength","stamina"),
            listOf(FormDrawback(Form.hishu,"strength"),FormDrawback(Form.urhan,"wits"),FormDrawback(Form.urhan,"wits"),FormDrawback(Form.dalu))))
        assertEquals(5,rules(s).attribute("strength",Form.gauru)); assertEquals(4,rules(s).attribute("stamina",Form.gauru))
        assertEquals(0,rules(s).attribute("strength",Form.hishu)); assertEquals(0,rules(s).attribute("wits",Form.urhan)); assertEquals(6,rules(s).speed(Form.hishu))
        s=s.copy(merits=s.merits.map { it.copy(rating=3) }); assertEquals(3,rules(s).attribute("stamina",Form.gauru))
        s=s.copy(armor=1,merits=listOf(Merit(source("fortified-form"),"Gauru",4)),rites=listOf(OwnedRite(source("armor"),active=true)))
        assertEquals(3 to 0,rules(s).armor(Form.hishu)); assertEquals(4 to 1,rules(s).armor(Form.gauru))
    }
    @Test fun dicePoolsAreWorkedOutInTheFormWornWithUntrainedPenalties() {
        var s=ForsakenState(renown=mapOf("wisdom" to 2))
        val pool=rules(s).worked("Wits + Occult + Wisdom vs Resistance")!!
        assertEquals(0,pool.dice); assertEquals("Chance die",pool.summary); assertEquals("vs Resistance",pool.against)
        s=s.sk("occult",2).sk("stealth",1).sk("weaponry",2)
        assertEquals(5,rules(s).worked("Wits + Occult + Wisdom vs Resistance")?.dice)
        assertEquals(4,rules(s).worked("Dexterity + Stealth + Purity versus Composure + Primal Urge",Form.urhan)?.dice)
        assertEquals("− animal's Resolve",rules(s).worked("Wits + Animal Ken + Wisdom - animal's Resolve")?.against)
        assertNull(rules(s).worked("Varies")); assertEquals(0,rules(s).brawlPool())
        assertEquals(4,rules(s).weaponryPool(Form.dalu)); assertNull(rules(s).weaponryPool(Form.gauru)); assertEquals(1,rules(s).firearmsPool(Form.hishu))
    }
    @Test fun thePriceShownIsThePriceChargedAndRefundsKeepHistoricalCosts() {
        var c=hunter()
        for ((id,expected) in listOf("affinity-cunning" to 3,"affinity-glory" to 2,"other-cunning" to 5,"wolf-cunning" to 1)) {
            val found=catalog.facet(id)!!; assertEquals(expected,rules(c.state).price(found).experiences)
            c=edits.learn(c,found,10.0); assertEquals(expected,c.state.changeLog.last().experiences)
        }
        c=edits.renown(c,Renown.purity,2,11.0)
        assertEquals(3,c.state.changeLog.last().experiences)
        assertEquals(Renown.purity,rules(c.state).price(catalog.facet("affinity-purity")!!).renown)
        assertEquals(5,rules(c.state).price(catalog.facet("locked-purity")!!).experiences)
        c=edits.learn(c,catalog.facet("affinity-purity")!!,12.0)
        assertEquals(0,c.state.changeLog.last().experiences); assertEquals(0,c.state.renownFacetCredits["purity"])
        c=edits.forget(c,c.state.facets.last().id,13.0); assertEquals(1,c.state.renownFacetCredits["purity"])
        val first=c.state.facets.first()
        c=edits.change(c) { it.copy(tribe=source("pure")) }
        c=edits.forget(c,first.id,14.0); assertEquals(-3,c.state.changeLog.last().experiences)
    }
    @Test fun aNewDotOfRenownOffersOnlyUnknownFacetsInUnlockedGifts() {
        var c=hunter(); c=edits.learn(c,catalog.facet("affinity-cunning")!!)
        c=edits.renown(c,Renown.purity,2)
        val ids=rules(c.state).freeFacetChoices(Renown.purity).map { it.facet.id }
        assertTrue("affinity-purity" in ids); assertTrue("wolf-purity" in ids); assertFalse("other-purity" in ids)
        assertEquals(listOf(Renown.purity),rules(c.state).renownsWithFreeFacets)
        c=edits.change(c) { it.copy(xpMode=false) }; assertTrue(rules(c.state).renownsWithFreeFacets.isEmpty())
        // Existing credits are retained, even while the sheet hides prices.
        assertEquals(1,c.state.renownFacetCredits["purity"])
    }
    @Test fun aSecondMoonGiftCostsFiveThenTwoAFacetsAndKeepsInactiveDots() {
        var c=hunter(); c=edits.change(c) { it.copy(renown=mapOf("purity" to 3),xpMode=false) }
        c=edits.change(c) { it.copy(xpMode=true) }
        val gift=OwnedMoonGift(source("alternate"))
        c=edits.change(c) { it.copy(extraMoonGifts=listOf(gift)) }; assertEquals(5,c.state.changeLog.last().experiences)
        c=edits.change(c) { it.copy(extraMoonGifts=listOf(gift.copy(dots=3))) }; assertEquals(4,c.state.changeLog.last().experiences)
        c=edits.renown(c,Renown.purity,2); assertEquals(2,rules(c.state).moonDots(c.state.extraMoonGifts.single()))
        assertEquals(3,codec.decode(codec.encode(c)).state.extraMoonGifts.single().dots)
        c=edits.change(c) { it.copy(extraMoonGifts=emptyList()) }; assertEquals(-9,c.state.changeLog.last().experiences)
    }
    @Test fun lodgeLoreCostsOutsidersThreeTimesAsMuchAndRefundsWhatWasPaid() {
        var c=hunter(); val merit=Merit(source("lore"),rating=3)
        c=edits.change(c) { it.copy(merits=listOf(merit),rites=listOf(OwnedRite(source("lore-rite")))) }
        assertEquals(listOf(9,9),c.state.changeLog.map { it.experiences })
        c=edits.change(c) { it.copy(lodge=source("adherents")) }
        c=edits.change(c) { it.copy(merits=emptyList()) }; assertEquals(-9,c.state.changeLog.last().experiences)
        c=edits.change(c) { it.copy(merits=listOf(merit.copy(rating=5)),rites=it.rites+OwnedRite(source("other-lore"))) }
        assertEquals(listOf(5,9),c.state.changeLog.takeLast(2).map { it.experiences })
        assertTrue(rules(c.state).prerequisiteChecks(catalog.entry(CatalogKind.merits,"lore")!!).all { it.met == true })
        val field=rules(ForsakenState(primalUrge=3,lodge=source("field")))
        assertEquals(15,field.essenceMaximum)
    }
    @Test fun eraReplacementAffinityAndWerewolfPrerequisitesAreGameSpecific() {
        val c=hunter(); val found=catalog.facet("era-glory")!!
        assertTrue(rules(c.state).hasAffinity(found.gift)); assertEquals(3,rules(c.state).price(found).experiences)
        assertEquals(3,edits.learn(c,found).state.changeLog.last().experiences)
        val checks=rules(c.state).prerequisiteChecks(catalog.entry(CatalogKind.merits,"requires")!!)
        assertEquals(listOf("Cunning 2","Primal Urge 3","Harmony 8"),checks.filter { it.met==false }.map { it.description })
        assertEquals("Only for humans",rules(c.state).meritUnavailableReason(catalog.entry(CatalogKind.merits,"human")!!))
    }
    @Test fun conditionEventsUseSharedBeatsAndPreserveHistoricalKeys() {
        var c=codec.character(ForsakenState(beats=4)); val row=CharacterCondition(source("test-condition"),note="Own",addedAt=10.25)
        c=edits.condition(c,row,ConditionEvent.added,10.25)
        assertEquals(1,c.state.conditions.single().counter)
        assertEquals("condition:test-condition/${row.id.saveKey()}",c.state.changeLog.single().trait)
        assertEquals(1,edits.condition(c,row,ConditionEvent.added).state.conditions.size)
        c=edits.condition(c,c.state.conditions.single(),ConditionEvent.resolved,11.5)
        assertTrue(c.state.conditions.isEmpty()); assertEquals(0,c.state.beats); assertEquals(1,c.state.experiences)
        assertEquals(1,c.state.changeLog.last().beats); assertEquals(11.5,c.state.changeLog.last().date,0.0)
        val noBeat=CharacterCondition(source("no-beat")); c=edits.condition(c,noBeat,ConditionEvent.added)
        c=edits.condition(c,noBeat,ConditionEvent.resolved); assertEquals(0,c.state.beats)
    }
    @Test fun siskurDahGroupsExcludeUnsupportedFactionsAndPreservePlainChoices() {
        val entry=catalog.entry(CatalogKind.conditions,"test-condition")!!
        val groups=rules(ForsakenState()).noteOptionGroups(entry)
        assertEquals(listOf("Forsaken Tribes","Lodges","Pure Tribes"),groups.map { it.title })
        assertFalse(groups.flatMap { it.options }.any { it.name=="Other" }); assertNotNull(groups.last().warning)
        assertEquals(listOf("Pure Tribes","Lodges","Forsaken Tribes"),rules(ForsakenState(tribe=source("pure"))).noteOptionGroups(entry).map { it.title })
        assertEquals(listOf(""),rules(ForsakenState()).noteOptionGroups(catalog.entry(CatalogKind.conditions,"ungrouped")!!).map { it.title })
    }
    @Test fun unknownMechanicsStayAdvisoryAndDoNotChangeNumbers() {
        val s=ForsakenState(facets=listOf(OwnedFacet(source("power-unknown"))))
        assertEquals(6,rules(s).health()); assertEquals(1,rules(s).attribute("strength"))
        assertEquals("Test rule",catalog.facet("power-unknown")!!.facet.summary)
    }
    @Test fun identityEditsResetOnlyTheReferenceFields() {
        val c=codec.character(ForsakenState(auspice=source("seer"),tribe=source("hunters"),moonGift=TraitSource(custom="Mine"),moonFacets=listOf("One"),huntersAspect="Old"))
        val changed=edits.change(c) { it.copy(auspice=source("singer"),tribe=source("pure")) }
        assertNull(changed.state.moonGift); assertEquals("",changed.state.huntersAspect); assertEquals(listOf("One"),changed.state.moonFacets)
    }

    @Test fun customWolfFacetMatchesTheSubmittedSwiftFallbackCost() {
        var c=hunter()
        val custom=OwnedFacet(TraitSource(custom="Test facet"),customKind=GiftKind.wolf)
        c=edits.change(c) { it.copy(facets=listOf(custom)) }
        // Swift facetCost returns furtherFacet (2) when no catalog Gift can be resolved.
        // Keep this behavior until Claude answers the handoff question; do not infer Wolf's catalog price.
        assertEquals(2,c.state.changeLog.last().experiences)
        c=edits.forget(c,custom.id); assertEquals(-2,c.state.changeLog.last().experiences)
    }

    @Test fun specialtiesRenameTheirDependentMeritAndRefundBothWhenRemoved() {
        val actual=catalog; val edit=ForsakenEdits(actual)
        var c=ForsakenCodec(actual).character(ForsakenState(xpMode=true))
        c=edit.specialty(c,"brawl",-1,"","Claws")
        assertEquals(1,c.state.changeLog.single().experiences)
        c=edit.change(c) { it.copy(merits=listOf(Merit(source("specialty-merit"),"Claws",1))) }
        val count=c.state.changeLog.size
        c=edit.specialty(c,"brawl",0,"Claws","Teeth")
        assertEquals("Teeth",c.state.merits.single().qualifier)
        assertEquals(count,c.state.changeLog.size)
        assertSame(c,edit.specialty(c,"brawl",0,"Claws","Stale rename"))
        c=edit.specialty(c,"brawl",0,"Teeth","")
        assertTrue(c.state.merits.isEmpty())
        assertTrue(c.state.skills.single { it.skill=="brawl" }.specialties.isEmpty())
        assertEquals(listOf(-1,-1),c.state.changeLog.takeLast(2).map { it.experiences })
        assertEquals(0,ForsakenRules(c.state,actual).experiencesSpent)
    }
}
