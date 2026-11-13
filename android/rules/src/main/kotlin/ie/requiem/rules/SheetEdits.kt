package ie.requiem.rules

import java.util.UUID

/** Committed player actions. Loading, rendering and saving never replay an edit. */
sealed interface SheetEdit {
    data class AddCondition(val source: TraitSource, val id: UUID = UUID.randomUUID()) : SheetEdit
    data class ConditionText(val id: UUID, val field: ConditionField, val text: String) : SheetEdit
    data class ConditionCounter(val id: UUID, val value: Int) : SheetEdit
    data class ConditionPersistent(val id: UUID, val value: Boolean) : SheetEdit
    data class ConditionAction(val id: UUID, val event: ConditionEvent) : SheetEdit
    data class Priority(val category: TraitCategory, val priority: CreationPriority, val skills: Boolean) : SheetEdit
    data class FavoredAttribute(val id: String) : SheetEdit
    data class CreationBonus(val experiences: Int) : SheetEdit
    data class FinishCreation(val allowIncomplete: Boolean = false) : SheetEdit
    data object LeaveCreation : SheetEdit
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
    data class Willpower(val index: Int) : SheetEdit
    data class Number(val field: NumberField, val value: Int) : SheetEdit
    data class Counter(val field: NumberField, val delta: Int) : SheetEdit
    data class ClanBane(val active: Boolean) : SheetEdit
    data class ElderBane(val active: Boolean) : SheetEdit
    data class TouchstoneText(val level: Int, val text: String) : SheetEdit
    data class AspirationText(val id: UUID, val text: String) : SheetEdit
    data class AddAspiration(val text: String, val id: UUID = UUID.randomUUID()) : SheetEdit
    data class RemoveAspiration(val id: UUID) : SheetEdit
    data class AddEntry(val kind: EntryKind, val source: TraitSource, val qualifier: String? = null,
        val ritualDiscipline: TraitSource = TraitSource(custom = ""), val ritualDots: Int = 1,
        val devotionCost: Int = 1, val id: UUID = UUID.randomUUID()) : SheetEdit
    data class RemoveEntry(val kind: EntryKind, val id: UUID) : SheetEdit
    data class EntryRating(val kind: EntryKind, val id: UUID, val value: Int) : SheetEdit
    data class RenameEntry(val kind: EntryKind, val id: UUID, val text: String) : SheetEdit
    data class MeritQualifier(val id: UUID, val text: String) : SheetEdit
    data class CustomRitual(val id: UUID, val discipline: TraitSource, val dots: Int) : SheetEdit
    data class CustomDevotionCost(val id: UUID, val value: Int) : SheetEdit
    data class Mystery(val source: TraitSource, val rename: Boolean = false, val coilId: UUID = UUID.randomUUID()) : SheetEdit
}

enum class EntryKind(val title: String, val catalogKind: CatalogKind) {
    Discipline("Discipline", CatalogKind.disciplines), Merit("Merit", CatalogKind.merits), Bane("Bane", CatalogKind.banes),
    Ritual("Ritual", CatalogKind.rituals), Devotion("Devotion", CatalogKind.devotions), Coil("Coil", CatalogKind.mysteries), Scale("Scale", CatalogKind.scales)
}
enum class NumberField(val title: String) { BloodPotency("Blood Potency"), Humanity("Humanity"), Vitae("Current Vitae"), Armor("Armor"), Beats("Beats"), Experiences("Earned") }
fun CharacterSave.number(field: NumberField): Int = when (field) {
    NumberField.BloodPotency -> bloodPotency; NumberField.Humanity -> humanity; NumberField.Vitae -> currentVitae
    NumberField.Armor -> armor; NumberField.Beats -> beats; NumberField.Experiences -> experiences
}
fun CharacterSave.numberRange(field: NumberField): IntRange = when (field) {
    NumberField.BloodPotency -> 0..10; NumberField.Humanity -> 1..10; NumberField.Vitae -> 0..maxVitae
    NumberField.Armor -> 0..99; NumberField.Beats -> 0..4; NumberField.Experiences -> 0..Int.MAX_VALUE
}
val CharacterSave.stamina: Int get() = attributeRating("stamina")
val CharacterSave.staminaCap: Int get() = legalRatings(RatingKind.Attribute, bloodPotency).last

