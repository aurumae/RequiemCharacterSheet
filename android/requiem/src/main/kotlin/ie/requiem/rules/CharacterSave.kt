package ie.requiem.rules

import java.util.UUID
import kotlinx.serialization.Serializable

@Serializable data class Touchstone(val level: Int, val text: String = "", val id: SaveId = UUID.randomUUID())
@Serializable data class Bane(val source: TraitSource, val id: SaveId = UUID.randomUUID())
@Serializable data class Discipline(val source: TraitSource, val rating: Int = 0, val id: SaveId = UUID.randomUUID())
@Serializable data class Ritual(
    val source: TraitSource,
    val customDiscipline: TraitSource = TraitSource(custom = ""),
    val customDots: Int = 1,
    val id: SaveId = UUID.randomUUID(),
)
@Serializable data class Devotion(val source: TraitSource, val customExperienceCost: Int = 1, val id: SaveId = UUID.randomUUID())
@Serializable data class Coil(val mystery: TraitSource, val rating: Int = 0, val id: SaveId = UUID.randomUUID())
@Serializable data class Scale(val source: TraitSource, val id: SaveId = UUID.randomUUID())

private val traitKinds = setOf("attribute", "skill", "specialty", "discipline", "merit", "coil",
    "ritual", "devotion", "scale", "humanity", "bloodPotency", "condition")
private fun validTraitKey(key: String) =
    key.substringBefore(':') in traitKinds && key.substringAfter(':', "").isNotEmpty()

private val categories = setOf("mental", "physical", "social")
@Serializable
data class CreationState(
    val bonusExperiences: Int = 0,
    val favoredAttribute: String? = null,
    val attributePriorities: Map<String, Int> = emptyMap(),
    val skillPriorities: Map<String, Int> = emptyMap(),
) {
    init {
        require(favoredAttribute == null || favoredAttribute in attributeIds)
        require(attributePriorities.keys.all { it in categories } && skillPriorities.keys.all { it in categories })
    }
}

// These IDs also specify the order in the iOS sheet and its writer.
internal val attributeIds = attributeDefinitions.map { it.id }
internal val coreSkillIds = skillDefinitions.map { it.id }

internal const val CURRENT_SCHEMA = 12

// Seconds since 2001-01-01 UTC. Retain the Double read from disk, including its fraction.
internal fun foundationNow(): Double = ie.chronicles.core.foundationNow()

@Serializable
data class CharacterSave(
    val schemaVersion: Int = CURRENT_SCHEMA,
    val id: SaveId = UUID.randomUUID(),
    val createdAt: Double = foundationNow(),
    val modifiedAt: Double = createdAt,
    override val name: String = "",
    override val player: String = "",
    override val chronicle: String = "",
    val mask: String = "",
    val dirge: String = "",
    override val concept: String = "",
    val clan: TraitSource = TraitSource(custom = ""),
    val bloodline: TraitSource = TraitSource(custom = ""),
    val covenant: TraitSource = TraitSource(custom = ""),
    override val attributes: List<Attribute> = attributeIds.map { Attribute(it) },
    override val skills: List<Skill> = coreSkillIds.map { Skill(it) },
    val skillList: String = "vampire-core",
    val bloodPotency: Int = 1,
    val currentVitae: Int = 0,
    override val healthTrack: List<Damage> = emptyList(),
    override val willpowerTrack: List<WillpowerMark> = emptyList(),
    val humanity: Int = 7,
    val clanBaneActive: Boolean = false,
    val elderBaneActive: Boolean = false,
    val touchstones: List<Touchstone> = (1..10).map { Touchstone(it) },
    val disciplines: List<Discipline> = emptyList(),
    override val merits: List<Merit> = emptyList(),
    val rituals: List<Ritual> = emptyList(),
    val devotions: List<Devotion> = emptyList(),
    val mystery: TraitSource = TraitSource(custom = ""),
    val coils: List<Coil> = emptyList(),
    val scales: List<Scale> = emptyList(),
    override val aspirations: List<Aspiration> = listOf(Aspiration()),
    val banes: List<Bane> = emptyList(),
    val size: Int = 5,
    val armor: Int = 0,
    override val beats: Int = 0,
    override val experiences: Int = 0,
    override val xpMode: Boolean = false,
    override val changeLog: List<TraitChange> = emptyList(),
    val paidDots: Map<String, Map<Int, Int>> = emptyMap(),
    val creation: CreationState? = null,
    override val conditions: List<CharacterCondition> = emptyList(),
) : ie.chronicles.core.ChroniclesCharacter {
    init {
        require(paidDots.keys.all(::validTraitKey)) { "Invalid paid-dot trait" }
        require(changeLog.all { validTraitKey(it.trait) }) { "Invalid log trait" }
    }
    val savedSchemaVersion: Int get() = if (elderBaneActive) 12 else if (conditions.isNotEmpty() || changeLog.any { it.trait.startsWith("condition:") }) 11 else 10
    val experiencesAvailable: Int get() = experiences - changeLog.sumOf { it.experiences }
}
