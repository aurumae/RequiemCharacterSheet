package ie.forsaken.rules

import ie.chronicles.core.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class ForsakenReaderTest {
    private val catalog = ForsakenCatalog.bundled
    private val codec = ForsakenPreviewCodec(catalog)
    private fun fixture(name: String) = javaClass.getResource("/forsaken-v1-$name.json")!!.readText()

    @Test fun submittedFixturesCoverEverySchemaOneFieldAndRawSnapshotRetainsThem() {
        val keys = setOf("play", "creation").flatMap { name ->
            val saved = Json.parseToJsonElement(fixture(name)).jsonObject
            val c = codec.decode(fixture(name))
            assertEquals(saved, Json.parseToJsonElement(codec.encode(c)))
            assertEquals(1, c.state.schemaVersion)
            saved.keys
        }.toSet()
        val descriptor = ForsakenState.serializer().descriptor
        assertEquals(keys, (0 until descriptor.elementsCount).map(descriptor::getElementName).toSet())
        val swift = File(System.getProperty("swiftModel")).readText()
            .substringAfter("enum CodingKeys:").substringAfter("case ").substringBefore('}')
        assertEquals(keys, swift.split(',').map(String::trim).filter(String::isNotEmpty).toSet())
    }

    /** Stored facts from SaveFormatTests.thePlayFixtureMeansWhatItSays. Effective ratings/XP wait for phase 3. */
    @Test fun thePlayFixtureKeepsAllStoredFactsWithoutApplyingRules() {
        val c = codec.decode(fixture("play")).state
        assertEquals("Mara Voss", c.name)
        assertEquals("Cahalith", catalog.name(CatalogKind.auspices, c.auspice))
        assertEquals("Blood Talons", catalog.name(CatalogKind.tribes, c.tribe))
        assertEquals("garm", c.lodge.catalog)
        assertEquals(TraitSource(catalog = "challenger"), c.blood)
        assertEquals(TraitSource(custom = "Stray"), c.bone)
        assertEquals(Form.dalu, c.form)
        assertEquals(3, c.attributes.single { it.attribute == "strength" }.rating)
        assertEquals(mapOf("glory" to 3, "purity" to 1, "cunning" to 1), c.renown)
        assertEquals(TraitSource(custom = "Gift of the Blood Moon"), c.moonGift)
        assertEquals(listOf("Red Howl", "Tide of Blood", "Hunter's Eclipse"), c.moonFacets)
        assertEquals(listOf(2, 1), c.extraMoonGifts.map { it.dots })
        assertEquals(5, c.facets.size)
        assertEquals(listOf("Primal Strength"), c.facets.filter { it.active }.map { catalog.facet(it.source.catalog)!!.facet.name })
        assertEquals(1, c.facets.count { it.withRenown })
        assertEquals(mapOf("honor" to 1), c.renownFacetCredits)
        assertEquals(listOf(1, 2), c.rites.map { catalog.entry(CatalogKind.rites, it.source.catalog)?.number("rating") ?: it.customRating })
        assertEquals(listOf("Two uses left", "A spirit of feedback"), c.fetishes.map { it.note })
        assertEquals(9, c.totem.packPoints)
        assertTrue(c.totem.advantages.isNotEmpty())
        assertEquals(listOf(Damage.lethal, Damage.bashing), c.healthTrack.take(2))
        assertEquals(listOf(TraitSource(catalog = "siskur-dah"), TraitSource(custom = "Hoarse")), c.conditions.map { it.source })
        assertEquals(mapOf(3 to 3), c.paidDots["renown:glory"])
        assertEquals(mapOf(1 to 5, 2 to 2), c.paidDots[c.changeLog[2].trait])
        assertEquals(5, c.changeLog.size)
        assertTrue(c.changeLog.first().duringCreation == true)
        assertEquals(ConditionEvent.resolved, c.changeLog.last().event)
        assertEquals(1, c.changeLog.last().beats)
        assertTrue(c.showsUnofficialContent && c.xpMode && c.creation == null)
        assertEquals(listOf("strength"), c.favoredForm.attributes)
        assertEquals(null, c.favoredForm.drawbacks.last().attribute)
    }

    /** Preserve the submitted creation example, including the grants awaiting Claude's clarification. */
    @Test fun theCreationFixtureIsReadWithoutGrantingOrCorrectingAnything() {
        val c = codec.decode(fixture("creation")).state
        assertEquals("Ash", c.name)
        assertEquals("predator-kings", c.tribe.catalog)
        assertEquals("Primal", c.huntersAspect)
        assertEquals(mapOf("physical" to 0, "social" to 2), c.creation!!.attributePriorities)
        assertEquals("survival", c.creation.freeSkill)
        assertEquals(listOf(Renown.purity), c.creation.grantedRenown)
        assertEquals("Being chained", c.kuruthTriggers.specific)
        assertEquals(null, c.kuruthTriggerSet.catalog)
        assertEquals(1, c.skills.single { it.skill == "survival" }.rating)
        assertEquals(2, c.merits.single { it.source.catalog == "totem" }.rating)
        assertFalse(ForsakenSection.MoonGifts in ForsakenSection.available(c, catalog))
    }

    @Test fun missingAndNullFieldsUseTheReferenceDefaultsAndNeverClampSavedValues() {
        val c = codec.decode("""{"game":"forsaken","name":"Partial","attributes":null,"primalUrge":13,"essence":99,"totem":{},"favoredForm":{"attributes":[null],"drawbacks":[{}]}}""").state
        assertEquals(9, c.attributes.size)
        assertTrue(c.attributes.all { it.rating == 1 })
        assertEquals(24, c.skills.size)
        assertEquals(7, c.harmony)
        assertEquals(13, c.primalUrge)
        assertEquals(99, c.essence)
        assertEquals(listOf<String?>(null), c.favoredForm.attributes)
        assertEquals(listOf(FormDrawback()), c.favoredForm.drawbacks)
        assertEquals(Totem(), c.totem)
        assertEquals(1, c.aspirations.size)
    }

    @Test fun namesRelinkForReadingButTheirSavedRepresentationIsUnchanged() {
        val text = """{"game":"forsaken","name":"Names","auspice":{"custom":"cáhalith"},"merits":[{"source":{"custom":"Language ( French )"},"rating":1}],"conditions":[{"source":{"custom":"Shaken"}}]}"""
        val c = codec.decode(text)
        assertEquals("cahalith", c.state.auspice.catalog)
        assertEquals("language", c.state.merits.single().source.catalog)
        assertEquals("French", c.state.merits.single().qualifier)
        assertEquals("shaken", c.state.conditions.single().source.catalog)
        assertEquals(Json.parseToJsonElement(text).jsonObject, Json.parseToJsonElement(codec.encode(c)).jsonObject - "id")
    }

    @Test fun unknownDataSurvivesAndThePreviewRefusesToWriteAnEditedCharacter() {
        val raw = Json.parseToJsonElement(fixture("play")).jsonObject.toMutableMap()
        raw["futureNote"] = Json.parseToJsonElement("""{"nested":[null,1,"keep"]}""")
        val c = codec.decode(JsonObject(raw).toString())
        assertEquals(raw, Json.parseToJsonElement(codec.encode(c)).jsonObject)
        assertNull(codec.encodeEdit(c, c, 10.0))
        assertThrows(IllegalStateException::class.java) { codec.encodeEdit(c, codec.decode(fixture("creation")), 10.0) }
    }

    @Test fun viewerRowsExposeSavedStateAndNeverLabelBaseRatingsAsEffective() {
        val c = codec.decode(fixture("play")).state
        val rows = previewRows(c, catalog)
        assertEquals(rows.size, rows.map { it.key }.toSet().size)
        assertEquals(3, rows.single { it.section == ForsakenSection.Attributes && it.title == "Strength" }.rating)
        assertTrue(rows.any { it.title.contains("Bonuses are not included") })
        assertFalse(rows.any { it.title == "Spirit Rank" || it.title == "Available Experiences" })
        assertTrue(rows.any { it.title == "Primal Strength" && it.value.contains("Active (saved)") && it.value.contains("Learned with Renown") })
        assertTrue(rows.any { it.title == "Hoarse" && it.value.contains(c.conditions.last().customEffect) })
        assertTrue(rows.any { it.title == "Recorded purchases" })
        assertTrue(rows.any { it.title == "Saved free Facets" })
    }
}
