package ie.requiem.rules

import kotlinx.serialization.json.*

val CharacterSave.willpower: Int
    get() = attributes.first { it.attribute == "resolve" }.rating + attributes.first { it.attribute == "composure" }.rating

// These totals determine exactly which damage and spent marks Swift writes to disk.
private fun CharacterSave.effectBonus(catalog: Catalog, effectType: String): Int {
    fun bonus(kind: CatalogKind, source: TraitSource, rating: Int): Int {
        if (rating <= 0) return 0
        val effects = catalog.entries(kind)[source.catalog]?.get("effects")?.jsonArray.orEmpty()
        return effects.sumOf { element ->
            val effect = element as? JsonObject
            val type = (effect?.get("type") as? JsonPrimitive)?.content
            val applies = type == effectType && (type != "attribute" || (effect["attribute"] as? JsonPrimitive)?.content == "stamina")
            val amount = effect?.get("amount")
            when {
                !applies -> 0
                amount == JsonPrimitive("rating") -> rating
                else -> ((amount as? JsonObject)?.get("fixed") as? JsonPrimitive)?.intOrNull ?: 0
            }
        }
    }
    return disciplines.sumOf { bonus(CatalogKind.disciplines, it.source, it.rating) } +
        merits.sumOf { bonus(CatalogKind.merits, it.source, it.rating) }
}

fun CharacterSave.staminaBonus(catalog: Catalog): Int = effectBonus(catalog, "attribute")

fun CharacterSave.health(catalog: Catalog): Int =
    size + stamina + staminaBonus(catalog) + effectBonus(catalog, "size")
