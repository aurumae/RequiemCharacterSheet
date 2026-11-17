package ie.chronicles.core

data class SpecialtyEdit(val skills: List<Skill>, val merits: List<Merit>)

fun ChroniclesCharacter.replaceSkillSpecialty(skillId: String, index: Int, previous: String, text: String,
    followsSpecialty: (Merit) -> Boolean): SpecialtyEdit? {
    val skill = skills.firstOrNull { it.skill == skillId } ?: return null
    if (skill.specialties.getOrNull(index) != previous) return null
    val name = text.trim()
    val specialties = skill.specialties.toMutableList()
    if (name.isEmpty()) specialties.removeAt(index) else specialties[index] = name
    val updated = skills.map { if (it == skill) it.copy(specialties = specialties) else it }
    val stillOwned = updated.any { row -> row.specialties.any { it.trim() == previous.trim() && it.isNotBlank() } }
    val updatedMerits = if (stillOwned) merits else merits.mapNotNull {
        if (it.qualifier != previous.trim() || !followsSpecialty(it)) it
        else if (name.isEmpty()) null else it.copy(qualifier = name)
    }
    return SpecialtyEdit(updated, updatedMerits)
}
