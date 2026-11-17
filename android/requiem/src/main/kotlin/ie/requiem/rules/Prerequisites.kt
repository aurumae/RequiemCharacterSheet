package ie.requiem.rules

import ie.chronicles.core.commonPrerequisite
import ie.chronicles.core.prerequisiteChecks
import ie.chronicles.core.prerequisiteWarning
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject

typealias PrerequisiteCheck = ie.chronicles.core.PrerequisiteCheck
fun List<PrerequisiteCheck>.warningText() = prerequisiteWarning()

fun CharacterSave.prerequisites(entry: BookEntry, catalog: Catalog): List<PrerequisiteCheck> = buildList {
    if (entry.raw.flag("unavailableToKindred")) add(PrerequisiteCheck("Not available to Kindred", false, unavailable = true))
    val merit = entry.takeIf { it.kind == CatalogKind.merits }
    addAll(prerequisiteChecks(entry.raw.objects("prerequisites"), entry.raw.array("prerequisitesAnyOf").map { group ->
        group.jsonArray.map { it.jsonObject }
    }) { check(it, catalog, merit) })
}
private fun CharacterSave.check(rule: JsonObject, catalog: Catalog, merit: BookEntry?): PrerequisiteCheck {
    val id = rule.str("id").orEmpty(); val minimum = rule.int("minimum", 1)
    fun named(kind: CatalogKind) = catalog.name(kind, TraitSource(catalog = id))
    val kind = rule.str("kind")
    val shared = commonPrerequisite(kind, id, minimum, rule.str("text"), willpower, ::traitName) { named(CatalogKind.merits) }
    if (shared != null) return shared
    return when (kind) {
        "discipline" -> PrerequisiteCheck("${named(CatalogKind.disciplines)} $minimum", disciplineRating(id) >= minimum)
        "bloodPotency" -> PrerequisiteCheck("Blood Potency $minimum", bloodPotency >= minimum)
        "notCovenant" -> PrerequisiteCheck("Not a member of the ${named(CatalogKind.covenants)}", covenant.catalog != id)
        "bloodline" -> PrerequisiteCheck("Bloodline: ${named(CatalogKind.bloodlines)}", bloodline.catalog == id)
        "clan" -> {
            val standIn = if (merit == null) null else listOfNotNull(catalog.entry(CatalogKind.bloodlines, bloodline), catalog.entry(CatalogKind.clans, clan))
                .firstOrNull { source -> source.raw.objects("meritAccess").any { it.str("inPlaceOf") == id && merit.id in it.strings("merits") } }
            PrerequisiteCheck("Clan: ${standIn?.name ?: named(CatalogKind.clans)}", standIn != null || clan.catalog == id)
        }
        "covenant" -> {
            val own = catalog.entry(CatalogKind.covenants, covenant)
            val replaces = merit != null && own?.raw?.objects("meritGroups")?.any {
                it.str("inPlaceOf") == id && ((it.str("group") != null && it.str("group") == merit.raw.str("group")) || merit.id in it.strings("merits"))
            } == true
            val name = if (replaces) own!!.name else statusStandIn(id, catalog)?.name ?: named(CatalogKind.covenants)
            if (replaces || rule.str("minimum") != null) PrerequisiteCheck("$name Status $minimum", covenantStatus(if (replaces) own!!.id else id, catalog) >= minimum)
            else PrerequisiteCheck("Covenant: $name", belongsToCovenant(id, catalog))
        }
        else -> PrerequisiteCheck(rule.str("text") ?: rule.str("id") ?: "Other requirement", null)
    }
}
