package ie.requiem.rules

import org.junit.Assert.*
import org.junit.Test

class CreationRulesTest {
    private val catalog = Catalog.bundled()
    private val codec = CharacterCodec(catalog)
    private fun guided(clan: String = "Daeva") = CharacterSave(creation = CreationState()).edit(SheetEdit.Detail(CharacterDetail.Clan, clan), catalog)
    private fun CharacterSave.change(action: SheetEdit) = edit(action, catalog, 800_000_000.25)
    private fun CharacterSave.attr(id: String, rating: Int) = change(SheetEdit.AttributeRating(id, rating))
    private fun CharacterSave.skill(id: String, rating: Int) = change(SheetEdit.SkillRating(id, rating))
    private fun CharacterSave.priorities(): CharacterSave {
        var c = this
        for (skills in listOf(false, true)) for ((category, priority) in listOf(TraitCategory.Physical to CreationPriority.Primary,
            TraitCategory.Mental to CreationPriority.Secondary, TraitCategory.Social to CreationPriority.Tertiary)) c = c.change(SheetEdit.Priority(category, priority, skills))
        return c
    }
    private fun CharacterSave.add(kind: EntryKind, id: String, qualifier: String? = null) = change(SheetEdit.AddEntry(kind, TraitSource(catalog = id), qualifier))
    private fun CharacterSave.merit(id: String, rating: Int, qualifier: String? = null): CharacterSave {
        val c = add(EntryKind.Merit, id, qualifier)
        return c.change(SheetEdit.EntryRating(EntryKind.Merit, c.merits.last().id, rating))
    }
    private fun CharacterSave.problem(kind: CreationProblemKind) = creationReport(catalog).problems.any { it.kind == kind }

    @Test fun prioritiesGateDotsSwapIndependentlyAndAllowOverspendRepair() {
        var c = guided("")
        assertEquals(listOf(1), c.attributeChoices("wits", catalog))
        assertSame(c, c.attr("wits", 2)); assertSame(c, c.skill("occult", 1))
        c = c.priorities().attr("strength", 5).attr("dexterity", 2).attr("wits", 5)
        assertEquals(5, c.creationReport(catalog).attributes.getValue(TraitCategory.Physical).used)
        assertSame(c, c.attr("stamina", 2))
        c = c.change(SheetEdit.Priority(TraitCategory.Physical, CreationPriority.Tertiary, false))
        assertEquals(mapOf("physical" to 2, "mental" to 1, "social" to 0), c.creation!!.attributePriorities)
        assertEquals(0, c.creation!!.skillPriorities["physical"])
        assertEquals(2, c.creationReport(catalog).overspend)
        assertEquals(CreationStepStatus.Problem, c.creationSteps(catalog)[1].status)
        assertSame(c, c.attr("dexterity", 3))
        c = c.attr("presence", 4) // Another category still has its own budget.
        assertEquals(4, c.attributeRating("presence"))
        c = c.attr("strength", 3)
        assertTrue(c.creationReport(catalog).withinLimits)
        assertSame(c, c.change(SheetEdit.FinishCreation())) // Legal but unfinished needs an explicit decision.
    }

    @Test fun favoredDotMovesIsProtectedAndSurvivesOnlyCompatibleClanChanges() {
        var c = guided().change(SheetEdit.FavoredAttribute("dexterity"))
        assertEquals(2, c.attributeRating("dexterity")); assertEquals(listOf(2), c.attributeChoices("dexterity", catalog))
        assertEquals(0, c.creationReport(catalog).attributes.getValue(TraitCategory.Physical).used)
        assertSame(c, c.attr("dexterity", 1)); assertSame(c, c.change(SheetEdit.FavoredAttribute("strength")))
        c = c.change(SheetEdit.FavoredAttribute("manipulation"))
        assertEquals(1, c.attributeRating("dexterity")); assertEquals(2, c.attributeRating("manipulation"))
        c = c.change(SheetEdit.Detail(CharacterDetail.Clan, "Ventrue"))
        assertNull(c.creation!!.favoredAttribute); assertEquals(1, c.attributeRating("manipulation"))
        c = c.change(SheetEdit.Detail(CharacterDetail.Clan, "Gangrel")).change(SheetEdit.FavoredAttribute("composure")).change(SheetEdit.Detail(CharacterDetail.Clan, "Nosferatu"))
        assertEquals("composure", c.creation!!.favoredAttribute)
        c = c.change(SheetEdit.Detail(CharacterDetail.Clan, "A custom clan"))
        assertNull(c.creation!!.favoredAttribute); assertEquals(1, c.attributeRating("composure"))
        assertTrue(c.changeLog.all { it.duringCreation == true && it.experiences == 0 && !it.xpMode }); assertTrue(c.paidDots.isEmpty())
    }

