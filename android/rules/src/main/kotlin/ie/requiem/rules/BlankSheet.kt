package ie.requiem.rules

import java.util.UUID

/** The only player edits supported by the first phone editor. Loading a file never runs an edit. */
sealed interface SheetEdit {
    data class Rename(val name: String) : SheetEdit
    data class XpMode(val enabled: Boolean) : SheetEdit
    data class Stamina(val delta: Int) : SheetEdit
    data class Mark(val index: Int) : SheetEdit
}

val CharacterSave.stamina: Int get() = attributes.first { it.attribute == "stamina" }.rating
val CharacterSave.staminaCap: Int get() = bloodPotency.coerceIn(5, 10)

fun CharacterSave.edit(action: SheetEdit, catalog: Catalog, at: Double = foundationNow()): CharacterSave {
    if (creation != null) return this
    return when (action) {
        is SheetEdit.Rename -> copy(name = action.name)
        is SheetEdit.XpMode -> copy(xpMode = action.enabled)
        is SheetEdit.Mark -> {
            val total = health(catalog)
            if (action.index !in 0 until total) return this
            val track = List(total) { healthTrack.getOrElse(it) { Damage.none } }.toMutableList()
            val previous = track[action.index]
            track[action.index] = Damage.entries[(previous.ordinal + 1) % Damage.entries.size]
            copy(healthTrack = track)
        }
        is SheetEdit.Stamina -> {
            require(action.delta == -1 || action.delta == 1)
            val from = stamina
            val to = (from + action.delta).coerceIn(1, staminaCap)
            if (to == from) return this
            val key = "attribute:stamina"
            val ledger = paidDots.toMutableMap()
            val levels = ledger[key].orEmpty().toMutableMap()
            val cost = if (to > from) {
                if (xpMode) { levels[to] = 4; 4 } else 0
            } else {
                val paid = levels.remove(from) ?: 0
                if (xpMode) -paid else 0
            }
            if (levels.isEmpty()) ledger.remove(key) else ledger[key] = levels
            val change = TraitChange(UUID.randomUUID(), at, key, "Stamina", from, to, cost, xpMode)
            val next = copy(attributes = attributes.map { if (it.attribute == "stamina") it.copy(rating = to) else it },
                changeLog = changeLog + change, paidDots = ledger)
            next.copy(healthTrack = next.healthTrack.take(next.health(catalog).coerceAtLeast(0)))
        }
    }
}
