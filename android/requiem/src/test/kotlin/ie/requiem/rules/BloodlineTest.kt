package ie.requiem.rules

import java.io.File
import java.util.UUID
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class BloodlineTest {
    private val catalog = Catalog.bundled()
    private val codec = CharacterCodec(catalog)
    private val source = TraitSource(catalog = "cachexy")
    private val id = UUID.fromString("40000000-0000-0000-0000-000000000001")

    @Test fun spokenPrerequisitesAndHistoryKeepCountsAndDirections() {
        assertEquals("Crúac 2 dots", "Crúac ••".spokenForScreenReader())
        assertEquals("1 to 3", "1 → 3".spokenForScreenReader())
        assertEquals("1 dot to 3 dots", "●–●●●".spokenForScreenReader())
        assertEquals("−3 Experiences", "−3 Experiences".spokenForScreenReader())
    }

    @Test fun legacyAndUnknownBloodlinesMigrateWithoutLosingIdentity() {
        for ((text, expected) in listOf("morbus" to TraitSource(catalog = "morbus"), "Khaibit" to TraitSource(custom = "Khaibit"), "" to TraitSource(custom = ""))) {
            val c = codec.decode("""{"schemaVersion":9,"bloodline":"$text"}""")
            assertEquals(expected, c.bloodline)
            assertNull(codec.encodeEdit(c, c, 800000001.0))
            assertEquals(c.bloodline, codec.decode(codec.encode(c)).bloodline)
        }
        val unknown = codec.decode("""{"schemaVersion":10,"bloodline":{"catalog":"unpublished-bloodline"}}""")
        assertEquals("unpublished-bloodline", codec.decode(codec.encode(unknown)).bloodline.catalog)
        assertEquals(TraitSource(custom = ""), codec.decode("{}").bloodline)
    }

    @Test fun sharedAdvancementPreservesHistoricalPricesAndRestriction() {
        val steps = Json.parseToJsonElement(javaClass.getResource("/bloodline-advancement.json")!!.readText()).jsonArray
        var c = CharacterSave(xpMode = true)
        for ((index, element) in steps.withIndex()) {
            val s = element.jsonObject
            val action = when (s.str("action")) {
                "clan" -> SheetEdit.Detail(CharacterDetail.Clan, s.str("text")!!)
                "bloodline" -> SheetEdit.Detail(CharacterDetail.Bloodline, s.str("text")!!)
                "add" -> SheetEdit.AddEntry(EntryKind.Discipline, source, id = id)
                "rating" -> SheetEdit.EntryRating(EntryKind.Discipline, id, s.int("rating"))
                "remove" -> SheetEdit.RemoveEntry(EntryKind.Discipline, id)
                else -> error("Unknown action")
            }
            c = c.edit(action, catalog, 800000000.25 + index)
            c = codec.decode(codec.encode(c))
            assertEquals(s.int("available"), c.experiencesAvailable)
            assertEquals(s.int("logCount"), c.changeLog.size)
        }
        assertEquals(mapOf(1 to 3, 2 to 3), c.paidDots["discipline:${id.toString().uppercase()}"])
        ContractFixtures.exchange("bloodline-advancement.json")?.let { dir ->
            File(dir, "kotlin-bloodline.json").writeText(codec.encode(c))
            val swift = codec.decode(File(dir, "swift-bloodline.json").readText())
            assertEquals(c.bloodline, swift.bloodline)
            assertEquals(c.paidDots, swift.paidDots)
            assertEquals(c.changeLog.map { it.experiences }, swift.changeLog.map { it.experiences })
            assertEquals(c.disciplines, swift.disciplines)
        }
    }

    @Test fun bloodlineChangesCreationBudgetAndKeepsItsOwnBane() {
        var c = CharacterSave(creation = CreationState(), clan = TraitSource(catalog = "mekhet"))
        assertNotNull(c.catalogOptions(EntryKind.Discipline, catalog).single { it.entry.id == "cachexy" }.blockedReason)
        c = c.edit(SheetEdit.Detail(CharacterDetail.Bloodline, "Morbus"), catalog)
        assertEquals(listOf("auspex", "celerity", "cachexy", "obfuscate"), c.inClanDisciplines(catalog))
        assertNull(c.catalogOptions(EntryKind.Discipline, catalog).single { it.entry.id == "cachexy" }.blockedReason)
        c = c.edit(SheetEdit.AddEntry(EntryKind.Discipline, source, id = id), catalog)
            .edit(SheetEdit.EntryRating(EntryKind.Discipline, id, 3), catalog)
        assertEquals(3, c.disciplineRating("cachexy"))
        assertTrue(c.changeLog.all { it.experiences == 0 && it.duringCreation == true })
        assertEquals("The Unclean Curse", c.bloodlineBane(catalog)?.name)
        assertNotNull(c.clanBane(catalog))
        assertTrue(c.banes.isEmpty())
        c = c.edit(SheetEdit.Detail(CharacterDetail.Clan, "Ventrue"), catalog)
        assertEquals("morbus", c.bloodline.catalog)
        assertEquals(3, c.disciplineRating("cachexy"))
        assertNotNull(c.identityOptions(CharacterDetail.Bloodline, catalog).single { it.entry.id == "morbus" }.warning)
        c = c.edit(SheetEdit.Detail(CharacterDetail.Bloodline, "Khaibit"), catalog)
        assertEquals(listOf("animalism", "dominate", "resilience"), c.inClanDisciplines(catalog))
        assertEquals(3, c.disciplineRating("cachexy"))
    }
}
