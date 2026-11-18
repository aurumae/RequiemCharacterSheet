package ie.forsaken.rules

import ie.chronicles.core.*
import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

@Serializable enum class Form { hishu, dalu, gauru, urshul, urhan }
@Serializable enum class Renown { cunning, glory, honor, purity, wisdom }
@Serializable enum class GiftKind { moon, shadow, wolf }
@Serializable enum class TotemKind { attribute, skill, specialty, merit }

@Serializable data class KuruthTriggers(val passive: String = "", val common: String = "", val specific: String = "")
@Serializable data class OwnedFacet(
    val source: TraitSource, val id: SaveId = UUID.randomUUID(),
    val customGift: String = "", val customKind: GiftKind = GiftKind.shadow,
    val active: Boolean = false, val withRenown: Boolean = false,
)
@Serializable data class OwnedMoonGift(
    val source: TraitSource, val id: SaveId = UUID.randomUUID(), val dots: Int = 1,
    val facets: List<String> = emptyList(),
)
@Serializable data class OwnedRite(
    val source: TraitSource, val id: SaveId = UUID.randomUUID(), val customRating: Int = 1, val active: Boolean = false,
)
@Serializable data class OwnedFetish(
    val source: TraitSource, val id: SaveId = UUID.randomUUID(), val customRating: Int = 1, val note: String = "",
)
@Serializable data class TotemAdvantage(
    val kind: TotemKind, val target: String, val id: SaveId = UUID.randomUUID(), val detail: String = "", val dots: Int = 1,
)
@Serializable data class Totem(
    val name: String = "", val aspiration: String = "", val ban: String = "", val packPoints: Int = 0,
    val advantages: List<TotemAdvantage> = emptyList(),
)
@Serializable data class FormDrawback(val form: Form? = null, val attribute: String? = null)
@Serializable data class FavoredForm(
    val attributes: List<String?> = emptyList(), val drawbacks: List<FormDrawback> = emptyList(),
)
@Serializable data class CreationState(
    val attributePriorities: Map<String, Int> = emptyMap(), val skillPriorities: Map<String, Int> = emptyMap(),
    val freeSkill: String? = null, val grantedRenown: List<Renown> = emptyList(),
)

/** Schema-1 saved values. Effective ratings and mutations belong to the ordinary-play rules, not the viewer. */
@Serializable data class ForsakenState(
    val game: String = "forsaken", val schemaVersion: Int = 1,
    val id: SaveId = UUID.randomUUID(), val createdAt: Double = foundationNow(), val modifiedAt: Double = createdAt,
    val name: String = "", val player: String = "", val chronicle: String = "", val concept: String = "",
    val blood: TraitSource = TraitSource(custom = ""), val bone: TraitSource = TraitSource(custom = ""),
    val auspice: TraitSource = TraitSource(custom = ""), val tribe: TraitSource = TraitSource(custom = ""),
    val lodge: TraitSource = TraitSource(custom = ""), val huntersAspect: String = "",
    val attributes: List<Attribute> = attributeDefinitions.map { Attribute(it.id) },
    val skills: List<Skill> = modernSkillDefinitions.map { Skill(it.id) },
    val merits: List<Merit> = emptyList(), val aspirations: List<Aspiration> = listOf(Aspiration()),
    val conditions: List<CharacterCondition> = emptyList(),
    val renown: Map<String, Int> = emptyMap(), val primalUrge: Int = 1, val essence: Int = 7, val harmony: Int = 7,
    val fleshTouchstone: String = "", val spiritTouchstone: String = "",
    val kuruthTriggerSet: TraitSource = TraitSource(custom = ""), val kuruthTriggers: KuruthTriggers = KuruthTriggers(),
    val form: Form = Form.hishu, val moonGift: TraitSource? = null, val moonFacets: List<String> = emptyList(),
    val extraMoonGifts: List<OwnedMoonGift> = emptyList(), val facets: List<OwnedFacet> = emptyList(),
    val rites: List<OwnedRite> = emptyList(), val fetishes: List<OwnedFetish> = emptyList(), val totem: Totem = Totem(),
    val size: Int = 5, val armor: Int = 0, val ballisticArmor: Int = 0,
    val renownFacetCredits: Map<String, Int> = emptyMap(), val favoredForm: FavoredForm = FavoredForm(),
    val healthTrack: List<Damage> = emptyList(), val willpowerTrack: List<WillpowerMark> = emptyList(),
    val beats: Int = 0, val experiences: Int = 0, val xpMode: Boolean = false, val creation: CreationState? = null,
    val changeLog: List<TraitChange> = emptyList(), val paidDots: Map<String, Map<Int, Int>> = emptyMap(),
    val showsUnofficialContent: Boolean = false,
)

/** The original JSON remains separate from decoded values. No preview operation canonically rewrites it. */
class ForsakenCharacter internal constructor(val state: ForsakenState, internal val original: JsonObject) : StoredCharacter {
    override val id get() = state.id
    override val name get() = state.name
    override val modifiedAt get() = state.modifiedAt
}
