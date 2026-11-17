package ie.requiem.rules

import ie.chronicles.core.replaceSkillSpecialty
import ie.chronicles.core.specialtyChoices as coreSpecialtyChoices

val SpecialtyChoice.label: String get() = "$specialty (${traitName(skill)})"
val CharacterSave.specialtyChoices: List<SpecialtyChoice> get() = coreSpecialtyChoices
/** Null means free text; an empty list means there is no legal choice yet. */
fun CharacterSave.qualifierChoices(entry: BookEntry, catalog: Catalog): List<String>? = when {
    entry.qualifierFromSpecialties -> specialtyChoices.map { it.specialty }
    entry.qualifierFromCovenants -> catalog.names(CatalogKind.covenants).ifEmpty { entry.qualifierOptions }
    else -> entry.qualifierOptions.takeIf { it.isNotEmpty() }
}
fun CharacterSave.validQualifier(entry: BookEntry, value: String?, catalog: Catalog): Boolean =
    if (entry.qualifierPrompt == null) true else !value.isNullOrBlank() && (qualifierChoices(entry, catalog)?.let { value.trim() in it } != false)
fun CharacterSave.meritsFollowing(specialty: String, catalog: Catalog): List<Merit> = merits.filter {
    it.qualifier == specialty.trim() && catalog.entry(CatalogKind.merits, it.source)?.qualifierFromSpecialties == true
}
internal fun CharacterSave.replaceSpecialty(action: SheetEdit.ReplaceSpecialty, catalog: Catalog): CharacterSave {
    val next = replaceSkillSpecialty(action.skill, action.index, action.previous, action.text) {
        catalog.entry(CatalogKind.merits, it.source)?.qualifierFromSpecialties == true
    } ?: return this
    return copy(skills = next.skills, merits = next.merits)
}
