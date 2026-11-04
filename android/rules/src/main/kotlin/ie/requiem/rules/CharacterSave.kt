package ie.requiem.rules

import java.util.Locale
import java.util.UUID
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

// Foundation writes uppercase UUIDs. Row UUIDs also appear inside paid-dot and log keys.
typealias SaveId = @Serializable(with = SwiftUuidSerializer::class) UUID

object SwiftUuidSerializer : KSerializer<UUID> {
    override val descriptor = PrimitiveSerialDescriptor("SwiftUUID", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): UUID {
        val text = decoder.decodeString()
        val id = UUID.fromString(text)
        require(id.toString().equals(text, ignoreCase = true)) { "Invalid UUID: $text" }
        return id
    }
    override fun serialize(encoder: Encoder, value: UUID) =
        encoder.encodeString(value.toString().uppercase(Locale.ROOT))
}

@Serializable
data class TraitSource(val catalog: String? = null, val custom: String? = null) {
    init { require((catalog == null) != (custom == null)) { "Expected one catalog ID or custom name" } }
}

@Serializable data class Attribute(val attribute: String, val rating: Int = 1)
@Serializable data class Skill(val skill: String, val rating: Int = 0, val specialties: List<String> = emptyList())
@Serializable data class Touchstone(val level: Int, val text: String = "", val id: SaveId = UUID.randomUUID())
@Serializable data class Aspiration(val text: String = "", val id: SaveId = UUID.randomUUID())
@Serializable data class Bane(val source: TraitSource, val id: SaveId = UUID.randomUUID())
@Serializable data class Discipline(val source: TraitSource, val rating: Int = 0, val id: SaveId = UUID.randomUUID())
@Serializable data class Merit(val source: TraitSource, val qualifier: String? = null, val rating: Int = 0, val id: SaveId = UUID.randomUUID())
@Serializable data class Ritual(
    val source: TraitSource,
    val customDiscipline: TraitSource = TraitSource(custom = ""),
    val customDots: Int = 1,
    val id: SaveId = UUID.randomUUID(),
)
@Serializable data class Devotion(val source: TraitSource, val customExperienceCost: Int = 1, val id: SaveId = UUID.randomUUID())
@Serializable data class Coil(val mystery: TraitSource, val rating: Int = 0, val id: SaveId = UUID.randomUUID())
@Serializable data class Scale(val source: TraitSource, val id: SaveId = UUID.randomUUID())
@Serializable enum class Damage { none, bashing, lethal, aggravated }
@Serializable enum class WillpowerMark { none, spent }

private val traitKinds = setOf("attribute", "skill", "specialty", "discipline", "merit", "coil",
    "ritual", "devotion", "scale", "humanity", "bloodPotency")
private fun validTraitKey(key: String) =
    key.substringBefore(':') in traitKinds && key.substringAfter(':', "").isNotEmpty()

@Serializable
data class TraitChange(
    val id: SaveId, val date: Double, val trait: String, val name: String,
    val from: Int, val to: Int, val experiences: Int, val xpMode: Boolean,
    val duringCreation: Boolean? = null,
) {
    init { require(validTraitKey(trait)) { "Invalid log trait: $trait" } }
}

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
internal val attributeIds = listOf(
    "intelligence", "wits", "resolve", "strength", "dexterity", "stamina",
    "presence", "manipulation", "composure",
)
internal val coreSkillIds = listOf(
    "academics", "computer", "crafts", "investigation", "medicine", "occult", "politics", "science",
    "athletics", "brawl", "drive", "firearms", "larceny", "stealth", "survival", "weaponry",
    "animal-ken", "empathy", "expression", "intimidation", "persuasion", "socialize", "streetwise", "subterfuge",
)

internal const val CURRENT_SCHEMA = 9

// Seconds since 2001-01-01 UTC. Retain the Double read from disk, including its fraction.
internal fun foundationNow(): Double = (System.currentTimeMillis() - 978_307_200_000L) / 1000.0

@Serializable
data class CharacterSave(
    val schemaVersion: Int = CURRENT_SCHEMA,
    val id: SaveId = UUID.randomUUID(),
    val createdAt: Double = foundationNow(),
    val modifiedAt: Double = createdAt,
    val name: String = "",
    val player: String = "",
    val chronicle: String = "",
    val mask: String = "",
    val dirge: String = "",
    val concept: String = "",
    val clan: TraitSource = TraitSource(custom = ""),
    val bloodline: String = "",
    val covenant: TraitSource = TraitSource(custom = ""),
    val attributes: List<Attribute> = attributeIds.map { Attribute(it) },
    val skills: List<Skill> = coreSkillIds.map { Skill(it) },
    val skillList: String = "vampire-core",
    val bloodPotency: Int = 1,
    val currentVitae: Int = 0,
    val healthTrack: List<Damage> = emptyList(),
    val willpowerTrack: List<WillpowerMark> = emptyList(),
    val humanity: Int = 7,
    val clanBaneActive: Boolean = false,
    val touchstones: List<Touchstone> = (1..10).map { Touchstone(it) },
    val disciplines: List<Discipline> = emptyList(),
    val merits: List<Merit> = emptyList(),
    val rituals: List<Ritual> = emptyList(),
    val devotions: List<Devotion> = emptyList(),
    val mystery: TraitSource = TraitSource(custom = ""),
    val coils: List<Coil> = emptyList(),
    val scales: List<Scale> = emptyList(),
    val aspirations: List<Aspiration> = listOf(Aspiration()),
    val banes: List<Bane> = emptyList(),
    val size: Int = 5,
    val armor: Int = 0,
    val beats: Int = 0,
    val experiences: Int = 0,
    val xpMode: Boolean = false,
    val changeLog: List<TraitChange> = emptyList(),
    val paidDots: Map<String, Map<Int, Int>> = emptyMap(),
    val creation: CreationState? = null,
) {
    init { require(paidDots.keys.all(::validTraitKey)) { "Invalid paid-dot trait" } }
    val experiencesAvailable: Int get() = experiences - changeLog.sumOf { it.experiences }
}