    @Test fun skillAndSpecialtyBudgetsCountAcrossRowsAndAllowRemoval() {
        var c = guided().priorities().skill("brawl", 5).skill("athletics", 5).skill("stealth", 1)
        assertSame(c, c.skill("weaponry", 1))
        c = c.change(SheetEdit.AddSpecialty("occult", "Ghosts")).change(SheetEdit.AddSpecialty("brawl", "Biting")).change(SheetEdit.AddSpecialty("brawl", "Grappling"))
        assertFalse(c.canAddSpecialty); assertSame(c, c.change(SheetEdit.AddSpecialty("academics", "History")))
        c = c.change(SheetEdit.ReplaceSpecialty("occult", 0, "Ghosts", "Spirits"))
        assertEquals(3, c.creationReport(catalog).specialties.used)
        c = c.change(SheetEdit.ReplaceSpecialty("brawl", 0, "Biting", ""))
        assertTrue(c.canAddSpecialty); assertEquals(2, c.creationReport(catalog).specialties.used)
    }

    @Test fun disciplinesRequireTwoInClanDotsAndSorceryStatus() {
        var c = guided().add(EntryKind.Discipline, "celerity")
        c = c.change(SheetEdit.EntryRating(EntryKind.Discipline, c.disciplines.single().id, 2))
        assertSame(c, c.add(EntryKind.Discipline, "cruac"))
        c = c.merit("covenant-status", 1, "Circle of the Crone").add(EntryKind.Discipline, "cruac")
        assertEquals(3, c.creationReport(catalog).disciplines.used)
        assertSame(c, c.add(EntryKind.Discipline, "vigor"))
        assertSame(c, c.change(SheetEdit.EntryRating(EntryKind.Discipline, c.disciplines.last().id, 2)))
        c = c.add(EntryKind.Ritual, "rigor-mortis")
        assertEquals(1, c.rituals.size)
        assertSame(c, c.add(EntryKind.Ritual, "pangs-of-proserpina"))
        assertSame(c, c.add(EntryKind.Ritual, "cheval"))
        c = c.change(SheetEdit.RemoveEntry(EntryKind.Merit, c.merits.single().id))
        assertTrue(c.problem(CreationProblemKind.SorceryStatus))
        assertSame(c, c.change(SheetEdit.FinishCreation(true)))
        c = c.change(SheetEdit.RemoveEntry(EntryKind.Ritual, c.rituals.single().id)).change(SheetEdit.RemoveEntry(EntryKind.Discipline, c.disciplines.last().id))
        assertTrue(c.creationReport(catalog).withinLimits)
    }

    @Test fun onlyTheChosenCoilCanUseTheThirdDisciplineDot() {
        var c = guided().add(EntryKind.Discipline, "celerity")
        c = c.change(SheetEdit.EntryRating(EntryKind.Discipline, c.disciplines.single().id, 2))
        c = c.change(SheetEdit.Mystery(TraitSource(catalog = "mystery-of-the-wyrm")))
        val coil = c.coils.single().id
        assertSame(c, c.change(SheetEdit.EntryRating(EntryKind.Coil, coil, 1)))
        c = c.merit("covenant-status", 1, "Ordo Dracul").change(SheetEdit.EntryRating(EntryKind.Coil, coil, 1))
        assertEquals(1, c.coils.single().rating)
        assertSame(c, c.change(SheetEdit.EntryRating(EntryKind.Coil, coil, 2)))
        assertSame(c, c.add(EntryKind.Coil, "mystery-of-the-voivode"))
        assertSame(c, c.add(EntryKind.Devotion, "body-of-will")); assertSame(c, c.add(EntryKind.Scale, "day-wake-conditioning"))
        c = c.change(SheetEdit.Mystery(TraitSource(catalog = "mystery-of-the-voivode")))
        assertTrue(c.problem(CreationProblemKind.OtherCoil))
        c = c.change(SheetEdit.EntryRating(EntryKind.Coil, coil, 0))
        assertTrue(c.creationReport(catalog).withinLimits)
    }