fun CharacterSave.edit(action: SheetEdit, catalog: Catalog, at: Double = foundationNow()): CharacterSave {
    if (!creationAllowsEdit(action, catalog)) return this
    val applied = applyEdit(action, catalog, at)
    val next = if (applied.creation != null && applied.xpMode) applied.copy(xpMode = false) else applied
    if (next == this) return this
    // Remove invisible marks immediately: an edit made before the next write must not
    // resurrect a box discarded by reducing Health or Willpower.
    return next.copy(healthTrack = next.healthTrack.take(next.health(catalog).coerceAtLeast(0)),
        willpowerTrack = next.willpowerTrack.take(next.willpower.coerceAtLeast(0)),
        currentVitae = next.currentVitae.coerceIn(0, next.maxVitae.coerceAtLeast(0)))
        .recordChanges(this, catalog, at)
}

internal fun CharacterSave.applyEdit(action: SheetEdit, catalog: Catalog, at: Double = foundationNow()): CharacterSave = when (action) {
    is SheetEdit.AddCondition, is SheetEdit.ConditionText, is SheetEdit.ConditionCounter,
    is SheetEdit.ConditionPersistent, is SheetEdit.ConditionAction -> editCondition(action, catalog, at)
    is SheetEdit.Priority -> setPriority(action)
    is SheetEdit.FavoredAttribute -> chooseFavoredAttribute(action.id, catalog)
    is SheetEdit.CreationBonus -> if (creation != null && CreationRules.ranks.any { it.second == action.experiences }) copy(creation = creation.copy(bonusExperiences = action.experiences)) else this
    is SheetEdit.FinishCreation -> if (creation != null && creationReport(catalog).withinLimits &&
        (action.allowIncomplete || creationSteps(catalog).all { it.status == CreationStepStatus.Done }) && CreationRules.ranks.any { it.second == creation.bonusExperiences })
        copy(creation = null, experiences = (experiences.toLong() + creation.bonusExperiences).coerceAtMost(Int.MAX_VALUE.toLong()).toInt(), xpMode = true) else this
    SheetEdit.LeaveCreation -> if (creation == null) this else copy(creation = null, xpMode = false)
    is SheetEdit.Rename -> copy(name = action.name)
    is SheetEdit.Detail -> editDetail(action.field, action.text, catalog)
    is SheetEdit.XpMode -> copy(xpMode = action.enabled)
    is SheetEdit.StaminaRating -> applyEdit(SheetEdit.AttributeRating("stamina", action.rating), catalog)
    is SheetEdit.Stamina -> applyEdit(SheetEdit.AttributeRating("stamina", stamina + action.delta), catalog)
    is SheetEdit.AttributeRating -> copy(attributes = attributes.map { if (it.attribute == action.id) it.copy(rating = action.rating.coerceIn(legalRatings(RatingKind.Attribute, bloodPotency))) else it })
    is SheetEdit.SkillRating -> copy(skills = skills.map { if (it.skill == action.id) it.copy(rating = action.rating.coerceIn(legalRatings(RatingKind.Skill, bloodPotency))) else it })
    is SheetEdit.Mark -> if (action.index !in 0 until health(catalog)) this else copy(healthTrack = List(health(catalog)) { i ->
        val old = healthTrack.getOrElse(i) { Damage.none }; if (i == action.index) Damage.entries[(old.ordinal + 1) % Damage.entries.size] else old })
    is SheetEdit.Willpower -> if (action.index !in 0 until willpower) this else copy(willpowerTrack = List(willpower) { i ->
        val old = willpowerTrack.getOrElse(i) { WillpowerMark.none }; if (i == action.index) if (old == WillpowerMark.none) WillpowerMark.spent else WillpowerMark.none else old })
    is SheetEdit.AddSpecialty -> if (action.text.isBlank()) this else copy(skills = skills.map { if (it.skill == action.skill) it.copy(specialties = it.specialties + action.text.trim()) else it })
    is SheetEdit.ReplaceSpecialty -> replaceSpecialty(action, catalog)
    is SheetEdit.Number -> setNumber(action.field, action.value, catalog)
    is SheetEdit.Counter -> {
        if (action.field == NumberField.Beats && action.delta > 0 && beats >= 4) copy(beats = 0, experiences = (experiences.toLong() + 1).coerceAtMost(Int.MAX_VALUE.toLong()).toInt())
        else setNumber(action.field, (number(action.field).toLong() + action.delta).coerceIn(0, Int.MAX_VALUE.toLong()).toInt(), catalog)
    }
    is SheetEdit.ClanBane -> copy(clanBaneActive = action.active)
    is SheetEdit.ElderBane -> copy(elderBaneActive = action.active)
    is SheetEdit.TouchstoneText -> copy(touchstones = touchstones.map { if (it.level == action.level) it.copy(text = action.text) else it })
    is SheetEdit.AspirationText -> copy(aspirations = aspirations.map { if (it.id == action.id) it.copy(text = action.text) else it })
    is SheetEdit.AddAspiration -> if (aspirations.any { it.id == action.id }) this else copy(aspirations = aspirations + Aspiration(action.text, action.id))
    is SheetEdit.RemoveAspiration -> copy(aspirations = aspirations.filterNot { it.id == action.id })
    is SheetEdit.AddEntry -> addEntry(action, catalog)
    is SheetEdit.RemoveEntry -> removeEntry(action)
    is SheetEdit.EntryRating -> rateEntry(action, catalog)
    is SheetEdit.RenameEntry -> renameEntry(action, catalog)
    is SheetEdit.MeritQualifier -> copy(merits = merits.map {
        val entry = catalog.entry(CatalogKind.merits, it.source)
        if (it.id != action.id || (entry != null && !validQualifier(entry, action.text, catalog))) it else it.copy(qualifier = action.text.trim().ifEmpty { null }) })
    is SheetEdit.CustomRitual -> copy(rituals = rituals.map { if (it.id == action.id && catalog.entry(CatalogKind.rituals, it.source) == null)
        it.copy(customDiscipline = action.discipline, customDots = action.dots.coerceIn(1, 5)) else it })
    is SheetEdit.CustomDevotionCost -> copy(devotions = devotions.map { if (it.id == action.id && catalog.entry(CatalogKind.devotions, it.source) == null)
        it.copy(customExperienceCost = action.value.coerceIn(1, 20)) else it })
    is SheetEdit.Mystery -> if (catalog.entry(CatalogKind.mysteries, action.source)?.coilOnly == true) this else chooseMystery(action)
}

