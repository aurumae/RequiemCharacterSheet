package ie.chronicles.core

import java.util.Locale
import java.util.UUID

data class ConditionUpdate(val conditions: List<CharacterCondition>, val log: TraitChange, val total: BeatTotal)

/** Apply one event to the row and log together. The game supplies the catalog's Beat rules. */
fun ChroniclesCharacter.applyConditionEvent(condition: CharacterCondition, event: ConditionEvent, name: String,
    hasBeat: Boolean, beatOnResolve: Boolean, duringCreation: Boolean, at: Double): ConditionUpdate? {
    val present = conditions.any { it.id == condition.id }
    if (event == ConditionEvent.added && present) return null
    if (event != ConditionEvent.added && !present) return null
    if (event == ConditionEvent.beat && !hasBeat) return null
    val gained = event == ConditionEvent.beat || (event == ConditionEvent.resolved && beatOnResolve)
    val rows = when (event) {
        ConditionEvent.added -> conditions + condition
        ConditionEvent.beat -> conditions
        ConditionEvent.ended, ConditionEvent.resolved -> conditions.filterNot { it.id == condition.id }
    }
    val key = "condition:${condition.source.catalog ?: "custom"}/${condition.id.toString().uppercase(Locale.ROOT)}"
    val log = TraitChange(UUID.randomUUID(), at, key, name, if (event == ConditionEvent.added) 0 else 1,
        if (event == ConditionEvent.added || event == ConditionEvent.beat) 1 else 0, 0, xpMode,
        true.takeIf { duringCreation }, event, 1.takeIf { gained })
    return ConditionUpdate(rows, log, if (gained) incrementBeat(beats, experiences) else BeatTotal(beats, experiences))
}
