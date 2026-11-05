package ie.requiem.rules

import java.util.UUID
import kotlinx.serialization.json.*

/** Committed player actions. Loading, rendering and saving never replay an edit. */
sealed interface SheetEdit {
    data class Rename(val name: String) : SheetEdit
    data class Detail(val field: CharacterDetail, val text: String) : SheetEdit
    data class XpMode(val enabled: Boolean) : SheetEdit
    data class AttributeRating(val id: String, val rating: Int) : SheetEdit
    data class SkillRating(val id: String, val rating: Int) : SheetEdit
    data class AddSpecialty(val skill: String, val text: String) : SheetEdit
    data class ReplaceSpecialty(val skill: String, val index: Int, val previous: String, val text: String) : SheetEdit
    data class Stamina(val delta: Int) : SheetEdit
    data class StaminaRating(val rating: Int) : SheetEdit
    data class Mark(val index: Int) : SheetEdit
}

val CharacterSave.stamina: Int get() = attributes.first { it.attribute == "stamina" }.rating
val CharacterSave.staminaCap: Int get() = legalRatings(RatingKind.Attribute, bloodPotency).last

fun CharacterSave.edit(action: SheetEdit, catalog: Catalog, at: Double = foundationNow()): CharacterSave {
    if (creation != null) return this
    return when (action) {
        is SheetEdit.Rename -> copy(name = action.name)
        is SheetEdit.Detail -> editDetail(action.field, action.text, catalog)
        is SheetEdit.XpMode -> copy(xpMode = action.enabled)
        is SheetEdit.StaminaRating -> edit(SheetEdit.AttributeRating("stamina", action.rating), catalog, at)
        is SheetEdit.Stamina -> edit(SheetEdit.AttributeRating("stamina", stamina + action.delta), catalog, at)
        is SheetEdit.Mark -> {
            val total = health(catalog)
            if (action.index !in 0 until total) return this
            val track = List(total) { healthTrack.getOrElse(it) { Damage.none } }.toMutableList()
            val previous = track[action.index]
            track[action.index] = Damage.entries[(previous.ordinal + 1) % Damage.entries.size]
            copy(healthTrack = track)
        }
        is SheetEdit.AttributeRating -> {
            val definition = attributeDefinitions.firstOrNull { it.id == action.id } ?: return this
            val from = attributes.firstOrNull { it.attribute == action.id }?.rating ?: return this
            val to = action.rating.coerceIn(legalRatings(RatingKind.Attribute, bloodPotency))
            if (to == from) return this
            val next = copy(attributes = attributes.map { if (it.attribute == action.id) it.copy(rating = to) else it })
                .recordLevelChange("attribute:${action.id}", definition.name, from, to, 4, at)
            // Remove marks beyond a reduced track now, so raising it before the writer finishes
            // cannot resurrect damage or spent Willpower that was already removed.
            next.copy(healthTrack = next.healthTrack.take(next.health(catalog).coerceAtLeast(0)),
                willpowerTrack = next.willpowerTrack.take(next.willpower.coerceAtLeast(0)),
                currentVitae = if (bloodPotency <= 0) minOf(next.currentVitae, next.stamina) else next.currentVitae)
        }
        is SheetEdit.SkillRating -> {
            val definition = skillDefinitions.firstOrNull { it.id == action.id } ?: return this
            val from = skills.firstOrNull { it.skill == action.id }?.rating ?: return this
            val to = action.rating.coerceIn(legalRatings(RatingKind.Skill, bloodPotency))
            if (to == from) return this
            copy(skills = skills.map { if (it.skill == action.id) it.copy(rating = to) else it })
                .recordLevelChange("skill:${action.id}", definition.name, from, to, 2, at)
        }
        is SheetEdit.AddSpecialty -> {
            val text = action.text.trim()
            val skill = skills.firstOrNull { it.skill == action.skill } ?: return this
            if (text.isEmpty()) return this
            replaceSpecialties(skill, skill.specialties + text, at)
        }
        is SheetEdit.ReplaceSpecialty -> {
            val skill = skills.firstOrNull { it.skill == action.skill } ?: return this
            if (skill.specialties.getOrNull(action.index) != action.previous) return this
            val text = action.text.trim()
            val specialties = skill.specialties.toMutableList()
            if (text.isEmpty()) specialties.removeAt(action.index) else specialties[action.index] = text
            if (specialties == skill.specialties) return this
            replaceSpecialties(skill, specialties, at)
        }
    }
}

private fun CharacterSave.editDetail(field: CharacterDetail, text: String, catalog: Catalog): CharacterSave = when (field) {
    CharacterDetail.Name -> copy(name = text)
    CharacterDetail.Player -> copy(player = text)
    CharacterDetail.Chronicle -> copy(chronicle = text)
    CharacterDetail.Mask -> copy(mask = text)
    CharacterDetail.Dirge -> copy(dirge = text)
    CharacterDetail.Concept -> copy(concept = text)
    CharacterDetail.Bloodline -> copy(bloodline = text)
    CharacterDetail.Covenant -> copy(covenant = catalog.source(CatalogKind.covenants, text))
    CharacterDetail.Clan -> {
        val source = catalog.source(CatalogKind.clans, text)
        val entry = catalog.entries(CatalogKind.clans)[source.catalog]
        val threshold = entry?.get("bane")?.jsonObject?.get("humanityThreshold")?.jsonPrimitive?.int ?: 6
        copy(clan = source, clanBaneActive = clanBaneActive || (clan != source && entry != null && humanity <= threshold))
    }
}

private fun CharacterSave.replaceSpecialties(skill: Skill, specialties: List<String>, at: Double): CharacterSave {
    val name = skillDefinitions.firstOrNull { it.id == skill.skill }?.name ?: return this
    val from = skill.specialties.count { it.isNotBlank() }
    val to = specialties.count { it.isNotBlank() }
    return copy(skills = skills.map { if (it.skill == skill.skill) it.copy(specialties = specialties) else it })
        .recordLevelChange("specialty:${skill.skill}", "$name Specialties", from, to, 1, at)
}

/** Same paid-level ledger as Swift: free edits log, renames don't, and removed dots
 * lose their paid status even when XP Mode is off. Only paid dots can be refunded. */
private fun CharacterSave.recordLevelChange(key: String, name: String, from: Int, to: Int, perDot: Int, at: Double): CharacterSave {
    if (from == to) return this
    val ledger = paidDots.toMutableMap()
    val levels = ledger[key].orEmpty().toMutableMap()
    val cost = if (to > from) {
        if (xpMode) {
            for (level in from + 1..to) levels[level] = perDot
            (to - from) * perDot
        } else 0
    } else {
        val paid = (to + 1..from).sumOf { levels.remove(it) ?: 0 }
        if (xpMode) -paid else 0
    }
    if (levels.isEmpty()) ledger.remove(key) else ledger[key] = levels
    val change = TraitChange(UUID.randomUUID(), at, key, name, from, to, cost, xpMode)
    return copy(changeLog = changeLog + change, paidDots = ledger)
}
