package ie.forsaken.rules

import ie.chronicles.core.*
import java.util.UUID
import kotlinx.serialization.json.*

/** Canonical schema-1 writer. Untouched imports are exported by CharacterStore as their original bytes. */
class ForsakenCodec(private val catalog: ForsakenCatalog = ForsakenCatalog.bundled) : SheetCodec<ForsakenCharacter> {
    private val reader = ForsakenPreviewCodec(catalog)
    private val json = Json { encodeDefaults = true; explicitNulls = false }
    override val currentSchema = 1
    override fun requireGame(fields: JsonObject) = reader.requireGame(fields)
    override fun decode(text: String, fileId: UUID?) = reader.decode(text, fileId)
    fun character(state: ForsakenState = ForsakenState()) = ForsakenCharacter(state, buildJsonObject {})
    override fun encode(character: ForsakenCharacter): String = encodeState(character.state)
    fun encodeState(state: ForsakenState): String {
        val rules = ForsakenRules(state, catalog)
        val normalized = state.copy(game = "forsaken", schemaVersion = 1,
            renown = state.renown.filterValues { it > 0 }, renownFacetCredits = state.renownFacetCredits.filterValues { it > 0 },
            healthTrack = state.healthTrack.foldedHealth(rules.health()),
            willpowerTrack = state.willpowerTrack.visibleTrack(rules.willpower, WillpowerMark.none))
        val fields = json.encodeToJsonElement(normalized).jsonObject.toMutableMap()
        fun omit(key: String, whenTrue: Boolean) { if (whenTrue) fields.remove(key) }
        omit("huntersAspect", state.huntersAspect.isEmpty())
        omit("kuruthTriggers", state.kuruthTriggerSet.catalog != null)
        omit("moonFacets", state.moonFacets.isEmpty())
        omit("extraMoonGifts", state.extraMoonGifts.isEmpty())
        omit("totem", state.totem == Totem())
        omit("ballisticArmor", state.ballisticArmor == 0)
        omit("renownFacetCredits", normalized.renownFacetCredits.isEmpty())
        omit("favoredForm", state.favoredForm == FavoredForm())
        omit("showsUnofficialContent", !state.showsUnofficialContent)
        fun rows(key: String, transform: (MutableMap<String, JsonElement>, Boolean) -> Unit) {
            val values = fields[key] as? JsonArray ?: return
            fields[key] = JsonArray(values.map { element ->
                val row = element.jsonObject.toMutableMap()
                transform(row, (row["source"] as? JsonObject)?.containsKey("catalog") == true)
                JsonObject(row)
            })
        }
        rows("conditions") { row, linked -> if (linked) row.keys.removeAll(setOf("customEffect", "customResolution", "customBeat", "customPersistent")) }
        rows("facets") { row, linked ->
            if (linked) row.keys.removeAll(setOf("customGift", "customKind"))
            if (row["active"] == JsonPrimitive(false)) row.remove("active")
            if (row["withRenown"] == JsonPrimitive(false)) row.remove("withRenown")
        }
        rows("extraMoonGifts") { row, linked -> if (linked || row["facets"] == JsonArray(emptyList())) row.remove("facets") }
        rows("rites") { row, linked ->
            if (linked) row.remove("customRating")
            if (row["active"] == JsonPrimitive(false)) row.remove("active")
        }
        rows("fetishes") { row, linked ->
            if (linked) row.remove("customRating")
            if (row["note"] == JsonPrimitive("")) row.remove("note")
        }
        return JsonObject(fields).toString()
    }
    override fun encodeEdit(original: ForsakenCharacter, edited: ForsakenCharacter, at: Double): String? {
        require(original.id == edited.id)
        if (original.state == edited.state.copy(modifiedAt = original.modifiedAt)) return null
        check(original.state.creation == null && edited.state.creation == null) { "Guided creation saves remain read-only until phase 4." }
        return encodeState(edited.state.copy(modifiedAt = at))
    }
}
