package ie.requiem.rules

import java.io.File
import java.util.UUID
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class GuidedCreationContractTest {
    private val catalog = Catalog.bundled()
    private val codec = CharacterCodec(catalog)
    private fun id(row: Int) = UUID.fromString("30000000-0000-0000-0000-${row.toString().padStart(12, '0')}")

    @Test fun sharedCreationSequenceMatchesSwiftAndExchangesResumableSaves() {
        val steps = Json.parseToJsonElement(javaClass.getResource("/guided-creation.json")!!.readText()).jsonArray
        val trace = mutableListOf<JsonElement>()
        var c = CharacterSave(creation = CreationState())
        for ((index, element) in steps.withIndex()) {
            val s = element.jsonObject; val before = c
            val action: SheetEdit? = when (s.str("action")) {
                "detail" -> SheetEdit.Detail(CharacterDetail.valueOf(s.str("field")!!), s.str("text")!!)
                "priority" -> SheetEdit.Priority(TraitCategory.valueOf(s.str("category")!!), CreationPriority.entries[s.int("value")], s.flag("skills"))
                "attribute" -> SheetEdit.AttributeRating(s.str("id")!!, s.int("rating"))
                "skill" -> SheetEdit.SkillRating(s.str("id")!!, s.int("rating"))
                "specialty" -> SheetEdit.AddSpecialty(s.str("id")!!, s.str("text")!!)
                "favored" -> SheetEdit.FavoredAttribute(s.str("id")!!)
                "aspiration" -> if (s.int("row") == 0) SheetEdit.AspirationText(c.aspirations.first().id, s.str("text")!!) else SheetEdit.AddAspiration(s.str("text")!!, id(s.int("row")))
                "touchstone" -> SheetEdit.TouchstoneText(s.int("value"), s.str("text")!!)
                "add" -> SheetEdit.AddEntry(EntryKind.valueOf(s.str("kind")!!), TraitSource(catalog = s.str("source")!!), s.str("qualifier"), id = id(s.int("row")))
                "rate" -> SheetEdit.EntryRating(EntryKind.valueOf(s.str("kind")!!), id(s.int("row")), s.int("rating"))
                "number" -> SheetEdit.Number(NumberField.valueOf(s.str("field")!!), s.int("value"))
                "bonus" -> SheetEdit.CreationBonus(s.int("value"))
                "finish" -> SheetEdit.FinishCreation(s.flag("anyway"))
                "check" -> null
                else -> error("Unknown creation action")
            }
            if (action != null) c = c.edit(action, catalog, 800_000_000.25 + index)
            if (s["accepted"] == JsonPrimitive(false)) assertSame("Rejected step $index", before, c)
            c = codec.decode(codec.encode(c))
            s["withinLimits"]?.let { assertEquals("Step $index", it.jsonPrimitive.boolean, c.creationReport(catalog).withinLimits) }
            s["overspend"]?.let { assertEquals("Step $index", it.jsonPrimitive.int, c.creationReport(catalog).overspend) }
            s["done"]?.let { assertEquals("Step $index", it.jsonPrimitive.int, c.creationSteps(catalog).count { step -> step.status == CreationStepStatus.Done }) }
            s["available"]?.let { assertEquals("Step $index", it.jsonPrimitive.int, c.experiencesAvailable) }
            if (c.creation != null) { assertFalse(c.xpMode); assertEquals(0, c.experiences); assertTrue(c.paidDots.isEmpty()); assertTrue(c.changeLog.all { it.duringCreation == true }) }
            trace += trace(c)
            s.str("checkpoint")?.let { checkpoint -> ContractFixtures.exchange("guided-creation.json")?.let { directory ->
                val swift = codec.decode(File(directory, "swift-guided-$checkpoint.json").readText())
                assertEquals("Checkpoint $checkpoint", trace(c), trace(swift))
                File(directory, "kotlin-guided-$checkpoint.json").writeText(codec.encode(c))
            } }
        }
        assertEquals(71, steps.size)
        assertEquals(10, c.experiencesAvailable)
        assertEquals(listOf(4, -4, 0, 5, 0), c.changeLog.takeLast(5).map { it.experiences })
        assertTrue(c.changeLog.dropLast(5).all { it.experiences == 0 && it.duringCreation == true })
        assertTrue(c.changeLog.takeLast(5).all { it.duringCreation == null })
        ContractFixtures.exchange("guided-creation.json")?.let { directory ->
            val swift = Json.parseToJsonElement(File(directory, "swift-guided-trace.json").readText())
            assertEquals(swift, JsonArray(trace))
        }
    }

    private fun trace(c: CharacterSave): JsonObject = buildJsonObject {
        put("attributes", JsonArray(c.attributes.map { JsonPrimitive(it.rating) }))
        put("skills", JsonArray(c.skills.map { JsonPrimitive(it.rating) }))
        put("available", c.experiencesAvailable); put("xpMode", c.xpMode)
        put("costs", JsonArray(c.changeLog.map { JsonPrimitive(it.experiences) }))
        put("creationChanges", JsonArray(c.changeLog.map { it.duringCreation?.let(::JsonPrimitive) ?: JsonNull }))
        put("favored", c.creation?.favoredAttribute?.let(::JsonPrimitive) ?: JsonNull)
        put("bonus", c.creation?.bonusExperiences?.let(::JsonPrimitive) ?: JsonNull)
        if (c.creation == null) put("report", JsonNull) else {
            val r = c.creationReport(catalog)
            putJsonObject("report") {
                fun budgets(b: Map<TraitCategory, CreationBudget>) = JsonArray(TraitCategory.entries.map { category ->
                    val budget = b.getValue(category)
                    JsonArray(listOf(JsonPrimitive(budget.used), JsonPrimitive(budget.allowed), budget.priority?.ordinal?.let(::JsonPrimitive) ?: JsonNull))
                })
                put("attributes", budgets(r.attributes)); put("skills", budgets(r.skills))
                put("specialties", r.specialties.used); put("disciplines", r.disciplines.used); put("merits", r.merits.used)
                put("problems", JsonArray(r.problems.map { it.description }.sorted().map(::JsonPrimitive)))
                put("steps", JsonArray(c.creationSteps(catalog).map { JsonPrimitive(it.status.name) }))
                put("details", JsonArray(c.creationSteps(catalog).map { JsonPrimitive(it.detail) }))
            }
        }
    }
}
