package ie.forsaken.rules

import ie.chronicles.core.*
import kotlinx.serialization.json.*

data class ForsakenNoteGroup(val title: String, val options: List<ConditionNoteOption>, val warning: String? = null)
fun ForsakenRules.noteOptionGroups(entry: ForsakenEntry): List<ForsakenNoteGroup> {
    val choices = entry.noteOptions
    if (choices.isEmpty()) return emptyList()
    if (choices.none { it.group != null }) return listOf(ForsakenNoteGroup("", choices))
    val own = if (isPure) "pure" else "forsaken"; val other = if (isPure) "forsaken" else "pure"
    val ownTitle = if (isPure) "Pure Tribes" else "Forsaken Tribes"
    val otherTitle = if (isPure) "Forsaken Tribes" else "Pure Tribes"
    return buildList {
        add(ForsakenNoteGroup(ownTitle, choices.filter { (it.group ?: own) == own }))
        choices.filter { it.group == "lodge" }.takeIf { it.isNotEmpty() }?.let { add(ForsakenNoteGroup("Lodges", it)) }
        choices.filter { it.group == other }.takeIf { it.isNotEmpty() }?.let {
            add(ForsakenNoteGroup(otherTitle, it, if (isPure) "The Forsaken are your enemies" else "The Pure are your enemies"))
        }
    }
}
fun ForsakenRules.meritUnavailableReason(entry: ForsakenEntry) = "Only for humans".takeIf { entry.text("category") == "human" }
fun ForsakenRules.prerequisiteChecks(entry: ForsakenEntry): List<PrerequisiteCheck> {
    val lodges = lodgesTeaching("merits", entry.id)
    val lodgeCheck = if (lodges.isEmpty()) emptyList() else listOf(PrerequisiteCheck(
        "Lodge: " + lodges.map { it.name }.listed("or") + " (three times the cost otherwise)", lodges.any { it.id == state.lodge.catalog }))
    fun check(p: JsonObject): PrerequisiteCheck {
        val id = p.text("id").orEmpty(); val minimum = p.number("minimum") ?: 1; val text = p.text("text")
        state.commonPrerequisite(p.text("kind"), id, minimum, text, willpower, ::traitTitle) {
            catalog.entry(CatalogKind.merits, it)?.name ?: it
        }?.let { return it }
        return when (p.text("kind")) {
            "renown" -> Renown.entries.firstOrNull { it.name == id }?.let { PrerequisiteCheck("${it.title} $minimum", renown(it) >= minimum) } ?: PrerequisiteCheck(text ?: id, null)
            "primalUrge" -> PrerequisiteCheck("Primal Urge $minimum", state.primalUrge >= minimum)
            "harmony" -> PrerequisiteCheck("Harmony $minimum", state.harmony >= minimum)
            "tribe" -> PrerequisiteCheck("Tribe: ${catalog.entry(CatalogKind.tribes, id)?.name ?: id}", state.tribe.catalog == id)
            "notTribe" -> PrerequisiteCheck(text ?: "Not of the ${catalog.entry(CatalogKind.tribes, id)?.name ?: id}", state.tribe.catalog != id)
            "auspice" -> PrerequisiteCheck("Auspice: ${catalog.entry(CatalogKind.auspices, id)?.name ?: id}", effectiveAuspice?.id == id)
            else -> PrerequisiteCheck(text ?: id.ifEmpty { p.text("kind").orEmpty() }, null)
        }
    }
    return lodgeCheck + prerequisiteChecks(entry.fields.objects("prerequisites"),
        entry.array("prerequisitesAnyOf").map { group -> (group as? JsonArray).orEmpty().mapNotNull { it as? JsonObject } }, ::check)
}
internal fun List<String>.listed(conjunction: String) = when (size) { 0 -> ""; 1 -> first(); else -> dropLast(1).joinToString(", ") + " $conjunction " + last() }
fun ForsakenRules.conditionEffects(target: String): List<Pair<CharacterCondition, String>> = state.conditions.flatMap { condition ->
    catalog.entry(CatalogKind.conditions, condition.source.catalog)?.fields?.objects("affects").orEmpty().filter {
        target in (it["targets"] as? JsonArray).orEmpty().map { value -> value.jsonPrimitive.content }
    }.map { condition to it.text("text").orEmpty() }
}
fun harmonyDescription(harmony: Int): String {
    val value = harmony.coerceIn(0, 10); val distance = kotlin.math.abs(value - 5)
    val trigger = when (distance) { 0 -> "No Kuruth triggers"; 1, 2 -> "Specific Kuruth triggers"; 3, 4 -> "Common Kuruth triggers"; else -> "Passive Kuruth triggers" }
    val control = listOf("15 minutes", "5 minutes", "1 minute", "30 seconds", "10 seconds", "3 seconds")[distance]
    val bans = when (value) { 0 -> 4; 1 -> 3; 2 -> 2; 3, 4 -> 1; else -> 0 }
    return "$trigger · Control for $control" + if (bans > 0) " · $bans ${if (bans == 1) "ban" else "bans"}" else ""
}
