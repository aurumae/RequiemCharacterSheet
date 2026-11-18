package ie.forsaken.rules

import kotlinx.serialization.json.*

/** Fixed, deliberately small mechanics inputs. Live book edits must not redefine these outcomes. */
internal object ForsakenTestCatalog {
    private fun obj(text: String) = Json.parseToJsonElement(text).jsonObject
    private fun row(id: String, extra: String = "{}") = JsonObject(mapOf(
        "id" to JsonPrimitive(id), "name" to JsonPrimitive(id), "summary" to JsonPrimitive("Test rule"),
        "source" to obj("""{"book":"rules-test","page":1}"""),
    ) + obj(extra))
    private fun gift(id: String, kind: String, facets: List<JsonObject>, extra: String = "{}") =
        JsonObject(row(id, extra) + mapOf("kind" to JsonPrimitive(kind), "facets" to JsonArray(facets)))
    val catalog = ForsakenCatalog.fromFiles(mapOf("rules-test.json" to buildJsonObject {
        put("format", "forsaken-catalog"); put("version", 1)
        put("book", obj("""{"id":"rules-test","name":"Test rules"}"""))
        put("auspices", JsonArray(listOf(
            row("seer", """{"renown":"purity","moonGift":"moon","giftAffinities":["affinity"],"benefit":{"name":"Benefit","summary":"Test"},"huntersAspect":{"name":"Watchful","condition":"test-condition"}}"""),
            row("singer", """{"renown":"glory","moonGift":"alternate","giftAffinities":[]}"""),
        )))
        put("tribes", JsonArray(listOf(
            row("hunters", """{"kind":"forsaken","renown":"glory","giftAffinities":["modern"]}"""),
            row("pure", """{"kind":"pure","renown":"glory","giftAffinities":["other"],"huntersAspects":[{"name":"Primal","condition":"instinctive"}]}"""),
        )))
        put("gifts", JsonArray(listOf(
            gift("affinity", "shadow", listOf(row("affinity-cunning", """{"renown":"cunning"}"""), row("affinity-glory", """{"renown":"glory"}"""), row("affinity-purity", """{"renown":"purity"}"""))),
            gift("other", "shadow", listOf(row("other-cunning", """{"renown":"cunning"}"""), row("other-purity", """{"renown":"purity"}"""))),
            gift("locked", "shadow", listOf(row("locked-purity", """{"renown":"purity"}"""))),
            gift("wolf", "wolf", listOf(row("wolf-cunning", """{"renown":"cunning"}"""), row("wolf-purity", """{"renown":"purity"}"""))),
            gift("era", "shadow", listOf(row("era-glory", """{"renown":"glory"}""")), """{"replaces":"modern"}"""),
            gift("moon", "moon", listOf(row("moon-one", """{"dots":1}"""), row("moon-health", """{"dots":2,"passive":true,"effects":[{"type":"health","amount":"rating"}]}"""))),
            gift("alternate", "moon", listOf(row("alternate-one", """{"dots":1}"""))),
            gift("powers", "wolf", listOf(
                row("power-strength", """{"renown":"purity","effects":[{"type":"attribute","attribute":"strength","amount":"rating"}]}"""),
                row("power-speed", """{"renown":"glory","effectForms":["urshul","urhan"],"effects":[{"type":"speed","amount":"rating"}]}"""),
                row("power-passive", """{"renown":"purity","passive":true,"effects":[{"type":"initiative","amount":"rating"},{"type":"willpower","amount":"rating"},{"type":"essenceMaximum","amount":"rating"}]}"""),
                row("power-skill", """{"renown":"purity","effects":[{"type":"skill","skill":"brawl","amount":"rating"}]}"""),
                row("power-unknown", """{"renown":"purity","passive":true,"effects":[{"type":"future-rule","amount":{"fixed":99}}]}"""),
            )),
        )))
        put("merits", JsonArray(listOf(
            row("embodiment-of-the-firstborn"), row("favored-form"), row("fortified-form"), row("instinctive-defense"),
            row("fast", """{"effects":[{"type":"initiative","amount":"rating"}]}"""),
            row("fleet", """{"effects":[{"type":"speed","amount":"rating"}]}"""),
            row("giant", """{"effects":[{"type":"size","amount":{"fixed":1}}]}"""),
            row("defensive", """{"effects":[{"type":"defenseSkillFromQualifier"}]}"""),
            row("lore"), row("human", """{"category":"human"}"""),
            row("requires", """{"prerequisites":[{"kind":"renown","id":"cunning","minimum":2},{"kind":"primalUrge","minimum":3},{"kind":"harmony","minimum":8},{"kind":"auspice","id":"seer"},{"kind":"notTribe","id":"pure"},{"kind":"tribe","id":"hunters"}]}"""),
            row("specialty-merit", """{"qualifier":{"fromSpecialties":true}}"""),
        )))
        put("rites", JsonArray(listOf(
            row("empower", """{"rating":1,"effects":[{"type":"attribute","attribute":"strength","amount":{"fixed":1}},{"type":"attribute","attribute":"dexterity","amount":{"fixed":1}},{"type":"attribute","attribute":"stamina","amount":{"fixed":1}},{"type":"essenceMaximum","amount":{"fixed":5}}]}"""),
            row("armor", """{"rating":3,"effects":[{"type":"armor","amount":{"fixed":2}}]}"""),
            row("lore-rite", """{"rating":3}"""), row("other-lore", """{"rating":3}"""),
        )))
        put("lodges", JsonArray(listOf(
            row("adherents", """{"blessing":"Test blessing","merits":["lore"],"rites":["lore-rite"]}"""),
            row("another", """{"rites":["other-lore"]}"""),
            row("field", """{"benefit":"Test benefit","effects":[{"type":"essenceMaximum","amount":"rating"}]}"""),
            row("story"),
        )))
        put("conditions", JsonArray(listOf(
            row("test-condition", """{"counter":true,"beat":"A Beat","noteOptions":[{"id":"own","name":"Own","summary":"Own effect","group":"forsaken"},{"id":"pure","name":"Pure","summary":"Pure effect","group":"pure"},{"id":"lodge","name":"Lodge","summary":"Lodge effect","group":"lodge"},{"id":"other","name":"Other","summary":"Other effect","group":"excluded"}],"affects":[{"targets":["attribute:stamina"],"text":"A stamina penalty"}]}"""),
            row("no-beat", """{"beatOnResolve":false}"""),
            row("ungrouped", """{"noteOptions":[{"id":"one","name":"One","summary":"One effect"}]}"""),
        )))
        put("kuruthTriggers", JsonArray(listOf(row("blood", """{"passive":"Smell","common":"Taste","specific":"Spill"}"""))))
    }.toString()))
}
