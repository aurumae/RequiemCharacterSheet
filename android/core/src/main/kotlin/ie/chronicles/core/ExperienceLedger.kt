package ie.chronicles.core

import java.util.Locale
import java.util.UUID

data class TraitLevel(val level: Int, val name: String)

fun ChroniclesCharacter.sharedTraitSnapshot(traitName: (String) -> String, meritName: (Merit) -> String): Map<String, TraitLevel> = buildMap {
    fun putLevel(key: String, level: Int, name: String) { put(key, TraitLevel(level, name)) }
    attributes.forEach { putLevel("attribute:${it.attribute}", it.rating, traitName(it.attribute)) }
    skills.forEach {
        putLevel("skill:${it.skill}", it.rating, traitName(it.skill))
        putLevel("specialty:${it.skill}", it.specialties.count { text -> text.isNotBlank() }, "${traitName(it.skill)} Specialties")
    }
    merits.forEach { putLevel("merit:${it.id.toString().uppercase(Locale.ROOT)}", it.rating, meritName(it)) }
}

data class ExperienceLedger(val paidDots: Map<String, Map<Int, Int>>, val changeLog: List<TraitChange>)

fun ExperienceLedger.record(old: Map<String, TraitLevel>, new: Map<String, TraitLevel>, kindOrder: List<String>,
    charge: Boolean, duringCreation: Boolean, at: Double, costPerDot: (String, Int) -> Int,
    refunds: (kind: String) -> Boolean): ExperienceLedger {
    val order = kindOrder.withIndex().associate { it.value to it.index }
    val keys = (old.keys + new.keys).sortedWith(compareBy<String> { order[it.substringBefore(':')] ?: order.size }
        .thenBy { it.substringAfter(':') })
    val ledger = paidDots.toMutableMap(); val log = changeLog.toMutableList()
    for (key in keys) {
        val from = old[key]?.level ?: 0; val to = new[key]?.level ?: 0
        if (from == to) continue
        val paid = ledger[key].orEmpty().toMutableMap()
        var cost = 0
        if (to > from && charge) for (level in from + 1..to) {
            val purchase = costPerDot(key, level)
            paid[level] = purchase; cost += purchase
        } else if (to < from) for (level in to + 1..from) {
            val removed = paid.remove(level) ?: 0
            if (charge && refunds(key.substringBefore(':'))) cost -= removed
        }
        if (paid.isEmpty()) ledger.remove(key) else ledger[key] = paid
        log += TraitChange(UUID.randomUUID(), at, key, new[key]?.name ?: old.getValue(key).name, from, to, cost, charge, if (duringCreation) true else null)
    }
    return ExperienceLedger(ledger, log)
}
