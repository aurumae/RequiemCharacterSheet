package ie.chronicles.core

/** Shared, immutable character view. Each game retains its own saved properties and edits. */
interface ChroniclesCharacter {
    val name: String
    val player: String
    val chronicle: String
    val concept: String
    val attributes: List<Attribute>
    val skills: List<Skill>
    val merits: List<Merit>
    val aspirations: List<Aspiration>
    val conditions: List<CharacterCondition>
    val healthTrack: List<Damage>
    val willpowerBonus: Int get() = 0
    val willpowerTrack: List<WillpowerMark>
    val beats: Int
    val experiences: Int
    val xpMode: Boolean
    val changeLog: List<TraitChange>
}
fun ChroniclesCharacter.attributeRating(id: String): Int = attributes.firstOrNull { it.attribute == id }?.rating ?: 0
fun ChroniclesCharacter.skillRating(id: String): Int = skills.firstOrNull { it.skill == id }?.rating ?: 0
val ChroniclesCharacter.willpower: Int get() = attributeRating("resolve") + attributeRating("composure") + willpowerBonus
data class SpecialtyChoice(val skill: String, val specialty: String)
val ChroniclesCharacter.specialtyChoices: List<SpecialtyChoice> get() = skills.flatMap { skill ->
    skill.specialties.mapNotNull { it.trim().takeIf(String::isNotEmpty)?.let { name -> SpecialtyChoice(skill.skill, name) } }
}.distinctBy { it.specialty }

/** Visible tracks pad empty boxes and discard hidden overflow only when explicitly written. */
fun <T> List<T>.visibleTrack(size: Int, empty: T): List<T> = List(size.coerceAtLeast(0)) { getOrElse(it) { empty } }
fun <T> List<T>.editBox(size: Int, index: Int, empty: T, change: (T) -> T): List<T> {
    if (index !in 0 until size) return this
    return List(size) { i ->
        val value = getOrElse(i) { empty }
        if (i == index) change(value) else value
    }
}

fun <T, K> mergeTraits(defaults: List<T>, saved: List<T>, key: (T) -> K): List<T> {
    val savedByKey = saved.asReversed().associateBy(key)
    val defaultKeys = defaults.map(key).toSet()
    return defaults.map { savedByKey[key(it)] ?: it } + saved.filter { key(it) !in defaultKeys }
}
data class BeatTotal(val beats: Int, val experiences: Int)
fun incrementBeat(beats: Int, experiences: Int): BeatTotal = if (beats >= 4)
    BeatTotal(0, (experiences.toLong() + 1).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()) else BeatTotal(beats + 1, experiences)

/** Used by games that keep wounds when temporary Health boxes disappear. */
fun List<Damage>.foldedHealth(boxes: Int): List<Damage> {
    val size = boxes.coerceAtLeast(0)
    val result = visibleTrack(size, Damage.none).toMutableList()
    for (index in size until this.size) {
        val wound = this[index]
        if (wound == Damage.none) continue
        val target = listOf(Damage.none, Damage.bashing, Damage.lethal)
            .firstNotNullOfOrNull { grade -> result.indexOf(grade).takeIf { it >= 0 } } ?: break
        result[target] = when (result[target]) {
            Damage.none -> wound
            Damage.bashing -> Damage.lethal
            else -> Damage.aggravated
        }
    }
    return result
}
