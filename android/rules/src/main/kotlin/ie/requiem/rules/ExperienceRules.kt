package ie.requiem.rules

import java.util.Locale
import java.util.UUID

internal fun UUID.swiftKey(): String = toString().uppercase(Locale.ROOT)
private data class TraitLevel(val level: Int, val name: String)
private val kindOrder = listOf("attribute", "skill", "specialty", "discipline", "merit", "coil", "ritual", "devotion", "scale", "humanity", "bloodPotency")

private fun CharacterSave.traitSnapshot(catalog: Catalog): Map<String, TraitLevel> = buildMap {
    fun add(key: String, level: Int, name: String) { put(key, TraitLevel(level, name)) }
    attributes.forEach { add("attribute:${it.attribute}", it.rating, traitName(it.attribute)) }
    skills.forEach {
        add("skill:${it.skill}", it.rating, traitName(it.skill))
        add("specialty:${it.skill}", it.specialties.count { text -> text.isNotBlank() }, "${traitName(it.skill)} Specialties")
    }
    disciplines.forEach { add("discipline:${it.id.swiftKey()}", it.rating, catalog.name(CatalogKind.disciplines, it.source)) }
    merits.forEach { add("merit:${it.id.swiftKey()}", it.rating, it.displayName(catalog)) }
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
    val old = before.traitSnapshot(catalog); val new = traitSnapshot(catalog)
    val keys = (old.keys + new.keys).sortedWith(compareBy<String> { kindOrder.indexOf(it.substringBefore(':')) }.thenBy { it.substringAfter(':') })
    val ledger = paidDots.toMutableMap(); val log = changeLog.toMutableList()
    val charge = xpMode && creation == null
    for (key in keys) {
        val from = old[key]?.level ?: 0; val to = new[key]?.level ?: 0
        if (from == to) continue
        val paid = ledger[key].orEmpty().toMutableMap()
        var cost = 0
        if (to > from && charge) for (level in from + 1..to) {
            val purchase = experienceCost(key, catalog)
            paid[level] = purchase; cost += purchase
        } else if (to < from) for (level in to + 1..from) {
            val removed = paid.remove(level) ?: 0
            if (charge && key.substringBefore(':') !in setOf("humanity", "bloodPotency")) cost -= removed
        }
        if (paid.isEmpty()) ledger.remove(key) else ledger[key] = paid
        log += TraitChange(UUID.randomUUID(), at, key, new[key]?.name ?: old.getValue(key).name, from, to, cost, charge, if (creation != null) true else null)
    }
    return copy(paidDots = ledger, changeLog = log)
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
        "coil" -> if (coils.any { it.id.swiftKey() == id && isMysteryCoil(it) }) 3 else 4
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
fun CharacterSave.changeName(change: TraitChange, catalog: Catalog): String = traitSnapshot(catalog)[change.trait]?.name?.takeIf { it.isNotBlank() }
    ?: change.name.ifBlank { change.trait.substringBefore(':').replaceFirstChar { it.uppercaseChar() } }
