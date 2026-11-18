package ie.forsaken.rules

import ie.chronicles.core.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class ForsakenSaveTest {
    private val codec = ForsakenCodec()
    private fun fixture(name: String) = javaClass.getResource("/forsaken-v1-$name.json")!!.readText()

    @Test fun aSavedCharacterIsWrittenBackUnchanged() {
        for (name in listOf("play", "creation")) {
            val text = fixture(name)
            assertSameJson(Json.parseToJsonElement(text), Json.parseToJsonElement(codec.encode(codec.decode(text))), name)
        }
    }
    @Test fun thePlayFixtureMeansWhatItSays() {
        val c = codec.decode(fixture("play")).state; val rules = ForsakenRules(c)
        assertEquals(2, rules.spiritRank); assertEquals(3, rules.moonGiftDots)
        assertEquals("Gift of the Blood Moon", rules.moonGiftName)
        assertEquals(6, c.totem.experiencesSpent); assertEquals(3, c.totem.experienceBudget)
        assertEquals(7, rules.attribute("strength", Form.dalu))
        assertEquals(10, rules.attribute("strength", Form.gauru))
        assertEquals(5, rules.attribute("strength", Form.hishu))
        assertEquals(2 to 2, rules.armor(Form.gauru))
        assertEquals(10, rules.experiencesSpent); assertEquals(4, rules.experiencesAvailable)
    }
    @Test fun theCreationFixtureRemainsIntactAndCannotBeEdited() {
        val c = codec.decode(fixture("creation")); val rules = ForsakenRules(c.state)
        assertTrue(rules.isPure); assertEquals("Primal", rules.huntersAspect?.text("name"))
        assertEquals("survival", c.state.creation?.freeSkill)
        assertEquals(listOf(Renown.purity), c.state.creation?.grantedRenown)
        assertThrows(IllegalStateException::class.java) { ForsakenEdits().change(c) { it.copy(name = "Changed") } }
        assertThrows(IllegalStateException::class.java) { codec.encodeEdit(c, codec.character(c.state.copy(name = "Changed")), 12.0) }
        assertNull(codec.encodeEdit(c, c, 12.0))
    }
    @Test fun canonicalOmissionsAndCustomRowsMatchSchemaOne() {
        val c = codec.character(ForsakenState(
            facets = listOf(OwnedFacet(TraitSource(custom = "Howl"), customGift = "Time", customKind = GiftKind.wolf), OwnedFacet(TraitSource(catalog = "strength-primal-strength"))),
            rites = listOf(OwnedRite(TraitSource(custom = "My rite"), customRating = 3), OwnedRite(TraitSource(catalog = "raiment-of-the-storm"), active = true)),
            fetishes = listOf(OwnedFetish(TraitSource(custom = "Knife"), customRating = 2, note = "Spirit")),
            renown = mapOf("glory" to 0, "purity" to 2), renownFacetCredits = mapOf("glory" to 0),
            favoredForm = FavoredForm(listOf(null, "strength"), listOf(FormDrawback())),
        ))
        val raw = Json.parseToJsonElement(codec.encode(c)).jsonObject
        listOf("huntersAspect", "moonGift", "moonFacets", "extraMoonGifts", "totem", "ballisticArmor", "renownFacetCredits", "showsUnofficialContent", "creation").forEach { assertFalse(it, it in raw) }
        assertEquals(setOf("purity"), raw.getValue("renown").jsonObject.keys)
        val facets = raw.getValue("facets").jsonArray
        assertEquals(setOf("id", "source", "customGift", "customKind"), facets[0].jsonObject.keys)
        assertEquals(setOf("id", "source"), facets[1].jsonObject.keys)
        assertEquals(JsonNull, raw.getValue("favoredForm").jsonObject.getValue("attributes").jsonArray[0])
        assertEquals(emptyMap<String, JsonElement>(), raw.getValue("favoredForm").jsonObject.getValue("drawbacks").jsonArray[0].jsonObject)
        assertEquals(6, raw.getValue("healthTrack").jsonArray.size)
        assertEquals(2, raw.getValue("willpowerTrack").jsonArray.size)
    }
    @Test fun sparseNoOpAndForeignOrFutureSavesAreSafe() {
        val text = """{"game":"forsaken","name":"Partial","futureNote":{"anything":true}}"""
        val c = codec.decode(text)
        assertNull(codec.encodeEdit(c, c, 50.0))
        assertThrows(UnsupportedGame::class.java) { codec.decode("""{"game":"requiem"}""") }
        assertThrows(UnsupportedGame::class.java) { codec.decode("{}") }
        assertThrows(UnsupportedSchema::class.java) { codec.decode("""{"game":"forsaken","schemaVersion":2}""") }
    }
}

/** Foundation NSDictionary compares JSON numbers by value (800000000 and 800000000.0 are equal). */
internal fun assertSameJson(expected: JsonElement, actual: JsonElement, path: String = "root") {
    when {
        expected is JsonObject && actual is JsonObject -> {
            assertEquals("$path keys", expected.keys, actual.keys)
            expected.forEach { (key, value) -> assertSameJson(value, actual.getValue(key), "$path/$key") }
        }
        expected is JsonArray && actual is JsonArray -> {
            assertEquals("$path length", expected.size, actual.size)
            expected.forEachIndexed { index, value -> assertSameJson(value, actual[index], "$path/$index") }
        }
        expected is JsonPrimitive && actual is JsonPrimitive && !expected.isString && !actual.isString &&
            expected.content.toBigDecimalOrNull() != null && actual.content.toBigDecimalOrNull() != null ->
            assertEquals(path, 0, expected.content.toBigDecimal().compareTo(actual.content.toBigDecimal()))
        else -> assertEquals(path, expected, actual)
    }
}
