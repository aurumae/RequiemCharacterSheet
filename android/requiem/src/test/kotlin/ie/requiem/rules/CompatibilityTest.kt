package ie.requiem.rules

import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class CompatibilityTest {
    @Test fun declarationsMatchActualReaderAndConditionalWriters() {
        val p = ContractFixtures.platform
        assertEquals(CURRENT_SCHEMA, p.getValue("readSchema").jsonPrimitive.int)
        assertEquals(CatalogKind.entries.map { it.name }.toSet(), p.getValue("catalogKinds").jsonArray.map { it.jsonPrimitive.content }.toSet())
        val catalog = Catalog.bundled(); val codec = CharacterCodec(catalog)
        val blank = CharacterSave()
        val condition = blank.edit(SheetEdit.AddCondition(TraitSource(catalog = "charmed")), catalog)
        val history = condition.edit(SheetEdit.ConditionAction(condition.conditions.single().id, ConditionEvent.ended), catalog)
        val cases = mapOf("plain" to blank, "conditions" to condition, "history" to history,
            "elder" to blank.copy(elderBaneActive = true), "elder-and-conditions" to condition.copy(elderBaneActive = true),
            "elder-off" to blank.copy(elderBaneActive = true).edit(SheetEdit.ElderBane(false), catalog))
        assertEquals(cases.keys, p.getValue("writers").jsonObject.keys)
        for ((name, c) in cases) {
            val fields = Json.parseToJsonElement(codec.encode(c)).jsonObject
            assertEquals(name, p.getValue("writers").jsonObject.getValue(name), fields["schemaVersion"])
            assertEquals(c.elderBaneActive, "elderBaneActive" in fields)
        }
        for (bytes in ContractFixtures.rejectedFiles()) assertThrows(UnsupportedSchema::class.java) { codec.decode(bytes.decodeToString()) }
    }
}
