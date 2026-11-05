package ie.requiem.rules

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject

data class PrerequisiteCheck(val description: String, val met: Boolean?)
fun List<PrerequisiteCheck>.warningText(): String {
    val unmet = filter { it.met == false }
    return buildList {
        if (unmet.any { it.description == "Not available to Kindred" }) add("Not available to Kindred")
        val others = unmet.filter { it.description != "Not available to Kindred" }
        if (others.isNotEmpty()) add("Requires " + others.joinToString("; ") { it.description })
    }.joinToString(". ")
}
fun CharacterSave.prerequisites(entry: BookEntry, catalog: Catalog): List<PrerequisiteCheck> = buildList {
    if (entry.raw.flag("unavailableToKindred")) add(PrerequisiteCheck("Not available to Kindred", false))
    addAll(entry.raw.objects("prerequisites").map { check(it, catalog) })
    val alternatives = entry.raw.array("prerequisitesAnyOf").map { group -> group.jsonArray.map { check(it.jsonObject, catalog) } }
    if (alternatives.isNotEmpty()) add(PrerequisiteCheck("One of: " + alternatives.joinToString(", or ") { group -> group.joinToString(" and ") { it.description } },
        alternatives.any { group -> group.all { it.met != false } }))
}
private fun CharacterSave.check(rule: JsonObject, catalog: Catalog): PrerequisiteCheck {
    val id = rule.str("id").orEmpty(); val minimum = rule.int("minimum", 1)
    fun named(kind: CatalogKind) = catalog.name(kind, TraitSource(catalog = id))
    return when (rule.str("kind")) {
        "attribute" -> if (attributeDefinitions.any { it.id == id }) PrerequisiteCheck("${traitName(id)} $minimum", attributeRating(id) >= minimum) else PrerequisiteCheck(rule.str("text") ?: id, null)
        "skill" -> PrerequisiteCheck("${traitName(id)} $minimum", skillRating(id) >= minimum)
        "merit" -> PrerequisiteCheck(named(CatalogKind.merits) + if (minimum > 1) " $minimum" else "", merits.any { it.source.catalog == id && it.rating >= minimum })
        "discipline" -> PrerequisiteCheck("${named(CatalogKind.disciplines)} $minimum", disciplineRating(id) >= minimum)
        "bloodPotency" -> PrerequisiteCheck("Blood Potency $minimum", bloodPotency >= minimum)
        "clan" -> PrerequisiteCheck("Clan: ${named(CatalogKind.clans)}", clan.catalog == id)
        "covenant" -> if (rule.str("minimum") != null) PrerequisiteCheck("${named(CatalogKind.covenants)} Status $minimum", covenantStatus(id, catalog) >= minimum)
            else PrerequisiteCheck("Covenant: ${named(CatalogKind.covenants)}", covenant.catalog == id)
        else -> PrerequisiteCheck(rule.str("text") ?: rule.str("id") ?: "Other requirement", null)
    }
}
