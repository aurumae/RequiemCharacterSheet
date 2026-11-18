package ie.forsaken.rules

import ie.chronicles.core.*
import kotlinx.serialization.json.*
import kotlin.math.abs

val Form.title: String get() = name.replaceFirstChar(Char::uppercaseChar)
val Renown.title: String get() = name.replaceFirstChar(Char::uppercaseChar)
fun traitTitle(id: String) = (attributeDefinitions + modernSkillDefinitions).firstOrNull { it.id == id }?.name
    ?: id.replaceFirstChar(Char::uppercaseChar)
val Form.attributeModifiers: Map<String, Int> get() = when (this) {
    Form.hishu -> emptyMap()
    Form.dalu -> mapOf("strength" to 1, "stamina" to 1, "manipulation" to -1)
    Form.gauru -> mapOf("strength" to 3, "dexterity" to 1, "stamina" to 2)
    Form.urshul -> mapOf("strength" to 2, "dexterity" to 2, "stamina" to 2, "manipulation" to -1)
    Form.urhan -> mapOf("dexterity" to 2, "stamina" to 1, "manipulation" to -1)
}
val Form.sizeModifier get() = when (this) { Form.hishu -> 0; Form.dalu, Form.urshul -> 1; Form.gauru -> 2; Form.urhan -> -1 }
val Form.speedBonus get() = if (this == Form.urshul || this == Form.urhan) 3 else 0
val Form.perceptionBonus get() = when (this) { Form.hishu -> 1; Form.dalu -> 2; Form.gauru, Form.urshul -> 3; Form.urhan -> 4 }
val Form.description get() = when (this) {
    Form.hishu -> "Human"; Form.dalu -> "Near-Human"; Form.gauru -> "Wolf-Man"; Form.urshul -> "Near-Wolf"; Form.urhan -> "Wolf"
}
val Form.notes get() = when (this) {
    Form.hishu -> "Perception bonus only with wolf senses. Sheep's Clothing."
    Form.dalu -> "Lunacy (witnesses +2). Claws do lethal damage; Defense applies against Firearms."
    Form.gauru -> "Lunacy (witnesses −2). Claws and bite +2L; Initiative +3 with teeth or claws; regenerates bashing and lethal damage each turn; Primal Fear. Fails Social rolls except Intimidation and Mental rolls except Perception and resistance. Held for Stamina + Primal Urge turns, once per scene."
    Form.urshul -> "Lunacy. Claws +1L, bite +2L; Weaken the Prey."
    Form.urhan -> "Bite +1L; Chase Down."
}
data class PrimalUrgeLevel(val traitMaximum: Int, val essenceMaximum: Int, val essencePerTurn: Int,
    val regeneration: Int, val feeding: String, val lunacyPenalty: Int, val trackingBonus: Int) {
    companion object {
        private val table = listOf(
            PrimalUrgeLevel(5,10,1,1,"None",0,0), PrimalUrgeLevel(5,11,2,1,"Meat",0,0),
            PrimalUrgeLevel(5,12,3,1,"Meat",0,0), PrimalUrgeLevel(5,13,4,2,"Raw meat",-2,1),
            PrimalUrgeLevel(5,15,5,2,"Raw meat",-2,1), PrimalUrgeLevel(6,20,6,3,"Carnivore",-2,2),
            PrimalUrgeLevel(7,25,7,3,"Carnivore",-2,2), PrimalUrgeLevel(8,30,8,4,"Essence",-3,3),
            PrimalUrgeLevel(9,50,10,5,"Essence",-4,3), PrimalUrgeLevel(10,75,15,6,"Essence",-5,4),
        )
        fun level(value: Int) = table[value.coerceIn(1, 10) - 1]
    }
}
enum class TriggerKind { passive, common, specific;
    fun applies(harmony: Int): Boolean = when (this) {
        passive -> abs(harmony - 5) == 5; common -> abs(harmony - 5) >= 3; specific -> abs(harmony - 5) >= 1
    }
}
val generalKuruthTriggers = listOf("Spending too long in Gauru", "Taking Gauru outside of combat",
    "Taking damage from silver", "Being forced into Kuruth by an Elodoth")