private fun CharacterSave.setNumber(field: NumberField, value: Int, catalog: Catalog): CharacterSave {
    val to = value.coerceIn(numberRange(field))
    return when (field) {
        NumberField.BloodPotency -> {
            val cap = legalRatings(RatingKind.Attribute, to).last
            copy(bloodPotency = to, attributes = attributes.map { it.copy(rating = it.rating.coerceIn(1, cap)) }, skills = skills.map { it.copy(rating = it.rating.coerceIn(0, cap)) })
        }
        NumberField.Humanity -> copy(humanity = to,
            clanBaneActive = clanBaneActive || (clanBane(catalog)?.let { to <= it.threshold && humanity > it.threshold } == true),
            elderBaneActive = elderBaneActive || (elderBane(catalog)?.let { to <= it.threshold && humanity > it.threshold } == true))
        NumberField.Vitae -> copy(currentVitae = to)
        NumberField.Armor -> copy(armor = to)
        NumberField.Beats -> copy(beats = to)
        NumberField.Experiences -> copy(experiences = to)
    }
}

private fun CharacterSave.editDetail(field: CharacterDetail, text: String, catalog: Catalog): CharacterSave = when (field) {
    CharacterDetail.Name -> copy(name = text); CharacterDetail.Player -> copy(player = text)
    CharacterDetail.Chronicle -> copy(chronicle = text); CharacterDetail.Mask -> copy(mask = text)
    CharacterDetail.Dirge -> copy(dirge = text); CharacterDetail.Concept -> copy(concept = text)
    CharacterDetail.Bloodline -> copy(bloodline = catalog.source(CatalogKind.bloodlines, text)).reconcileFavoredAttribute(catalog)
    CharacterDetail.Covenant -> copy(covenant = catalog.source(CatalogKind.covenants, text))
    CharacterDetail.Clan -> {
        val source = catalog.source(CatalogKind.clans, text)
        val changed = copy(clan = source)
        val next = changed.reconcileFavoredAttribute(catalog)
        next.copy(clanBaneActive = clanBaneActive || (clan != source && next.clanBane(catalog)?.let { humanity <= it.threshold } == true),
            elderBaneActive = if (clan == source) elderBaneActive else next.elderBane(catalog)?.let { humanity <= it.threshold } == true)
    }
}

