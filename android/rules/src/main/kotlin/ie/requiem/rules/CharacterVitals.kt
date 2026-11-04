package ie.requiem.rules

import kotlinx.serialization.json.*

val CharacterSave.willpower: Int
    get() = attributes.first { it.attribute == "resolve" }.rating + attributes.first { it.attribute == "composure" }.rating

// These totals determine exactly which damage and spent marks Swift writes to disk.
fun CharacterSave.health(catalog: Catalog): Int {
    fun bonus(kind: CatalogKind, source: TraitSource, rating: Int): Int {
        if (rating <= 0) return 0
        val effects = catalog.entries(kind)[source.catalog]?.get("effects")?.jsonArray.orEmpty()
        return effects.sumOf { element ->
            val effect = element as? JsonObject
            val type = (effect?.get("type") as? JsonPrimitive)?.content
            val applies = type == "size" || (type == "attribute" && (effect["attribute"] as? JsonPrimitive)?.content == "stamina")
            val amount = effect?.get("amount")
            when {
                !applies -> 0
                amount == JsonPrimitive("rating") -> rating
                else -> ((amount as? JsonObject)?.get("fixed") as? JsonPrimitive)?.intOrNull ?: 0
            }
        }
    }
    val stamina = attributes.first { it.attribute == "stamina" }.rating
    return size + stamina + disciplines.sumOf { bonus(CatalogKind.disciplines, it.source, it.rating) } +
        merits.sumOf { bonus(CatalogKind.merits, it.source, it.rating) }
}
