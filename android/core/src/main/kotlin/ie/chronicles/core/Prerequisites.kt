package ie.chronicles.core

data class PrerequisiteCheck(val description: String, val met: Boolean?, val unavailable: Boolean = false)

fun List<PrerequisiteCheck>.prerequisiteWarning(): String {
    val unmet = filter { it.met == false }
    val parts = unmet.filter { it.unavailable }.map { it.description }.toMutableList()
    val requirements = unmet.filterNot { it.unavailable }
    if (requirements.isNotEmpty()) parts.add("Requires " + requirements.joinToString("; ") { it.description })
    return parts.joinToString(". ")
}

fun <T> prerequisiteChecks(required: List<T>, anyOf: List<List<T>>, check: (T) -> PrerequisiteCheck) = buildList {
    addAll(required.map(check))
    if (anyOf.isNotEmpty()) {
        val groups = anyOf.map { it.map(check) }
        val choices = groups.joinToString(", or ") { group -> group.joinToString(" and ") { it.description } }
        add(PrerequisiteCheck("One of: $choices", groups.any { group -> group.none { it.met == false } }))
    }
}

fun ChroniclesCharacter.commonPrerequisite(kind: String?, id: String, minimum: Int, text: String?, totalWillpower: Int,
    traitName: (String) -> String, meritName: (String) -> String): PrerequisiteCheck? = when (kind) {
    "attribute" -> if (attributeDefinitions.any { it.id == id })
        PrerequisiteCheck("${traitName(id)} $minimum", attributeRating(id) >= minimum) else PrerequisiteCheck(text ?: id, null)
    "skill" -> PrerequisiteCheck("${traitName(id)} $minimum", skillRating(id) >= minimum)
    "merit" -> PrerequisiteCheck(meritName(id) + if (minimum > 1) " $minimum" else "",
        merits.any { it.source.catalog == id && it.rating >= minimum })
    "willpower" -> PrerequisiteCheck("Willpower $minimum", totalWillpower >= minimum)
    else -> null
}
