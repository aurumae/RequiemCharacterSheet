package ie.requiem.rules

import java.io.File
import java.util.UUID
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class Beta2RulesTest {
    private val catalog = Catalog.bundled()
    private val codec = CharacterCodec(catalog)
    private fun source(id: String) = TraitSource(catalog = id)
    private fun CharacterSave.add(id: String) = edit(SheetEdit.AddCondition(source(id)), catalog, 800_000_000.0)
    private fun CharacterSave.action(event: ConditionEvent, index: Int = 0) = edit(SheetEdit.ConditionAction(conditions[index].id, event), catalog, 800_000_001.0)
    private fun objectOf(c: CharacterSave) = Json.parseToJsonElement(codec.encode(c)).jsonObject

    @Test fun writesTenUntilConditionsOrTheirHistoryNeedEleven() {
        val blank = CharacterSave()
        assertEquals(10, objectOf(blank).getValue("schemaVersion").jsonPrimitive.int)
        assertFalse("conditions" in objectOf(blank))
        val ended = blank.add("charmed").action(ConditionEvent.ended)
        assertEquals(11, objectOf(ended).getValue("schemaVersion").jsonPrimitive.int)
        assertFalse("conditions" in objectOf(ended))
        assertEquals(ended.changeLog, codec.decode(codec.encode(ended)).changeLog)
        assertEquals(11, codec.decode(codec.encode(ended)).savedSchemaVersion)
    }
    @Test fun catalogFlagsAndSourcebookCountsMatchIOS() {
        val entries = catalog.bookEntries(CatalogKind.conditions)
        assertEquals(sourceEntries(CatalogKind.conditions), catalog.entries(CatalogKind.conditions))
        for (id in listOf("distracted", "stumbled")) assertFalse(CharacterCondition(source(id)).info(catalog).beatOnResolve)
        assertTrue(entries.any { it.id == "primeval-truths" && it.bookId == "secrets-of-the-covenants" })
    }
    @Test fun duplicateRulesAndRecentChoicesSurviveRemoval() {
        var c = CharacterSave().add("charmed")
        assertEquals(c, c.add("charmed"))
        c = c.add("swooning").add("swooning")
        assertEquals(3, c.conditions.size)
        c = c.action(ConditionEvent.ended).add("broken").add("confused").add("deprived").add("tempted").add("charmed")
        assertEquals(listOf("charmed", "tempted", "deprived", "confused", "broken"), c.recentConditionIDs(catalog))
        val last = c.conditions.last()
        assertEquals(c, c.edit(SheetEdit.AddCondition(source("swooning"), last.id), catalog))
    }
    @Test fun beatActionsRollOverWithoutChargingXpAndCannotReplayRemovedConditions() {
        val added = CharacterSave(beats = 4, experiences = 3, xpMode = true).add("charmed")
        val beat = added.action(ConditionEvent.beat)
        assertEquals(0, beat.beats); assertEquals(4, beat.experiences)
        assertEquals(1, beat.conditions.size); assertEquals(1, beat.changeLog.last().beats)
        val resolved = beat.action(ConditionEvent.resolved)
        assertEquals(1, resolved.beats); assertTrue(resolved.conditions.isEmpty())
        assertTrue(resolved.paidDots.isEmpty()); assertTrue(resolved.changeLog.all { it.experiences == 0 })
        assertEquals(resolved, resolved.edit(SheetEdit.ConditionAction(added.conditions.single().id, ConditionEvent.resolved), catalog))
        for (id in listOf("distracted", "stumbled")) assertEquals(0, CharacterSave().add(id).action(ConditionEvent.resolved).beats)
        assertEquals(0, CharacterSave().add("charmed").action(ConditionEvent.ended).beats)
    }
    @Test fun effectsAreInformationalAndUnknownTargetsIgnored() {
        val before = CharacterSave()
        val after = before.add("deprived").add("broken").add("confused")
        assertEquals(2, after.conditionEffects("attribute:resolve", catalog).size)
        assertEquals(1, after.conditionEffects("skillCategory:social", catalog).size)
        assertTrue(after.conditionEffects("madeUp:social", catalog).isEmpty())
        assertEquals(before.health(catalog), after.health(catalog)); assertEquals(before.defense(catalog), after.defense(catalog))
        assertEquals(before.totalAttribute("wits", catalog), after.totalAttribute("wits", catalog))
    }
    @Test fun counterNoteAndCustomCardNamesFollowTheLog() {
        var c = CharacterSave().add("tempted")
        val id = c.conditions.single().id
        c = c.edit(SheetEdit.ConditionCounter(id, 30), catalog).edit(SheetEdit.ConditionText(id, ConditionField.Note, "At court"), catalog)
        assertEquals(20, c.conditions.single().counter)
        assertEquals("Tempted −20 (At court)", c.changeName(c.changeLog.first(), catalog))
        c = c.action(ConditionEvent.ended)
        assertEquals("Tempted −20 (At court)", c.changeName(c.changeLog.first(), catalog))
        val custom = UUID.randomUUID()
        c = c.edit(SheetEdit.AddCondition(TraitSource(custom = ""), custom), catalog)
            .edit(SheetEdit.ConditionText(custom, ConditionField.Name, "Haunted"), catalog)
            .edit(SheetEdit.ConditionText(custom, ConditionField.Effect, "Shadows whisper"), catalog)
            .edit(SheetEdit.ConditionText(custom, ConditionField.Resolution, "Face the ghost"), catalog)
            .edit(SheetEdit.ConditionText(custom, ConditionField.Beat, "Listen"), catalog)
            .edit(SheetEdit.ConditionPersistent(custom, true), catalog)
        val decoded = codec.decode(codec.encode(c))
        assertEquals(c.conditions, decoded.conditions)
        assertEquals("Haunted", decoded.changeName(decoded.changeLog.last(), catalog))
        assertTrue(decoded.conditions.single().info(catalog).persistent)
    }
    @Test fun catalogCardsOmitCustomFieldsAndUnknownCatalogIdsSurvive() {
        val c = CharacterSave().add("charmed")
        val fields = objectOf(c).getValue("conditions").jsonArray.single().jsonObject
        assertFalse(fields.keys.any { it.startsWith("custom") })
        val unknown = c.copy(conditions = listOf(c.conditions.single().copy(source = source("future-condition"))))
        assertEquals(unknown.conditions, codec.decode(codec.encode(unknown)).conditions)
        assertFalse(unknown.conditions.single().info(catalog).custom)
    }
    @Test fun specialtyMeritsRequireChoicesAndFollowRenameAndPaidRemoval() {
        val entry = catalog.entry(CatalogKind.merits, "area-of-expertise")!!
        var c = CharacterSave(xpMode = true, experiences = 20)
        assertTrue(c.qualifierChoices(entry, catalog)!!.isEmpty())
        assertEquals(c, c.edit(SheetEdit.AddEntry(EntryKind.Merit, entry.source(), "Rifles"), catalog))
        c = c.edit(SheetEdit.AddSpecialty("firearms", " Rifles "), catalog)
        assertEquals("Rifles (Firearms)", c.specialtyChoices.single().label)
        c = c.edit(SheetEdit.AddEntry(EntryKind.Merit, entry.source(), "Rifles"), catalog)
        assertEquals(18, c.experiencesAvailable)
        c = c.edit(SheetEdit.ReplaceSpecialty("firearms", 0, "Rifles", "Pistols"), catalog)
        assertEquals("Pistols", c.merits.single().qualifier)
        assertEquals(18, c.experiencesAvailable)
        c = c.edit(SheetEdit.ReplaceSpecialty("firearms", 0, "Pistols", ""), catalog)
        assertTrue(c.merits.isEmpty()); assertEquals(20, c.experiencesAvailable)
        assertTrue(c.paidDots.isEmpty())
    }
    @Test fun duplicateSpecialtyNameKeepsItsMeritUntilTheLastNameIsRemoved() {
        var c = CharacterSave().edit(SheetEdit.AddSpecialty("firearms", "Tricks"), catalog)
            .edit(SheetEdit.AddSpecialty("brawl", "Tricks"), catalog)
            .edit(SheetEdit.AddEntry(EntryKind.Merit, source("area-of-expertise"), "Tricks"), catalog)
        assertEquals(1, c.specialtyChoices.size)
        c = c.edit(SheetEdit.ReplaceSpecialty("firearms", 0, "Tricks", "Rifles"), catalog)
        assertEquals("Tricks", c.merits.single().qualifier)
        c = c.edit(SheetEdit.ReplaceSpecialty("brawl", 0, "Tricks", ""), catalog)
        assertTrue(c.merits.isEmpty())
    }
    @Test fun flockAddsUnpaidHerdDotsWithoutChangingItsPurchaseChoices() {
        var c = CharacterSave(xpMode = true, experiences = 20)
            .edit(SheetEdit.AddEntry(EntryKind.Merit, source("herd")), catalog)
            .edit(SheetEdit.AddEntry(EntryKind.Merit, source("flock")), catalog)
        c = c.edit(SheetEdit.EntryRating(EntryKind.Merit, c.merits[0].id, 4), catalog)
            .edit(SheetEdit.EntryRating(EntryKind.Merit, c.merits[1].id, 3), catalog)
        val herd = c.entryRows(EntryKind.Merit, catalog).first()
        assertEquals(4, herd.rating); assertEquals(3, herd.bonus); assertEquals(5, herd.choices.last())
        assertEquals(13, c.experiencesAvailable)
        assertTrue(c.prerequisites(catalog.entry(CatalogKind.merits, "flock")!!, catalog).any { it.met == null })
        val removed = c.edit(SheetEdit.RemoveEntry(EntryKind.Merit, c.merits[1].id), catalog)
        assertEquals(0, removed.meritBonus("herd", catalog)); assertEquals(16, removed.experiencesAvailable)
    }
    @Test fun sourcebookPrerequisitesAndStandaloneCoilCostsAreEnforced() {
        val casual = catalog.entry(CatalogKind.merits, "casual-user")!!
        assertTrue(CharacterSave().prerequisites(casual, catalog).single().met == true)
        assertFalse(CharacterSave(covenant = source("carthian-movement")).prerequisites(casual, catalog).single().met!!)
        val mobilize = catalog.entry(CatalogKind.merits, "mobilize-outrage")!!
        val c = CharacterSave().edit(SheetEdit.AttributeRating("resolve", 3), catalog).edit(SheetEdit.AttributeRating("composure", 2), catalog)
        assertTrue(c.prerequisites(mobilize, catalog).single { it.description == "Willpower 5" }.met!!)
        val blank = CharacterSave(xpMode = true, experiences = 20)
        assertEquals(blank, blank.edit(SheetEdit.Mystery(source("coil-of-ziva")), catalog))
        assertFalse(blank.catalogOptions(EntryKind.Coil, catalog, choosingMystery = true).any { it.entry.coilOnly })
        val added = blank.edit(SheetEdit.AddEntry(EntryKind.Coil, source("coil-of-ziva")), catalog)
        val rated = added.edit(SheetEdit.EntryRating(EntryKind.Coil, added.coils.single().id, 2), catalog)
        assertEquals(12, rated.experiencesAvailable)
        assertEquals(setOf("Secrets of the Covenants"), rated.catalogOptions(EntryKind.Coil, catalog, "Covenants").map { it.group }.toSet())
    }
    @Test fun androidConditionActionsWriteAFileThatSwiftCanContinue() {
        var c = CharacterSave(name = "Beta 2 exchange", beats = 4).add("charmed")
        c = c.edit(SheetEdit.ConditionText(c.conditions.single().id, ConditionField.Note, "Lady Ysolde"), catalog)
            .action(ConditionEvent.beat).action(ConditionEvent.resolved).add("tempted")
        c = c.edit(SheetEdit.ConditionCounter(c.conditions.single().id, 2), catalog)
        val custom = UUID.randomUUID()
        c = c.edit(SheetEdit.AddCondition(TraitSource(custom = "Haunted"), custom), catalog)
            .edit(SheetEdit.ConditionText(custom, ConditionField.Effect, "Shadows whisper"), catalog)
            .edit(SheetEdit.ConditionPersistent(custom, true), catalog)
        assertEquals(1, c.beats); assertEquals(1, c.experiences)
        ContractFixtures.exchange("beta2-play")?.let { File(it, "kotlin-beta2-play.json").writeText(codec.encode(c)) }
    }
}
