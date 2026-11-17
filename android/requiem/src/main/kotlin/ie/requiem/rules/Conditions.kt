package ie.requiem.rules

import ie.chronicles.core.ConditionNoteOption
import ie.chronicles.core.BookSource
import ie.chronicles.core.applyConditionEvent
import java.util.UUID

enum class ConditionField { Name, Note, Effect, Resolution, Beat }

data class ConditionInfo(val name: String, val persistent: Boolean, val effect: String,
    val resolution: String, val beat: String?, val possibleSources: String?, val citation: String,
    val beatOnResolve: Boolean, val hasCounter: Boolean, val notePrompt: String, val custom: Boolean,
    val noteOptions: List<ConditionNoteOption>, val source: BookSource?)

fun CharacterCondition.info(catalog: Catalog): ConditionInfo {
    val entry = catalog.entry(CatalogKind.conditions, source)
    val raw = entry?.raw
    val name = catalog.name(CatalogKind.conditions, source)
    val hasCounter = raw?.flag("counter") == true
    return ConditionInfo(if (hasCounter && counter > 0) "$name −$counter" else name,
        raw?.flag("persistent") ?: customPersistent, entry?.summary ?: customEffect,
        raw?.str("resolution") ?: customResolution,
        if (entry != null) raw?.str("beat") else customBeat.trim().ifEmpty { null },
        raw?.str("possibleSources"), entry?.citation.orEmpty(), raw?.str("beatOnResolve") != "false",
        hasCounter, raw?.str("notePrompt") ?: "Note", source.catalog == null, entry?.noteOptions.orEmpty(), entry?.sourceReference)
}

fun CharacterCondition.logName(catalog: Catalog): String = info(catalog).name + if (note.isEmpty()) "" else " ($note)"
fun CharacterSave.canAddCondition(entry: BookEntry): Boolean = entry.repeatable || conditions.none { it.source.catalog == entry.id }
fun CharacterSave.recentConditionIDs(catalog: Catalog): List<String> = changeLog.asReversed()
    .filter { it.trait.startsWith("condition:") && it.event == ConditionEvent.added }
    .map { it.trait.substringAfter(':').substringBefore('/') }
    .filter { it != "custom" && catalog.entry(CatalogKind.conditions, it) != null }.distinct().take(5)

data class ConditionEffect(val condition: CharacterCondition, val text: String)
fun CharacterSave.conditionEffects(target: String, catalog: Catalog): List<ConditionEffect> {
    if (!knownConditionTarget(target)) return emptyList()
    return conditions.flatMap { condition ->
        catalog.entry(CatalogKind.conditions, condition.source)?.raw?.objects("affects").orEmpty()
            .filter { target in it.strings("targets") }.map { ConditionEffect(condition, it.str("text").orEmpty()) }
    }
}
private fun knownConditionTarget(target: String): Boolean = when (target.substringBefore(':')) {
    "attribute" -> target.substringAfter(':') in attributeIds
    "skill" -> target.substringAfter(':', "").isNotEmpty()
    "attributeCategory", "skillCategory" -> target.substringAfter(':') in setOf("mental", "physical", "social")
    "defense" -> target == "defense"
    else -> false
}

internal fun CharacterSave.editCondition(action: SheetEdit, catalog: Catalog, at: Double): CharacterSave {
    fun apply(c: CharacterCondition, event: ConditionEvent): CharacterSave {
        val info = c.info(catalog)
        val change = applyConditionEvent(c, event, c.logName(catalog), info.beat != null, info.beatOnResolve,
            creation != null, at) ?: return this
        return copy(conditions = change.conditions, changeLog = changeLog + change.log,
            beats = change.total.beats, experiences = change.total.experiences)
    }
    return when (action) {
        is SheetEdit.AddCondition -> {
            val entry = catalog.entry(CatalogKind.conditions, action.source)
            if (conditions.any { it.id == action.id } || (action.source.catalog != null &&
                    (entry == null || !canAddCondition(entry)))) this
            else {
                val c = CharacterCondition(action.source, action.id, counter = if (entry?.raw?.flag("counter") == true) 1 else 0, addedAt = at)
                apply(c, ConditionEvent.added)
            }
        }
        is SheetEdit.ConditionAction -> {
            val c = conditions.firstOrNull { it.id == action.id } ?: return this
            if (action.event == ConditionEvent.added) return this
            apply(c, action.event)
        }
        is SheetEdit.ConditionText -> copy(conditions = conditions.map { c ->
            if (c.id != action.id || (action.field != ConditionField.Note && c.source.catalog != null)) c
            else when (action.field) {
                ConditionField.Name -> c.copy(source = catalog.source(CatalogKind.conditions, action.text))
                ConditionField.Note -> c.copy(note = action.text)
                ConditionField.Effect -> c.copy(customEffect = action.text)
                ConditionField.Resolution -> c.copy(customResolution = action.text)
                ConditionField.Beat -> c.copy(customBeat = action.text)
            }
        })
        is SheetEdit.ConditionCounter -> copy(conditions = conditions.map {
            if (it.id == action.id && it.info(catalog).hasCounter) it.copy(counter = action.value.coerceIn(1, 20)) else it })
        is SheetEdit.ConditionPersistent -> copy(conditions = conditions.map {
            if (it.id == action.id && it.source.catalog == null) it.copy(customPersistent = action.value) else it })
        else -> this
    }
}

fun CharacterSave.conditionLogName(change: TraitChange, catalog: Catalog): String? {
    if (!change.trait.startsWith("condition:")) return null
    val id = runCatching { UUID.fromString(change.trait.substringAfter('/')) }.getOrNull()
    return conditions.firstOrNull { it.id == id }?.logName(catalog)
        ?: changeLog.lastOrNull { it.trait == change.trait }?.name
}
