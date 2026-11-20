package ie.forsaken.rules

import ie.chronicles.core.*
import java.util.Locale

internal fun SaveId.saveKey() = toString().uppercase(Locale.ROOT)
val forsakenTraitKindOrder = listOf("attribute", "skill", "specialty", "merit", "renown", "moonGift", "facet", "rite", "primalUrge", "condition")

fun ForsakenRules.traitSnapshot(): Map<String, TraitLevel> = buildMap {
    putAll(state.sharedTraitSnapshot(::traitTitle, ::meritName))
    Renown.entries.forEach { put("renown:${it.name}", TraitLevel(renown(it), it.title)) }
    state.extraMoonGifts.forEach { put("moonGift:${it.id.saveKey()}", TraitLevel(it.dots, catalog.name(CatalogKind.gifts, it.source))) }
    state.facets.forEach { put("facet:${it.id.saveKey()}", TraitLevel(1, facetName(it))) }
    state.rites.forEach { put("rite:${it.id.saveKey()}", TraitLevel(riteRating(it), catalog.name(CatalogKind.rites, it.source))) }
    put("primalUrge:primalUrge", TraitLevel(state.primalUrge, "Primal Urge"))
}

fun ForsakenRules.meritName(merit: Merit) = catalog.name(CatalogKind.merits, merit.source) +
    merit.qualifier?.let { " ($it)" }.orEmpty()

fun ForsakenRules.conditionLogName(condition: CharacterCondition): String {
    val name = catalog.name(CatalogKind.conditions, condition.source)
    val counted = name.isNotEmpty() && condition.counter > 0 &&
        catalog.entry(CatalogKind.conditions, condition.source.catalog)?.flag("counter") == true
    return name + (if (counted) " −${condition.counter}" else "") + condition.note.takeIf(String::isNotEmpty)?.let { " ($it)" }.orEmpty()
}

/** Display current/final names without rewriting saved historical names or legacy keys. */
fun ForsakenRules.changeName(change: TraitChange, names: Map<String, TraitLevel> = traitSnapshot()): String {
    val kind = change.trait.substringBefore(':')
    val current = if (kind == "condition") {
        val key = change.trait.substringAfter(':').substringAfter('/', "")
        val id = runCatching { java.util.UUID.fromString(key) }.getOrNull()?.takeIf { it.toString().equals(key, true) }
        state.conditions.firstOrNull { it.id == id }?.let(::conditionLogName)
            ?: state.changeLog.lastOrNull { it.trait == change.trait }?.name
    } else names[change.trait]?.name
    val name = current?.takeIf(String::isNotEmpty) ?: change.name
    val label = when (kind) {
        "moonGift" -> "Moon Gift"; "primalUrge" -> "Primal Urge"
        in forsakenTraitKindOrder -> kind.replaceFirstChar(Char::uppercaseChar)
        else -> kind
    }
    return name.ifEmpty { "Unnamed $label" }
}

fun ForsakenRules.experienceCost(key: String, level: Int): Int {
    val id = key.substringAfter(':')
    return when (key.substringBefore(':')) {
        "attribute" -> 4
        "skill" -> 2
        "specialty" -> 1
        "merit" -> lodgeMultiplier(lodgesTeaching("merits", state.merits.firstOrNull { it.id.saveKey() == id }?.source?.catalog))
        "renown" -> 3
        "rite" -> lodgeMultiplier(lodgesTeaching("rites", state.rites.firstOrNull { it.id.saveKey() == id }?.source?.catalog))
        "primalUrge" -> 5
        "moonGift" -> if (level == 1) 5 else 2
        "facet" -> {
            val owned = state.facets.firstOrNull { it.id.saveKey() == id }
            val gift = owned?.let(::gift)
            when { owned?.withRenown == true -> 0; gift == null -> customFacetCost(owned?.customKind ?: GiftKind.shadow)
                else -> facetCost(gift, state.facets.any { it.id != owned.id && gift(it)?.id == gift.id }) }
        }
        else -> 0
    }
}

fun ForsakenRules.attributeNote(id: String): String? {
    val notes = buildList {
        fun signed(value: Int) = if (value > 0) "+$value" else "−${-value}"
        state.form.attributeModifiers[id]?.takeIf { it != 0 }?.let { add("${signed(it)} in ${state.form.title}") }
        favoredFormModifier(id, state.form).takeIf { it != 0 }?.let { add("${signed(it)} from Favored Form") }
        val totem = state.totem.dots(TotemKind.attribute, id)
        if (totem > 0) add("+$totem from the totem")
        if (attributeBonus(id) > totem) add("+1 from Embodiment of the Firstborn")
        appliedPowers.filter { (it.forms == null || state.form.name in it.forms) && it.effect.text("type") == "attribute" && it.effect.text("attribute") == id }
            .forEach { add("+${it.effect["amount"].amount(it.rating)} from ${it.name}") }
    }
    return notes.takeIf { it.isNotEmpty() }?.joinToString(" · ")
}