    @Test fun meritsHonorPrerequisitesAndGapsAndShareTheirBudgetWithBloodPotency() {
        var c = guided()
        assertSame(c, c.add(EntryKind.Merit, "telepathy")); assertSame(c, c.add(EntryKind.Merit, "attache"))
        c = c.merit("resources", 3)
        c = c.change(SheetEdit.Number(NumberField.BloodPotency, 2))
        assertEquals(8, c.creationReport(catalog).merits.used)
        assertSame(c, c.change(SheetEdit.Number(NumberField.BloodPotency, 3)))
        c = c.merit("covenant-status", 2, "Invictus")
        assertEquals(10, c.creationReport(catalog).merits.used)
        assertSame(c, c.add(EntryKind.Merit, "language"))
        assertSame(c, c.change(SheetEdit.Number(NumberField.Humanity, 8)))
        assertSame(c, c.change(SheetEdit.XpMode(true)))
        c = c.change(SheetEdit.Number(NumberField.BloodPotency, 1))
            .change(SheetEdit.EntryRating(EntryKind.Merit, c.merits.first().id, 2)).priorities()
            .attr("stamina", 3).attr("composure", 3).skill("brawl", 2).skill("streetwise", 2)
            .merit("street-fighting", 2).add(EntryKind.Merit, "iron-skin")
        assertEquals(listOf(0, 2, 4), c.entryRows(EntryKind.Merit, catalog).last().choices)
        c = c.change(SheetEdit.EntryRating(EntryKind.Merit, c.merits.last().id, 3))
        assertEquals(4, c.merits.last().rating)
        c = c.attr("stamina", 1)
        assertTrue(c.problem(CreationProblemKind.MeritPrerequisites))
    }

    @Test fun importedBudgetsAndUnavailableMeritsStayVisibleUntilRepaired() {
        val early = codec.decode(javaClass.getResource("/characters/v9-early-guided.json")!!.readText())
        assertTrue(early.creation!!.attributePriorities.isEmpty())
        assertEquals(early, codec.decode(codec.encode(early)))
        val c = guided().copy(merits = listOf(Merit(TraitSource(catalog = "telepathy"), rating = 0)), humanity = 8, bloodPotency = 4)
        assertTrue(c.problem(CreationProblemKind.UnavailableMerit)); assertTrue(c.problem(CreationProblemKind.Humanity)); assertTrue(c.problem(CreationProblemKind.BloodPotency))
        assertSame(c, c.change(SheetEdit.FinishCreation(true)))
        val fixed = c.change(SheetEdit.RemoveEntry(EntryKind.Merit, c.merits.single().id))
            .change(SheetEdit.Number(NumberField.Humanity, 7)).change(SheetEdit.Number(NumberField.BloodPotency, 1))
        assertTrue(fixed.creationReport(catalog).withinLimits)
    }

    @Test fun finishIsExplicitAwardsOnceAndOnlyLaterPurchasesAreRefunded() {
        var c = guided("Ventrue").priorities().change(SheetEdit.FavoredAttribute("presence")).attr("presence", 4)
        assertTrue(c.creationSteps(catalog)[4].detail.contains("Touchstone on Humanity 7"))
        c = c.change(SheetEdit.TouchstoneText(7, "The family estate"))
        assertFalse(c.creationSteps(catalog)[4].detail.contains("Touchstone"))
        assertSame(c, c.change(SheetEdit.FinishCreation()))
        c = codec.decode(codec.encode(c.change(SheetEdit.CreationBonus(15))))
        assertEquals(0, c.experiences); assertEquals(15, c.creation!!.bonusExperiences)
        val finished = c.change(SheetEdit.FinishCreation(true))
        assertNull(finished.creation); assertTrue(finished.xpMode); assertEquals(15, finished.experiencesAvailable)
        assertSame(finished, finished.change(SheetEdit.FinishCreation(true)))
        val paid = finished.attr("presence", 5)
        assertEquals(11, paid.experiencesAvailable)
        val removed = paid.attr("presence", 1)
        assertEquals(15, removed.experiencesAvailable); assertEquals(-4, removed.changeLog.last().experiences)
        assertNull(removed.changeLog.last().duringCreation)
        val left = c.change(SheetEdit.LeaveCreation)
        assertNull(left.creation); assertFalse(left.xpMode); assertEquals(0, left.experiences)
        assertEquals(c.attributes, left.attributes); assertEquals(c.changeLog, left.changeLog)
    }

    @Test fun pickerPreviewsDoNotMutateTheSheetAndExplainUnavailableEntries() {
        val c = guided()
        val text = codec.encode(c)
        val merits = c.catalogOptions(EntryKind.Merit, catalog)
        assertNotNull(merits.first { it.entry.id == "telepathy" }.blockedReason)
        assertNotNull(merits.first { it.entry.id == "iron-skin" }.blockedReason)
        assertNull(merits.first { it.entry.id == "resources" }.blockedReason)
        assertEquals(text, codec.encode(c))
        assertEquals(listOf(1), c.attributeChoices("stamina", catalog))
        val ordinary = c.change(SheetEdit.LeaveCreation)
        assertNull(ordinary.catalogOptions(EntryKind.Merit, catalog).first { it.entry.id == "telepathy" }.blockedReason)
    }
}
