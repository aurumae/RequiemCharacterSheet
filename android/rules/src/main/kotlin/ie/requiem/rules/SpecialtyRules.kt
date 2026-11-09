package ie.requiem.rules

data class SpecialtyChoice(val skill: String, val specialty: String) {
    val label: String get() = "$specialty (${traitName(skill)})"
}
val CharacterSave.specialtyChoices: List<SpecialtyChoice> get() = skills.flatMap { skill ->
    skill.specialties.mapNotNull { it.trim().takeIf(String::isNotEmpty)?.let { name -> SpecialtyChoice(skill.skill, name) } }
}.distinctBy { it.specialty }
/** Null means free text; an empty list means there is no legal choice yet. */
fun CharacterSave.qualifierChoices(entry: BookEntry): List<String>? = if (entry.qualifierFromSpecialties)
    specialtyChoices.map { it.specialty } else entry.qualifierOptions.takeIf { it.isNotEmpty() }
fun CharacterSave.meritsFollowing(specialty: String, catalog: Catalog): List<Merit> = merits.filter {
    it.qualifier == specialty.trim() && catalog.entry(CatalogKind.merits, it.source)?.qualifierFromSpecialties == true
}
internal fun CharacterSave.replaceSpecialty(action: SheetEdit.ReplaceSpecialty, catalog: Catalog): CharacterSave {
    val skill = skills.firstOrNull { it.skill == action.skill } ?: return this
    if (skill.specialties.getOrNull(action.index) != action.previous) return this
    val name = action.text.trim()
    val next = copy(skills = skills.map {
        if (it.skill != action.skill) it else it.copy(specialties = it.specialties.toMutableList().apply {
            if (name.isEmpty()) removeAt(action.index) else set(action.index, name)
        })
    })
    if (next.specialtyChoices.any { it.specialty == action.previous.trim() }) return next
    val following = meritsFollowing(action.previous, catalog).map { it.id }.toSet()
    return next.copy(merits = if (name.isEmpty()) merits.filterNot { it.id in following }
        else merits.map { if (it.id in following) it.copy(qualifier = name) else it })
}
