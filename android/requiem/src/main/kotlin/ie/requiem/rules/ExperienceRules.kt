package ie.requiem.rules

import ie.chronicles.core.ExperienceLedger
import ie.chronicles.core.TraitLevel
import ie.chronicles.core.record
import ie.chronicles.core.sharedTraitSnapshot
import java.util.Locale
import java.util.UUID

internal fun UUID.swiftKey(): String = toString().uppercase(Locale.ROOT)
private val kindOrder = listOf("attribute", "skill", "specialty", "discipline", "merit", "coil", "ritual", "devotion", "scale", "humanity", "bloodPotency")

private fun CharacterSave.traitSnapshot(catalog: Catalog): Map<String, TraitLevel> = buildMap {
    fun add(key: String, level: Int, name: String) { put(key, TraitLevel(level, name)) }
    putAll(sharedTraitSnapshot(::traitName) { it.displayName(catalog) })
    disciplines.forEach { add("discipline:${it.id.swiftKey()}", it.rating, catalog.name(CatalogKind.disciplines, it.source)) }
    coils.forEach { add("coil:${it.id.swiftKey()}", it.rating, it.displayName(catalog)) }
    rituals.forEach { add("ritual:${it.id.swiftKey()}", 1, catalog.name(CatalogKind.rituals, it.source)) }
    devotions.forEach { add("devotion:${it.id.swiftKey()}", if (catalog.entry(CatalogKind.devotions, it.source) != null) 1 else it.customExperienceCost.coerceAtLeast(1), catalog.name(CatalogKind.devotions, it.source)) }
    scales.forEach { add("scale:${it.id.swiftKey()}", 1, catalog.name(CatalogKind.scales, it.source)) }
    add("humanity:humanity", humanity, "Humanity")
    add("bloodPotency:bloodPotency", bloodPotency, "Blood Potency")
}

internal fun CharacterSave.traitLevels(catalog: Catalog): Map<String, Int> = traitSnapshot(catalog).mapValues { it.value.level }

/** One recorder for every committed edit, matching Swift's snapshot order and paid levels. */
internal fun CharacterSave.recordChanges(before: CharacterSave, catalog: Catalog, at: Double): CharacterSave {
    val next = ExperienceLedger(paidDots, changeLog).record(before.traitSnapshot(catalog), traitSnapshot(catalog),
        kindOrder, xpMode && creation == null, creation != null, at,
        costPerDot = { key, _ -> experienceCost(key, catalog) },
        refunds = { it != "humanity" && it != "bloodPotency" })
    return copy(paidDots = next.paidDots, changeLog = next.changeLog)
}

private fun CharacterSave.experienceCost(key: String, catalog: Catalog): Int {
    val id = key.substringAfter(':')
    return when (key.substringBefore(':')) {
        "attribute" -> 4
        "skill" -> 2
        "specialty", "merit" -> 1
        "humanity" -> 2
        "bloodPotency" -> 5
        "discipline" -> {
            val discipline = disciplines.firstOrNull { it.id.swiftKey() == id }
            val entry = discipline?.let { catalog.entry(CatalogKind.disciplines, it.source) }
            if (entry != null && !entry.isRitualDiscipline && entry.id in inClanDisciplines(catalog)) 3 else 4
        }
        "coil" -> if (coils.any { it.id.swiftKey() == id && isMysteryCoil(it, catalog) }) 3 else 4
        "ritual" -> {
            val ritual = rituals.firstOrNull { it.id.swiftKey() == id } ?: return 2
            val discipline = ritual.discipline(catalog)
            val others = rituals.count { it.id != ritual.id && it.discipline(catalog) == discipline }
            val free = discipline.catalog?.let(::disciplineRating) ?: 0
            if (others < free) 0 else 2
        }
        "devotion" -> devotions.firstOrNull { it.id.swiftKey() == id }?.let { catalog.entry(CatalogKind.devotions, it.source)?.experienceCost } ?: 1
        "scale" -> scales.firstOrNull { it.id.swiftKey() == id }?.let { catalog.entry(CatalogKind.scales, it.source) }?.let(::scaleCost) ?: 2
        else -> 0
    }
}

/** Live names keep a custom entry's older log records readable after it is named. */
fun CharacterSave.changeName(change: TraitChange, catalog: Catalog): String = conditionLogName(change, catalog) ?: traitSnapshot(catalog)[change.trait]?.name?.takeIf { it.isNotBlank() }
    ?: change.name.ifBlank { change.trait.substringBefore(':').replaceFirstChar { it.uppercaseChar() } }
