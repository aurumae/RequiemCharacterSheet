package ie.requiem.rules

import kotlinx.serialization.json.*
import ie.chronicles.core.mergeTraits as merge
import ie.chronicles.core.visibleTrack

class UnsupportedSchema(val version: Int) : IllegalArgumentException("Unsupported character schema $version")

class CharacterCodec(private val catalog: Catalog) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; explicitNulls = false }

    fun decode(text: String, fileId: java.util.UUID? = null): CharacterSave {
        val input = json.parseToJsonElement(text).jsonObject
        val version = input["schemaVersion"]?.takeUnless { it == JsonNull }?.let {
            require(!it.jsonPrimitive.isString) { "schemaVersion must be a number" }
            it.jsonPrimitive.int
        } ?: 1
        if (version !in 1..CURRENT_SCHEMA) throw UnsupportedSchema(version)
        val fields = input.filterValues { it != JsonNull }.toMutableMap()
        // The oldest payloads did not carry an ID; keep the library filename as their identity.
        if (fileId != null) fields.putIfAbsent("id", JsonPrimitive(fileId.toString()))
        fields["schemaVersion"] = JsonPrimitive(CURRENT_SCHEMA)
        if ("createdAt" !in fields || "modifiedAt" !in fields) {
            val now = JsonPrimitive(foundationNow())
            fields.putIfAbsent("createdAt", now)
            fields.putIfAbsent("modifiedAt", now)
        }
        fields["creation"]?.let { fields["creation"] = JsonObject(it.jsonObject.filterValues { value -> value != JsonNull }) }
        migrateTraits(fields)
        migrateTracks(fields)
        val character = json.decodeFromJsonElement<CharacterSave>(JsonObject(fields))
        val threshold = catalog.entries(CatalogKind.clans)[character.clan.catalog]
            ?.get("bane")?.jsonObject?.get("humanityThreshold")?.jsonPrimitive?.int ?: 6
        val cap = character.bloodPotency.coerceIn(5, 10)
        require(character.attributes.all { it.attribute in attributeIds }) { "Unknown attribute" }
        val attrs = merge(attributeIds.map { Attribute(it) }, character.attributes) { it.attribute }
            .map { it.copy(rating = it.rating.coerceIn(1, cap)) }
        val skills = merge(coreSkillIds.map { Skill(it) }, character.skills) { it.skill }
            .map { it.copy(rating = it.rating.coerceIn(0, cap)) }
        val maxVitae = when {
            character.bloodPotency <= 0 -> attrs.first { it.attribute == "stamina" }.rating
            character.bloodPotency >= 10 -> 75
            else -> listOf(10, 11, 12, 13, 15, 20, 25, 30, 50)[character.bloodPotency - 1]
        }
        return character.copy(
            attributes = attrs, skills = skills, skillList = "vampire-core",
            touchstones = merge((1..10).map { Touchstone(it) }, character.touchstones) { it.level },
            clanBaneActive = if ("clanBaneActive" in fields) character.clanBaneActive else character.humanity <= threshold,
            coils = character.coils.map { it.copy(rating = it.rating.coerceIn(0, 5)) },
            currentVitae = minOf(character.currentVitae, maxVitae),
        )
    }

    fun encode(character: CharacterSave): String {
        require(character.schemaVersion == CURRENT_SCHEMA)
        // Swift writes exactly the visible Health and Willpower boxes, including unmarked boxes.
        val encoded = json.encodeToJsonElement(character.copy(
            schemaVersion = character.savedSchemaVersion,
            healthTrack = character.healthTrack.visibleTrack(character.health(catalog), Damage.none),
            willpowerTrack = character.willpowerTrack.visibleTrack(character.willpower, WillpowerMark.none),
        )).jsonObject.toMutableMap()
        if (!character.elderBaneActive) encoded.remove("elderBaneActive")
        if (character.conditions.isEmpty()) encoded.remove("conditions")
        else encoded["conditions"] = JsonArray(encoded.getValue("conditions").jsonArray.map { element ->
            val fields = element.jsonObject
            if (fields.getValue("source").jsonObject.containsKey("catalog"))
                JsonObject(fields.filterKeys { it !in setOf("customEffect", "customResolution", "customBeat", "customPersistent") })
            else fields
        })
        return JsonObject(encoded).toString()
    }

    /** Compare to the originally loaded state. Re-decoding a sparse legacy save would generate new IDs. */
    fun encodeEdit(original: CharacterSave, edited: CharacterSave, at: Double): String? {
        require(original.id == edited.id)
        if (original == edited.copy(modifiedAt = original.modifiedAt)) return null
        return encode(edited.copy(modifiedAt = at))
    }

    private fun migrateTracks(fields: MutableMap<String, JsonElement>) {
        for ((track, legacy, mark) in listOf(
            Triple("healthTrack", "healthBoxes", "damageType"), Triple("willpowerTrack", "willpowerBoxes", "state")
        )) {
            if (track !in fields && legacy in fields) {
                fields[track] = JsonArray(fields.getValue(legacy).jsonArray.map { it.jsonObject[mark]?.takeUnless { mark -> mark == JsonNull } ?: JsonPrimitive("none") })
            }
        }
    }

    private fun migrateTraits(fields: MutableMap<String, JsonElement>) {
        fun rows(key: String, transform: (MutableMap<String, JsonElement>) -> Unit = {}) {
            val rows = fields[key]?.jsonArray ?: return
            fields[key] = JsonArray(rows.map { JsonObject(it.jsonObject.filterValues { value -> value != JsonNull }.toMutableMap().apply(transform)) })
        }
        rows("touchstones")
        rows("aspirations")
        rows("attributes") { row ->
            row.putIfAbsent("attribute", JsonPrimitive(row["name"]?.jsonPrimitive?.content?.lowercase() ?: ""))
        }
        rows("skills") { row ->
            if ("skill" !in row) {
                val name = row.getValue("name").jsonPrimitive.content
                row["skill"] = JsonPrimitive(name.lowercase().replace(' ', '-'))
            }
            val old = row["specialty"]?.jsonPrimitive?.content.orEmpty()
            if ("specialties" !in row && old.isNotEmpty()) row["specialties"] = JsonArray(listOf(JsonPrimitive(old)))
        }
        fun link(row: MutableMap<String, JsonElement>, key: String, kind: CatalogKind, legacy: String = key) {
            val objectSource = row[key] as? JsonObject
            if (objectSource?.containsKey("catalog") == true) return
            val name = objectSource?.getValue("custom")?.jsonPrimitive?.content
                ?: row[legacy]?.jsonPrimitive?.content?.trim().orEmpty()
            var source = catalog.source(kind, name)
            if (kind == CatalogKind.merits) {
                row.remove("qualifier")
                if (source.catalog == null && name.endsWith(')') && '(' in name) {
                    val base = catalog.source(kind, name.substringBeforeLast('(').trim())
                    val qualifier = name.substringAfterLast('(').dropLast(1).trim()
                    if (base.catalog != null && qualifier.isNotEmpty()) {
                        source = base
                        row["qualifier"] = JsonPrimitive(qualifier)
                    }
                }
            }
            row[key] = json.encodeToJsonElement(source)
        }
        link(fields, "clan", CatalogKind.clans)
        link(fields, "bloodline", CatalogKind.bloodlines)
        link(fields, "covenant", CatalogKind.covenants)
        link(fields, "mystery", CatalogKind.mysteries)
        for (kind in listOf(CatalogKind.disciplines, CatalogKind.merits, CatalogKind.banes)) {
            rows(kind.name) { link(it, "source", kind, if (kind == CatalogKind.banes) "text" else "name") }
        }
        for (kind in listOf(CatalogKind.devotions, CatalogKind.scales)) {
            rows(kind.name) { link(it, "source", kind) }
        }
        rows("rituals") {
            link(it, "source", CatalogKind.rituals)
            link(it, "customDiscipline", CatalogKind.disciplines)
        }
        rows("coils") { link(it, "mystery", CatalogKind.mysteries) }
        rows("conditions") { link(it, "source", CatalogKind.conditions) }
    }
}
