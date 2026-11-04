package ie.requiem.rules

import java.io.File
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class SaveContractTest {
    @Test fun tappingTheSameDotTwiceDoesNotReplayAPurchase() {
        val blank = CharacterSave(xpMode = true)
        val bought = blank.edit(SheetEdit.StaminaRating(4), catalog)
        assertEquals(listOf(12), bought.changeLog.map { it.experiences })
        assertSame(bought, bought.edit(SheetEdit.StaminaRating(4), catalog))
        val lowered = bought.edit(SheetEdit.StaminaRating(2), catalog)
        assertEquals(listOf(12, -8), lowered.changeLog.map { it.experiences })
        assertEquals(mapOf(2 to 4), lowered.paidDots["attribute:stamina"])
        // An absolute tap uses the latest state even before the next Compose frame.
        assertEquals(1, lowered.edit(SheetEdit.StaminaRating(1), catalog).stamina)
    }

    @Test fun staminaAdvancementMatchesTheSwiftEditor() {
        val steps = Json.parseToJsonElement(javaClass.getResource("/stamina-advancement.json")!!.readText()).jsonArray
        var c = CharacterSave()
        steps.forEachIndexed { index, element ->
            val step = element.jsonObject
            fun number(key: String) = step.getValue(key).jsonPrimitive.int
            c = c.edit(SheetEdit.XpMode(step.getValue("xpMode").jsonPrimitive.boolean), catalog)
                .edit(SheetEdit.Stamina(number("delta")), catalog)
            c = codec.decode(codec.encode(c))
            assertEquals(number("rating"), c.stamina)
            assertEquals(index + 1, c.changeLog.size)
            assertEquals(number("cost"), c.changeLog.last().experiences)
            assertEquals(number("available"), c.experiencesAvailable)
            assertEquals(step.getValue("paidLevels").jsonArray.map { it.jsonPrimitive.int },
                c.paidDots["attribute:stamina"].orEmpty().keys.sorted())
        }
    }

    private val catalog = Catalog.bundled()
    private val codec = CharacterCodec(catalog)

    private fun fixture(name: String): String =
        requireNotNull(javaClass.getResourceAsStream("/characters/$name.json")).bufferedReader().use { it.readText() }

    @Test fun sharedExamplesAgreeOnDerivedValues() {
        val cases = requireNotNull(javaClass.getResourceAsStream("/expected-values.json")).bufferedReader().use {
            Json.parseToJsonElement(it.readText()).jsonObject
        }
        for ((name, metrics) in cases) {
            val c = codec.decode(fixture(name))
            val expected = metrics.jsonObject
            assertEquals(name, expected.getValue("health").jsonPrimitive.int, c.health(catalog))
            assertEquals(name, expected.getValue("willpower").jsonPrimitive.int, c.willpower)
            assertEquals(name, expected.getValue("availableXP").jsonPrimitive.int, c.experiencesAvailable)
            assertEquals(name, expected.getValue("guided").jsonPrimitive.boolean, c.creation != null)
        }
    }

    @Test fun readsAllBooksAndResolvesNamesAsSwiftDoes() {
        assertEquals(setOf("vtr2e-core", "cofd-core", "thousand-years-of-night"), catalog.books.keys)
        assertTrue(CatalogKind.entries.all { catalog.entries(it).isNotEmpty() })
        System.getProperty("exchangeDir")?.let { path ->
            val expected = Json.decodeFromString<Map<String, List<String>>>(File(path, "catalog-ids.json").readText())
            val actual = CatalogKind.entries.associate { it.name to catalog.entries(it).keys.toList() } +
                ("books" to catalog.books.keys.toList())
            assertEquals(expected, actual)
        }
        assertEquals("cruac", catalog.source(CatalogKind.disciplines, "Cruac").catalog)
        assertEquals("ritual", catalog.entries(CatalogKind.disciplines).getValue("cruac")["kind"]?.jsonPrimitive?.content)
        assertEquals("gargoyles-vigilance-advanced", catalog.source(CatalogKind.devotions, "Gargoyle’s Vigilance (Advanced)").catalog)
        assertNotNull(catalog.entries(CatalogKind.rituals)["blandishment-of-sin-advanced"])
        assertEquals("akhud", catalog.source(CatalogKind.clans, "THE AKHUD").catalog)
    }

    @Test fun coreWinsEvenWhenLoadedAfterAnotherBook() {
        fun book(name: String) = """{"format":"requiem-catalog","version":1,"book":{"id":"book","name":"Test"},"merits":[{"id":"same","name":"$name"}]}"""
        val books = Catalog(mapOf("a.json" to book("Reprint"), "vtr2e-core.json" to book("Core")))
        assertEquals("same", books.source(CatalogKind.merits, "Core").catalog)
        assertEquals("Reprint", books.source(CatalogKind.merits, "Reprint").custom)
    }

    @Test fun migratesNamedTraitsAndLegacyBoxes() {
        val character = codec.decode(fixture("v1-unversioned"))
        assertEquals("daeva", character.clan.catalog)
        assertEquals("defensive-combat", character.merits.single().source.catalog)
        assertEquals("Brawl", character.merits.single().qualifier)
        assertEquals("Cannot cross running water", character.banes.single().source.custom)
        assertEquals(listOf("Grappling"), character.skills.single { it.skill == "brawl" }.specialties)
        assertEquals(Damage.bashing, character.healthTrack.first())
        assertEquals(WillpowerMark.spent, character.willpowerTrack.first())
        assertEquals(true, character.clanBaneActive)
        assertEquals(24, character.skills.size)
        // These versions changed one part of the unversioned shape at a time.
        val old = Json.parseToJsonElement(fixture("v1-unversioned")).jsonObject.toMutableMap()
        for (version in 2..5) {
            old["schemaVersion"] = JsonPrimitive(version)
            when (version) {
                2 -> {
                    old["id"] = JsonPrimitive(character.id.toString())
                    old["createdAt"] = JsonPrimitive(100.25)
                    old["modifiedAt"] = JsonPrimitive(101.5)
                }
                3 -> {
                    old.remove("healthBoxes")
                    old["healthTrack"] = JsonArray(listOf(JsonPrimitive("lethal")))
                }
                4 -> old["skills"] = Json.parseToJsonElement("""[{"skill":"troupe-skill","rating":2,"specialties":["Custom"]}]""")
                5 -> old["clan"] = Json.parseToJsonElement("""{"catalog":"unknown-clan"}""")
            }
            val decoded = codec.decode(JsonObject(old).toString())
            assertEquals(character.id, decoded.id)
            assertEquals(101.5, decoded.modifiedAt, 0.0)
            assertEquals(if (version >= 3) Damage.lethal else Damage.bashing, decoded.healthTrack.first())
            if (version >= 4) assertEquals("troupe-skill", decoded.skills.last().skill)
            if (version == 5) assertEquals("unknown-clan", decoded.clan.catalog)
            assertNull(codec.encodeEdit(decoded, decoded, at = 500.0))
        }
    }

    @Test fun openingAnOldSaveKeepsItsTimestampAndDoesNotRequestAWrite() {
        for (name in listOf("v6-clan-bane", "v7-sorcery", "v8-paid", "v9-early-guided")) {
            val text = fixture(name)
            val c = codec.decode(text)
            assertNull(codec.encodeEdit(c, c, at = 800_000_100.0))
            assertEquals(Json.parseToJsonElement(text).jsonObject.getValue("modifiedAt").jsonPrimitive.double, c.modifiedAt, 0.0)
            System.getProperty("exchangeDir")?.let { directory ->
                val edited = c.copy(name = c.name + " (edited on Android)")
                File(directory, "kotlin-$name.json").writeText(requireNotNull(codec.encodeEdit(c, edited, 800_000_002.875)))
            }
            when (name) {
                "v6-clan-bane" -> assertTrue(c.rituals.isEmpty() && !c.clanBaneActive)
                "v7-sorcery" -> {
                    assertEquals(2, c.rituals.size)
                    assertEquals(c.experiences, c.experiencesAvailable)
                }
                "v8-paid" -> assertTrue(c.xpMode && c.paidDots.isNotEmpty() && c.creation == null)
                "v9-early-guided" -> assertEquals(CreationState(), c.creation)
            }
        }
    }

    @Test fun exchangesCurrentCharactersAndPreservesHiddenState() {
        val exchange = System.getProperty("exchangeDir")?.let(::File)
        for (name in listOf("v9-advanced", "v9-guided")) {
            val text = exchange?.resolve("swift-$name.json")?.readText() ?: fixture(name)
            val original = codec.decode(text)
            if (name == "v9-advanced") {
                val merit = original.merits.single { it.source.catalog == "defensive-combat" }
                val key = "merit:" + merit.id.toString().uppercase()
                assertEquals(1, original.paidDots[key]?.get(1))
                assertEquals(key, original.changeLog.last().trait)
                assertEquals(-1, original.experiencesAvailable)
                assertEquals(2, original.rituals.size)
                assertEquals("Unpublished power", original.devotions.last().source.custom)
            } else {
                assertEquals("presence", original.creation?.favoredAttribute)
                assertEquals(0, original.creation?.attributePriorities?.get("social"))
                assertEquals(1, original.creation?.skillPriorities?.get("physical"))
                assertEquals(true, original.changeLog.last().duringCreation)
                assertEquals("Keeper of the accounts", original.touchstones.single { it.level == 7 }.text)
            }
            val edited = original.copy(name = original.name + " (edited on Android)")
            val written = requireNotNull(codec.encodeEdit(original, edited, at = 800_000_002.875))
            assertEquals(edited.copy(modifiedAt = 800_000_002.875), codec.decode(written))
            exchange?.resolve("kotlin-$name.json")?.writeText(written)
        }
    }

    @Test fun newSheetsEncodeTheSameDefaultTracksAndOlderInputsNormalize() {
        val newFile = codec.encode(CharacterSave())
        val newSheet = codec.decode(newFile)
        System.getProperty("exchangeDir")?.let { File(it, "kotlin-blank.json").writeText(newFile) }
        assertEquals(List(6) { Damage.none }, newSheet.healthTrack)
        assertEquals(List(2) { WillpowerMark.none }, newSheet.willpowerTrack)
        val sparse = codec.decode("""{"bloodPotency":2,"currentVitae":50,"disciplines":[{"name":"Resilience","rating":2}],
            "merits":[{"name":"Giant","rating":3}],"attributes":[{"name":"Stamina","rating":8}]}""")
        assertEquals(5, sparse.attributes.single { it.attribute == "stamina" }.rating)
        assertEquals(11, sparse.currentVitae)
        assertEquals(13, codec.decode(codec.encode(sparse)).healthTrack.size)
    }

    @Test fun futureAndDamagedSavesCannotEnterTheEditPath() {
        assertEquals(10, assertThrows(UnsupportedSchema::class.java) { codec.decode(fixture("v10-future")) }.version)
        assertThrows(IllegalArgumentException::class.java) { codec.decode("""{"id":"broken"}""") }
        assertThrows(IllegalArgumentException::class.java) { codec.decode("""{"healthTrack":["lost"]}""") }
        assertThrows(IllegalArgumentException::class.java) { codec.decode("""{"paidDots":{"broken":{"1":3}}}""") }
        assertThrows(IllegalArgumentException::class.java) { codec.decode("""{"creation":{"favoredAttribute":"unknown"}}""") }
    }
}