val totemMeritsNeverGranted = setOf("dedicated-locus", "totem")
val Totem.experienceBudget get() = when (packPoints) { in Int.MIN_VALUE..0 -> 0; in 1..8 -> 1; in 9..14 -> 3; in 15..20 -> 5; else -> 10 }
val TotemAdvantage.cost get() = when (kind) { TotemKind.attribute -> 4 * dots; TotemKind.skill -> 2 * dots; TotemKind.specialty -> 1; TotemKind.merit -> dots }
val Totem.experiencesSpent get() = advantages.sumOf { it.cost }
fun Totem.dots(kind: TotemKind, target: String) = advantages.filter { it.kind == kind && it.target == target }.sumOf { it.dots }

internal fun JsonObject.text(key: String) = (get(key) as? JsonPrimitive)?.contentOrNull
internal fun JsonObject.number(key: String) = (get(key) as? JsonPrimitive)?.intOrNull
internal fun JsonObject.objects(key: String) = (get(key) as? JsonArray).orEmpty().mapNotNull { it as? JsonObject }
internal fun JsonElement?.amount(rating: Int) = when (this) {
    is JsonPrimitive -> if (isString && content == "rating") rating else 0
    is JsonObject -> number("fixed") ?: 0
    else -> 0
}
data class AppliedPower(val name: String, val effect: JsonObject, val rating: Int, val forms: List<String>?)
data class WorkedDicePool(val dice: Int, val traits: String, val against: String) {
    val summary get() = if (dice <= 0) "Chance die" else "$dice ${if (dice == 1) "die" else "dice"}"
}
data class FacetPrice(val experiences: Int, val renown: Renown? = null, val unlocksGift: Boolean = false)

