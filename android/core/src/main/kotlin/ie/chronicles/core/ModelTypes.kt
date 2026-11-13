package ie.chronicles.core

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

@Serializable data class Aspiration(val text: String = "", val id: SaveId = UUID.randomUUID())

@Serializable data class Merit(val source: TraitSource, val qualifier: String? = null, val rating: Int = 0, val id: SaveId = UUID.randomUUID())

@Serializable enum class Damage { none, bashing, lethal, aggravated }

@Serializable enum class WillpowerMark { none, spent }

@Serializable enum class ConditionEvent { added, ended, resolved, beat }

@Serializable
data class CharacterCondition(
    val source: TraitSource, val id: SaveId = UUID.randomUUID(), val note: String = "",
    val counter: Int = 0, val addedAt: Double = foundationNow(),
    val customEffect: String = "", val customResolution: String = "",
    val customBeat: String = "", val customPersistent: Boolean = false,
)

@Serializable
data class TraitChange(
    val id: SaveId, val date: Double, val trait: String, val name: String,
    val from: Int, val to: Int, val experiences: Int, val xpMode: Boolean,
    val duringCreation: Boolean? = null,
    val event: ConditionEvent? = null, val beats: Int? = null,
) {
    init { require(validTraitKey(trait)) { "Invalid log trait: $trait" } }
}

// Games validate the allowed kind names; core keeps the serialized key open.
fun validTraitKey(key: String): Boolean = key.substringBefore(':').isNotEmpty() && key.substringAfter(':', "").isNotEmpty()

fun foundationNow(): Double = (System.currentTimeMillis() - 978_307_200_000L) / 1000.0
