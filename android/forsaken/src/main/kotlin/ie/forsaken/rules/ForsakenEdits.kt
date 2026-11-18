package ie.forsaken.rules

import ie.chronicles.core.*

/** Every ordinary-play edit applies the Swift view side effects and records its paid dots exactly once. */
class ForsakenEdits(val catalog: ForsakenCatalog = ForsakenCatalog.bundled) {
    fun change(character: ForsakenCharacter, at: Double = foundationNow(), transform: (ForsakenState) -> ForsakenState): ForsakenCharacter {
        val old = character.state
        check(old.creation == null) { "Guided creation saves are read-only until phase 4." }
        var next = transform(old)
        require(next.id == old.id && next.creation == null && next.game == old.game && next.schemaVersion == old.schemaVersion)
        if (next == old) return character
        if (next.auspice != old.auspice) next = next.copy(moonGift = null)
        if (next.tribe != old.tribe) next = next.copy(huntersAspect = "")
        if (next.totem.advantages != old.totem.advantages) next = syncTotemMerits(next, old.totem.advantages)
        val before = ForsakenRules(old, catalog); val after = ForsakenRules(next, catalog)
        if (next.form != old.form || after.health() < before.health()) {
            // Swift only replaces the track when there are wounds outside the new capacity.
            if (next.healthTrack.drop(after.health().coerceAtLeast(0)).any { it != Damage.none })
                next = next.copy(healthTrack = next.healthTrack.foldedHealth(after.health()))
        }
        val ledger = ExperienceLedger(next.paidDots, next.changeLog).record(before.traitSnapshot(), after.traitSnapshot(),
            forsakenTraitKindOrder, next.xpMode, false, at, after::experienceCost) { true }
        return ForsakenCharacter(next.copy(paidDots = ledger.paidDots, changeLog = ledger.changeLog), character.original)
    }
    fun renown(character: ForsakenCharacter, kind: Renown, rating: Int, at: Double = foundationNow()) = change(character, at) { state ->
        val credits = state.renownFacetCredits.toMutableMap()
        if (state.xpMode) credits[kind.name] = ((credits[kind.name] ?: 0) + rating - (state.renown[kind.name] ?: 0)).coerceAtLeast(0)
        val values = state.renown.toMutableMap().apply { if (rating > 0) put(kind.name, rating) else remove(kind.name) }
        state.copy(renown = values, renownFacetCredits = credits)
    }
    fun learn(character: ForsakenCharacter, found: CatalogFacet, at: Double = foundationNow()) = change(character, at) { state ->
        if (state.facets.any { it.source.catalog == found.facet.id }) return@change state
        require(found.gift.text("kind") != "moon")
        val free = ForsakenRules(state, catalog).canLearnFree(found)
        val credits = state.renownFacetCredits.toMutableMap()
        found.facet.text("renown")?.takeIf { free }?.let { credits[it] = (credits[it] ?: 1) - 1 }
        state.copy(renownFacetCredits = credits, facets = state.facets + OwnedFacet(TraitSource(catalog = found.facet.id), withRenown = free))
    }
    fun forget(character: ForsakenCharacter, id: SaveId, at: Double = foundationNow()) = change(character, at) { state ->
        val owned = state.facets.firstOrNull { it.id == id } ?: return@change state
        val credits = state.renownFacetCredits.toMutableMap()
        catalog.facet(owned.source.catalog)?.facet?.text("renown")?.takeIf { owned.withRenown }?.let { credits[it] = (credits[it] ?: 0) + 1 }
        state.copy(renownFacetCredits = credits, facets = state.facets.filterNot { it.id == id })
    }
    fun specialty(character: ForsakenCharacter, skill: String, index: Int, previous: String, text: String,
        at: Double = foundationNow()) = change(character, at) { state ->
        if (index < 0) {
            val name = text.trim()
            if (name.isEmpty()) state else state.copy(skills = state.skills.map {
                if (it.skill == skill) it.copy(specialties = it.specialties + name) else it
            })
        } else state.replaceSkillSpecialty(skill, index, previous, text) { merit ->
            catalog.entry(CatalogKind.merits, merit.source.catalog)?.objectValue("qualifier")?.get("fromSpecialties")?.toString() == "true"
        }?.let { state.copy(skills = it.skills, merits = it.merits) } ?: state
    }
    private fun syncTotemMerits(state: ForsakenState, previous: List<TotemAdvantage>): ForsakenState {
        val granted = state.totem.advantages.filter { it.kind == TotemKind.merit }
        val rows = state.merits.toMutableList()
        granted.forEach { if (rows.none { row -> row.source.catalog == it.target }) rows += Merit(TraitSource(catalog = it.target), it.detail.takeIf(String::isNotEmpty), 0) }
        val dropped = previous.filter { it.kind == TotemKind.merit }.map { it.target }.toSet() - granted.map { it.target }.toSet()
        return state.copy(merits = rows.filterNot { it.rating == 0 && it.source.catalog in dropped })
    }
    fun condition(character: ForsakenCharacter, condition: CharacterCondition, event: ConditionEvent, at: Double = foundationNow()) = change(character, at) { state ->
        val entry = catalog.entry(CatalogKind.conditions, condition.source.catalog)
        if (event == ConditionEvent.added && entry != null && !entry.flag("repeatable") && state.conditions.any { it.source == condition.source }) return@change state
        val row = if (event == ConditionEvent.added && entry?.flag("counter") == true && condition.counter == 0) condition.copy(counter = 1) else condition
        val name = catalog.name(CatalogKind.conditions, row.source)
        val title = if (entry?.flag("counter") == true && row.counter > 0) "$name −${row.counter}" else name
        val logName = title + if (row.note.isNotEmpty()) " (${row.note})" else ""
        val hasBeat = (entry?.text("beat") ?: row.customBeat).isNotEmpty()
        val resolve = entry?.fields?.get("beatOnResolve")?.let { (it as? kotlinx.serialization.json.JsonPrimitive)?.content != "false" } ?: true
        val update = state.applyConditionEvent(row, event, logName, hasBeat, resolve, false, at) ?: return@change state
        state.copy(conditions = update.conditions, changeLog = state.changeLog + update.log, beats = update.total.beats, experiences = update.total.experiences)
    }
}