/** Pure calculations from the submitted Swift model. Catalog mechanics remain game-specific. */
class ForsakenRules(val state: ForsakenState, val catalog: ForsakenCatalog = ForsakenCatalog.bundled) {
    val tribe get() = catalog.entry(CatalogKind.tribes, state.tribe.catalog)
    val auspice get() = catalog.entry(CatalogKind.auspices, state.auspice.catalog)
    val lodge get() = catalog.entry(CatalogKind.lodges, state.lodge.catalog)
    val isPure get() = tribe?.text("kind") == "pure"
    val effectiveAuspice get() = auspice.takeUnless { isPure }
    val huntersAspect: JsonObject? get() = if (!isPure) auspice?.objectValue("huntersAspect") else
        tribe?.array("huntersAspects")?.mapNotNull { it as? JsonObject }?.firstOrNull { it.text("name") == state.huntersAspect }
    fun renown(kind: Renown) = state.renown[kind.name] ?: 0
    val spiritRank get() = when (Renown.entries.sumOf(::renown)) { in Int.MIN_VALUE..3 -> 1; in 4..7 -> 2; in 8..12 -> 3; in 13..18 -> 4; else -> 5 }
    val primalUrge get() = PrimalUrgeLevel.level(state.primalUrge)
    val baseRatingCap get() = primalUrge.traitMaximum
    val moonGiftRenown get() = Renown.entries.firstOrNull { it.name == effectiveAuspice?.text("renown") }
    val moonGiftDots get() = moonGiftRenown?.let { renown(it).coerceAtMost(5) } ?: 0
    val moonGift: ForsakenEntry? get() = if (isPure) null else when {
        state.moonGift?.custom != null -> null
        state.moonGift?.catalog != null -> catalog.entry(CatalogKind.gifts, state.moonGift.catalog)
        else -> catalog.entry(CatalogKind.gifts, effectiveAuspice?.text("moonGift"))
    }
    val moonGiftName get() = state.moonGift?.custom ?: moonGift?.name.orEmpty()
    fun moonDots(owned: OwnedMoonGift) = minOf(owned.dots, moonGiftDots)
    val affinityGifts get() = (effectiveAuspice?.strings("giftAffinities").orEmpty() + tribe?.strings("giftAffinities").orEmpty()).toSet()
    fun hasAffinity(gift: ForsakenEntry) = gift.id in affinityGifts || gift.text("replaces") in affinityGifts
    fun gift(facet: OwnedFacet) = catalog.facet(facet.source.catalog)?.gift
    fun facetName(facet: OwnedFacet) = facet.source.custom ?: catalog.facet(facet.source.catalog)?.facet?.name ?: facet.source.catalog.orEmpty()
    fun riteRating(rite: OwnedRite) = catalog.entry(CatalogKind.rites, rite.source.catalog)?.number("rating") ?: rite.customRating
    fun kuruthTrigger(kind: TriggerKind) = catalog.entry(CatalogKind.kuruthTriggers, state.kuruthTriggerSet.catalog)?.text(kind.name)
        ?: when (kind) { TriggerKind.passive -> state.kuruthTriggers.passive; TriggerKind.common -> state.kuruthTriggers.common; TriggerKind.specific -> state.kuruthTriggers.specific }
    fun lodgesTeaching(kind: String, id: String?) = if (id == null) emptyList() else catalog.all(CatalogKind.lodges).filter { id in it.strings(kind) }
    fun lodgeMultiplier(lodges: List<ForsakenEntry>) = if (lodges.isEmpty() || lodges.any { it.id == state.lodge.catalog }) 1 else 3
    fun meritBonus(id: String) = state.totem.dots(TotemKind.merit, id)
    fun meritDots(id: String) = (state.merits.filter { it.source.catalog == id }.maxOfOrNull { it.rating } ?: 0) + meritBonus(id)
    fun prerequisitesApply(merit: Merit) = merit.source.catalog?.let { meritBonus(it) == 0 } ?: true
    fun grantedSpecialties(id: String) = state.totem.advantages.filter { it.kind == TotemKind.specialty && it.target == id && it.detail.isNotEmpty() }.map { it.detail }
    private fun embodiesFirstborn(id: String) = state.merits.any { it.source.catalog == "embodiment-of-the-firstborn" && it.rating > 0 && it.qualifier.equals(traitTitle(id), true) }
    fun attributeBonus(id: String) = state.totem.dots(TotemKind.attribute, id) + if (embodiesFirstborn(id)) 1 else 0
    fun overLimitAllowance(id: String) = (if (state.totem.dots(TotemKind.attribute, id) > 0) 1 else 0) + if (embodiesFirstborn(id)) 1 else 0
    fun countedBaseAttribute(id: String): Int {
        val bought = state.attributeRating(id)
        return minOf(bought + attributeBonus(id), maxOf(bought, baseRatingCap + overLimitAllowance(id)))
    }
    val favoredForm: Pair<Form, Int>? get() {
        val dots = meritDots("favored-form")
        val name = state.merits.firstOrNull { it.source.catalog == "favored-form" }?.qualifier
        val form = Form.entries.firstOrNull { it.title.equals(name, true) && it != Form.hishu }
        return if (dots > 0 && form != null) form to dots else null
    }
    fun favoredFormModifier(id: String, form: Form): Int {
        val favored = favoredForm ?: return 0
        if (form == favored.first) return if (id in state.favoredForm.attributes.take(if (favored.second >= 4) 2 else if (favored.second >= 2) 1 else 0)) 1 else 0
        return -state.favoredForm.drawbacks.take(favored.second.coerceAtLeast(0)).count { it.form == form && it.attribute == id }
    }
    fun formModifier(id: String, form: Form) = (form.attributeModifiers[id] ?: 0) + favoredFormModifier(id, form)
    fun attribute(id: String, form: Form = state.form) = (countedBaseAttribute(id) + powerTotal("attribute", form, id) + formModifier(id, form)).coerceAtLeast(0)
    fun totalAttribute(id: String) = (state.attributeRating(id) + attributeBonus(id) + powerTotal("attribute", state.form, id) + formModifier(id, state.form)).coerceAtLeast(0)
    fun skill(id: String, form: Form = state.form): Int {
        val bought = state.skillRating(id); val bonus = state.totem.dots(TotemKind.skill, id)
        return minOf(bought + bonus, maxOf(bought, baseRatingCap + if (bonus > 0) 1 else 0)) + powerTotal("skill", form, id)
    }
    fun skillBonus(id: String) = state.totem.dots(TotemKind.skill, id) + powerTotal("skill", state.form, id)
    val appliedPowers: List<AppliedPower> by lazy {
        buildList {
            fun addEffects(entry: ForsakenEntry, rating: Int, withForms: Boolean = true) {
                val forms = (entry.fields["effectForms"] as? JsonArray)?.map { it.jsonPrimitive.content }.takeIf { withForms }
                entry.fields.objects("effects").forEach { add(AppliedPower(entry.name, it, rating, forms)) }
            }
            fun moon(gift: ForsakenEntry?, dots: Int) { gift?.array("facets")?.forEach {
                val facet = ForsakenEntry(it.jsonObject)
                if ((facet.number("dots") ?: 0) <= dots && facet.flag("passive")) addEffects(facet, moonGiftDots)
            } }
            moon(moonGift, moonGiftDots)
            if (!isPure) state.extraMoonGifts.forEach { moon(catalog.entry(CatalogKind.gifts, it.source.catalog), moonDots(it)) }
            state.facets.forEach { owned -> catalog.facet(owned.source.catalog)?.facet?.let { facet ->
                if (facet.flag("passive") || owned.active) addEffects(facet,
                    Renown.entries.firstOrNull { it.name == facet.text("renown") }?.let(::renown) ?: moonGiftDots)
            } }
            state.rites.filter { it.active }.forEach { owned -> catalog.entry(CatalogKind.rites, owned.source.catalog)?.let { addEffects(it, it.number("rating") ?: 1, false) } }
            lodge?.let { addEffects(it, state.primalUrge, false) }
        }
    }
    fun powerTotal(type: String, form: Form = state.form, target: String? = null) = appliedPowers.sumOf {
        if ((it.forms == null || form.name in it.forms) && it.effect.text("type") == type && (target == null || it.effect.text(type) == target))
            it.effect["amount"].amount(it.rating) else 0
    }
    private fun meritTotal(type: String): Int {
        val owned = state.merits.mapNotNull { merit -> catalog.entry(CatalogKind.merits, merit.source.catalog)?.let { it to merit.rating + meritBonus(it.id) } }
        val ownedIds = owned.map { it.first.id }.toSet()
        val unlisted = state.totem.advantages.filter { it.kind == TotemKind.merit }.map { it.target }.toSet().minus(ownedIds)
            .mapNotNull { id -> catalog.entry(CatalogKind.merits, id)?.let { it to meritBonus(id) } }
        return (owned + unlisted).filter { it.second > 0 }.sumOf { (entry, rating) -> entry.fields.objects("effects").filter { it.text("type") == type }.sumOf { it["amount"].amount(rating) } }
    }
    fun size(form: Form = state.form) = state.size + form.sizeModifier + meritTotal("size") + powerTotal("size", form)
    fun health(form: Form = state.form) = attribute("stamina", form) + size(form) + powerTotal("health", form)
    val willpower get() = state.attributeRating("resolve") + state.attributeRating("composure") + powerTotal("willpower")
    val essenceMaximum get() = primalUrge.essenceMaximum + powerTotal("essenceMaximum")
    fun speed(form: Form = state.form) = attribute("strength", form) + attribute("dexterity", form) + 5 + form.speedBonus + meritTotal("speed") + powerTotal("speed", form)
    fun defense(form: Form = state.form, using: String = "athletics"): Int {
        val dex = attribute("dexterity", form); val wits = attribute("wits", form)
        val instinctive = form in listOf(Form.urshul, Form.urhan) && meritDots("instinctive-defense") > 0
        return (if (instinctive) maxOf(dex, wits) else minOf(dex, wits)) + skill(using, form) + meritTotal("defense") + powerTotal("defense", form)
    }
    fun initiative(form: Form = state.form) = attribute("dexterity", form) + attribute("composure", form) + meritTotal("initiative") + powerTotal("initiative", form)
    val alternativeDefenseSkills get() = state.merits.filter { it.rating > 0 }.mapNotNull { merit ->
        if (catalog.entry(CatalogKind.merits, merit.source.catalog)?.fields?.objects("effects")?.any { it.text("type") == "defenseSkillFromQualifier" } == true)
            modernSkillDefinitions.firstOrNull { it.name.equals(merit.qualifier, true) }?.id else null
    }
    fun armor(form: Form = state.form): Pair<Int, Int> {
        var general = state.armor + powerTotal("armor", form); var ballistic = state.ballisticArmor
        state.merits.filter { it.source.catalog == "fortified-form" && it.qualifier.equals(form.title, true) }.forEach {
            val dots = it.rating + meritBonus("fortified-form")
            general += if (dots >= 5) 2 else if (dots >= 3) 1 else 0
            ballistic += if (dots >= 5) 2 else if (dots >= 4) 1 else 0
        }
        return general to ballistic
    }
    fun brawlPool(form: Form = state.form) = attribute("strength", form) + skill("brawl", form).let { if (it > 0) it else -1 }
    fun weaponryPool(form: Form = state.form) = (attribute("strength", form) + skill("weaponry", form)).takeIf { form in listOf(Form.hishu, Form.dalu) }
    fun firearmsPool(form: Form = state.form) = (attribute("dexterity", form) + skill("firearms", form)).takeIf { form in listOf(Form.hishu, Form.dalu) }
    fun worked(pool: String, form: Form = state.form): WorkedDicePool? {
        var traits = pool; var against = ""
        for ((separator, mark) in listOf(" versus " to "vs ", " vs " to "vs ", " - " to "− ", " − " to "− ")) {
            if (separator in pool) { traits = pool.substringBefore(separator); against = mark + pool.substringAfter(separator); break }
        }
        var dice = 0
        for (term in traits.split(" + ")) {
            val name = term.trim()
            val attr = attributeDefinitions.firstOrNull { it.name.equals(name, true) }
            val sk = modernSkillDefinitions.firstOrNull { it.name.equals(name, true) }
            val renown = Renown.entries.firstOrNull { it.title.equals(name, true) }
            dice += when { attr != null -> attribute(attr.id, form); sk != null -> skill(sk.id, form).let { if (it > 0) it else sk.category.unskilledPenalty }
                renown != null -> renown(renown); name.equals("Primal Urge", true) -> state.primalUrge; else -> return null }
        }
        return WorkedDicePool(dice, traits, against)
    }
    val experiencesSpent get() = state.changeLog.sumOf { it.experiences }
    val experiencesAvailable get() = state.experiences - experiencesSpent
    fun hasUnlocked(gift: ForsakenEntry) = gift.text("kind") == "wolf" || state.facets.any { gift(it)?.id == gift.id }
    fun canLearnFree(found: CatalogFacet) = state.creation == null && (state.renownFacetCredits[found.facet.text("renown")] ?: 0) > 0 && hasUnlocked(found.gift)
    fun facetCost(gift: ForsakenEntry, unlocked: Boolean) = when { gift.text("kind") == "wolf" -> 1; unlocked -> 2; gift.text("kind") == "shadow" && hasAffinity(gift) -> 3; else -> 5 }
    fun price(found: CatalogFacet): FacetPrice {
        val renown = Renown.entries.firstOrNull { it.name == found.facet.text("renown") }
        if (canLearnFree(found) && renown != null) return FacetPrice(0, renown)
        val unlocked = hasUnlocked(found.gift)
        return FacetPrice(facetCost(found.gift, unlocked), unlocksGift = !unlocked)
    }
    val renownsWithFreeFacets get() = if (state.xpMode && state.creation == null) Renown.entries.filter { (state.renownFacetCredits[it.name] ?: 0) > 0 } else emptyList()
    fun freeFacetChoices(renown: Renown): List<CatalogFacet> {
        val known = state.facets.mapNotNull { it.source.catalog }.toSet()
        return catalog.all(CatalogKind.gifts).filter { it.text("kind") != "moon" && hasUnlocked(it) }.flatMap { gift ->
            gift.array("facets").map { CatalogFacet(gift, ForsakenEntry(it.jsonObject)) }.filter { it.facet.text("renown") == renown.name && it.facet.id !in known }
        }
    }
}
