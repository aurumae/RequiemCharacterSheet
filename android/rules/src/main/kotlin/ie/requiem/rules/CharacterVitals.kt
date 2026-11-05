package ie.requiem.rules

import kotlinx.serialization.json.*

fun CharacterSave.attributeRating(id: String): Int = attributes.firstOrNull { it.attribute == id }?.rating ?: 0
fun CharacterSave.skillRating(id: String): Int = skills.firstOrNull { it.skill == id }?.rating ?: 0
val CharacterSave.willpower: Int get() = attributeRating("resolve") + attributeRating("composure")

internal data class AppliedEffect(val data: JsonObject, val rating: Int, val qualifier: String? = null)
internal fun CharacterSave.effects(catalog: Catalog): List<AppliedEffect> =
    disciplines.filter { it.rating > 0 }.flatMap { d -> catalog.entry(CatalogKind.disciplines, d.source)?.raw?.objects("effects").orEmpty().map { AppliedEffect(it, d.rating) } } +
    merits.filter { it.rating > 0 }.flatMap { m -> catalog.entry(CatalogKind.merits, m.source)?.raw?.objects("effects").orEmpty().map { AppliedEffect(it, m.rating, m.qualifier) } }

internal fun JsonObject.effectAmount(rating: Int): Int = if (get("amount") == JsonPrimitive("rating")) rating else obj("amount")?.int("fixed") ?: 0
internal fun CharacterSave.effectBonus(catalog: Catalog, type: String, attribute: String? = null): Int = effects(catalog).sumOf {
    if (it.data.str("type") == type && (attribute == null || it.data.str("attribute") == attribute)) it.data.effectAmount(it.rating) else 0
}
fun CharacterSave.attributeBonus(id: String, catalog: Catalog): Int = effectBonus(catalog, "attribute", id)
fun CharacterSave.rollBonus(id: String, catalog: Catalog): Int = effectBonus(catalog, "attributeRolls", id)
fun CharacterSave.staminaBonus(catalog: Catalog): Int = attributeBonus("stamina", catalog)
fun CharacterSave.totalAttribute(id: String, catalog: Catalog): Int = attributeRating(id) + attributeBonus(id, catalog)
fun CharacterSave.rollAttribute(id: String, catalog: Catalog): Int = totalAttribute(id, catalog) + rollBonus(id, catalog)
fun CharacterSave.effectiveSize(catalog: Catalog): Int = size + effectBonus(catalog, "size")
fun CharacterSave.health(catalog: Catalog): Int = effectiveSize(catalog) + totalAttribute("stamina", catalog)
fun CharacterSave.speed(catalog: Catalog): Int = 5 + totalAttribute("strength", catalog) + totalAttribute("dexterity", catalog) + effectBonus(catalog, "speed")
fun CharacterSave.initiative(catalog: Catalog): Int = totalAttribute("dexterity", catalog) + totalAttribute("composure", catalog) + effectBonus(catalog, "initiative")
fun CharacterSave.defense(catalog: Catalog, skill: String = "athletics"): Int = minOf(totalAttribute("dexterity", catalog), totalAttribute("wits", catalog)) + skillRating(skill) + effectBonus(catalog, "defense")
fun CharacterSave.alternativeDefenseSkills(catalog: Catalog): List<String> = effects(catalog).filter { it.data.str("type") == "defenseSkillFromQualifier" }
    .mapNotNull { effect -> skillDefinitions.firstOrNull { it.name.equals(effect.qualifier, true) }?.id }.distinct()
fun CharacterSave.skillDiceContribution(id: String): Int = skillRating(id).let { if (it != 0) it else skillDefinitions.firstOrNull { d -> d.id == id }?.category?.unskilledPenalty ?: -3 }
fun CharacterSave.combatPool(skill: String, catalog: Catalog): Int = rollAttribute(if (skill == "firearms") "dexterity" else "strength", catalog) + skillDiceContribution(skill)
val CharacterSave.maxVitae: Int get() = when {
    bloodPotency <= 0 -> stamina
    bloodPotency >= 10 -> 75
    else -> listOf(10, 11, 12, 13, 15, 20, 25, 30, 50)[bloodPotency - 1]
}
val CharacterSave.vitaePerTurn: Int get() = when {
    bloodPotency <= 0 -> 1
    bloodPotency >= 10 -> 15
    bloodPotency == 9 -> 10
    else -> bloodPotency
}

internal fun CharacterSave.dice(pool: JsonObject, catalog: Catalog, disciplineRating: Int = 0): Int? {
    val attr = pool.str("attribute") ?: return null
    return rollAttribute(attr, catalog) + (pool.str("skill")?.let(::skillDiceContribution) ?: 0) +
        (if (pool.flag("includesDiscipline")) disciplineRating else 0) + (pool.str("discipline")?.let(::disciplineRating) ?: 0)
}