private fun CharacterSave.addEntry(a: SheetEdit.AddEntry, catalog: Catalog): CharacterSave {
    val entry = catalog.entry(a.kind.catalogKind, a.source)
    if (a.source.catalog != null && entry == null) return this
    if (a.kind == EntryKind.Discipline && entry != null && reasonCantLearn(entry, catalog) != null) return this
    val owned = entryRows(a.kind, catalog)
    if (owned.any { it.id == a.id } || (a.source.catalog != null && owned.any { it.source == a.source } && !(a.kind == EntryKind.Merit && entry?.repeatable == true))) return this
    return when (a.kind) {
        EntryKind.Discipline -> copy(disciplines = disciplines + Discipline(a.source, 1, a.id))
        EntryKind.Merit -> {
            if (entry != null && !validQualifier(entry, a.qualifier, catalog)) this
            else copy(merits = merits + Merit(a.source, a.qualifier?.trim()?.ifEmpty { null }, entry?.ratings?.minOrNull() ?: 1, a.id))
        }
        EntryKind.Bane -> if (banes.size >= 3) this else copy(banes = banes + Bane(a.source, a.id))
        EntryKind.Ritual -> copy(rituals = rituals + Ritual(a.source, a.ritualDiscipline, a.ritualDots.coerceIn(1, 5), a.id))
        EntryKind.Devotion -> copy(devotions = devotions + Devotion(a.source, a.devotionCost.coerceIn(1, 20), a.id))
        EntryKind.Coil -> copy(coils = coils + Coil(a.source, 0, a.id))
        EntryKind.Scale -> copy(scales = scales + Scale(a.source, a.id))
    }
}
private fun CharacterSave.removeEntry(a: SheetEdit.RemoveEntry): CharacterSave = when (a.kind) {
    EntryKind.Discipline -> copy(disciplines = disciplines.filterNot { it.id == a.id })
    EntryKind.Merit -> copy(merits = merits.filterNot { it.id == a.id })
    EntryKind.Bane -> copy(banes = banes.filterNot { it.id == a.id })
    EntryKind.Ritual -> copy(rituals = rituals.filterNot { it.id == a.id })
    EntryKind.Devotion -> copy(devotions = devotions.filterNot { it.id == a.id })
    EntryKind.Coil -> copy(coils = coils.filterNot { it.id == a.id })
    EntryKind.Scale -> copy(scales = scales.filterNot { it.id == a.id })
}
private fun CharacterSave.rateEntry(a: SheetEdit.EntryRating, catalog: Catalog): CharacterSave = when (a.kind) {
    EntryKind.Discipline -> copy(disciplines = disciplines.map { if (it.id == a.id) it.copy(rating = a.value.coerceIn(0, 5)) else it })
    EntryKind.Merit -> copy(merits = merits.map { if (it.id == a.id) it.copy(rating = catalog.entry(CatalogKind.merits, it.source)?.allowedRating(a.value) ?: a.value.coerceIn(0, 5)) else it })
    EntryKind.Coil -> copy(coils = coils.map { if (it.id == a.id) it.copy(rating = a.value.coerceIn(0, 5)) else it })
    EntryKind.Ritual -> copy(rituals = rituals.map { if (it.id == a.id && catalog.entry(CatalogKind.rituals, it.source) == null) it.copy(customDots = a.value.coerceIn(1, 5)) else it })
    else -> this
}
private fun CharacterSave.renameEntry(a: SheetEdit.RenameEntry, catalog: Catalog): CharacterSave {
    val row = entryRows(a.kind, catalog).firstOrNull { it.id == a.id } ?: return this
    if (catalog.entry(a.kind.catalogKind, row.source) != null) return this
    val source = catalog.source(a.kind.catalogKind, a.text)
    return when (a.kind) {
        EntryKind.Discipline -> copy(disciplines = disciplines.map { if (it.id == a.id) it.copy(source = source) else it })
        EntryKind.Merit -> { val (s, q) = catalog.parseMerit(a.text); copy(merits = merits.map { if (it.id == a.id) it.copy(source = s, qualifier = q) else it }) }
        EntryKind.Bane -> copy(banes = banes.map { if (it.id == a.id) it.copy(source = source) else it })
        EntryKind.Ritual -> copy(rituals = rituals.map { if (it.id == a.id) it.copy(source = source) else it })
        EntryKind.Devotion -> copy(devotions = devotions.map { if (it.id == a.id) it.copy(source = source) else it })
        EntryKind.Coil -> copy(coils = coils.map { if (it.id == a.id) it.copy(mystery = source) else it })
        EntryKind.Scale -> copy(scales = scales.map { if (it.id == a.id) it.copy(source = source) else it })
    }
}
private fun CharacterSave.chooseMystery(a: SheetEdit.Mystery): CharacterSave {
    var next = coils
    val old = mystery
    if (a.rename && old != TraitSource(custom = "") && coils.any { it.mystery == old } && coils.none { it.mystery == a.source }) {
        val first = coils.first { it.mystery == old }.id
        next = coils.map { if (it.id == first) it.copy(mystery = a.source) else it }
    } else if (a.source != TraitSource(custom = "") && coils.none { it.mystery == a.source }) next = listOf(Coil(a.source, 0, a.coilId)) + coils
    return copy(mystery = a.source, coils = next)
}
