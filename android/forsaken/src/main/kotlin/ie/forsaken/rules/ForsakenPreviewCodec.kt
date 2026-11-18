package ie.forsaken.rules

import ie.chronicles.core.*
import java.util.Locale
import java.util.UUID
import kotlinx.serialization.json.*

/** Reader and raw-transfer adapter only. Do not enroll this as a canonical schema-1 writer. */
class ForsakenPreviewCodec(private val catalog: ForsakenCatalog = ForsakenCatalog.bundled) : SheetCodec<ForsakenCharacter> {
    override val currentSchema = 1
    private val json = Json { ignoreUnknownKeys = true }

    override fun requireGame(fields: JsonObject) {
        val game = fields["game"] as? JsonPrimitive
        if (game?.isString != true || game.content != "forsaken") throw UnsupportedGame(game?.content ?: "requiem")
    }

    override fun decode(text: String, fileId: UUID?): ForsakenCharacter {
        val raw = json.parseToJsonElement(text).jsonObject
        requireGame(raw)
        raw["schemaVersion"]?.takeUnless { it == JsonNull }?.let {
            require(it is JsonPrimitive && !it.isString && it.intOrNull != null) { "Invalid schema version" }
            if (it.int > currentSchema) throw UnsupportedSchema(it.int)
        }
        // Swift's decode(default:) treats a null like an absent field. Array nulls (Favored Form) are significant.
        val values = withoutNullFields(raw).jsonObject.toMutableMap()
        if ("id" !in values && fileId != null) values["id"] = JsonPrimitive(fileId.toString())
        val now = JsonPrimitive(foundationNow())
        values.putIfAbsent("createdAt", now)
        values.putIfAbsent("modifiedAt", now)
        val saved = json.decodeFromJsonElement<ForsakenState>(JsonObject(values))
        require(listOf(saved.createdAt, saved.modifiedAt).all(Double::isFinite))
        fun relink(kind: CatalogKind, source: TraitSource) = source.custom?.let { catalog.index(kind).source(it) } ?: source
        val state = saved.copy(
            blood = relink(CatalogKind.archetypes, saved.blood), bone = relink(CatalogKind.archetypes, saved.bone),
            auspice = relink(CatalogKind.auspices, saved.auspice), tribe = relink(CatalogKind.tribes, saved.tribe),
            lodge = relink(CatalogKind.lodges, saved.lodge),
            merits = saved.merits.map { merit ->
                // Shared Swift Merit.relink also extracts a trailing qualifier from a custom name.
                val name = merit.source.custom
                if (name == null) merit else {
                    val index = catalog.index(CatalogKind.merits)
                    val exact = index.source(name)
                    val opening = name.lastIndexOf('(')
                    val qualifier = if (name.endsWith(')') && opening >= 0) name.substring(opening + 1, name.length - 1).trim() else ""
                    val base = if (qualifier.isNotEmpty()) index.source(name.substring(0, opening).trim()) else exact
                    when {
                        exact.catalog != null -> merit.copy(source = exact, qualifier = null)
                        base.catalog != null && qualifier.isNotEmpty() -> merit.copy(source = base, qualifier = qualifier)
                        else -> merit.copy(qualifier = null)
                    }
                }
            },
            conditions = saved.conditions.map { it.copy(source = relink(CatalogKind.conditions, it.source)) },
            renown = saved.renown.filterKeys { key -> Renown.entries.any { it.name == key } },
            renownFacetCredits = saved.renownFacetCredits.filterKeys { key -> Renown.entries.any { it.name == key } },
            facets = saved.facets.filter { catalog.facet(it.source.catalog)?.gift?.text("kind") != "moon" },
        )
        return ForsakenCharacter(state, raw)
    }

    override fun encode(character: ForsakenCharacter): String = JsonObject(character.original.toMutableMap().apply {
        // Normalize identity for duplicate comparison; actual exports use the untouched document bytes.
        // A partial file without identity receives only this field when first imported.
        put("id", JsonPrimitive(character.id.toString().uppercase(Locale.ROOT)))
    }).toString()

    override fun encodeEdit(original: ForsakenCharacter, edited: ForsakenCharacter, at: Double): String? {
        check(original === edited) { "Forsaken preview characters are read-only" }
        return null
    }
}

private fun withoutNullFields(value: JsonElement): JsonElement = when (value) {
    is JsonObject -> JsonObject(value.filterValues { it != JsonNull }.mapValues { withoutNullFields(it.value) })
    is JsonArray -> JsonArray(value.map(::withoutNullFields))
    else -> value
}
