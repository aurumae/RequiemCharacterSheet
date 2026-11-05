package ie.requiem.rules

import kotlinx.serialization.json.*

data class DetailFact(val label: String, val value: String)
data class DetailBlock(val title: String, val summary: String = "", val dots: String = "", val learned: Boolean = true, val facts: List<DetailFact> = emptyList())
data class BookDetail(val title: String, val summary: String, val citation: String, val facts: List<DetailFact>, val warnings: List<String>, val blocks: List<DetailBlock>)

internal fun JsonObject.costText(includeNote: Boolean = true): String {
    fun amount(key: String, unit: String): String? = when (val a = get(key)) {
        is JsonPrimitive -> if (a.content == "varies") "Varies" else null
        is JsonObject -> a.str("fixed")?.let { "$it $unit" } ?: a.ints("range").takeIf { it.isNotEmpty() }?.let { "${it.first()}–${it.last()} $unit" }
        else -> null
    }
    val parts = listOfNotNull(amount("vitae", "Vitae"), amount("willpower", "Willpower"))
    val base = if ("Varies" in parts) "Varies" else if (parts.isEmpty()) "Free" else (if (flag("optional")) "Optional: " else "") + parts.joinToString(" and ")
    return base + if (includeNote) str("note")?.let { " ($it)" }.orEmpty() else ""
}
internal fun JsonObject.poolFormula(catalog: Catalog, disciplineName: String = ""): String? {
    str("text")?.let { return it }
    val attr = str("attribute") ?: return null
    val terms = buildList {
        add(traitName(attr)); str("skill")?.let { add(traitName(it)) }
        if (flag("includesDiscipline")) add(disciplineName)
        str("discipline")?.let { add(catalog.name(CatalogKind.disciplines, TraitSource(catalog = it))) }
    }
    val resistance = str("resistance")
    return terms.joinToString(" + ") + if (resistance != null && (resistance.startsWith('-') || resistance.startsWith('−'))) " $resistance" else ""
}
private fun JsonObject.humanityRule(): String = when (str("humanity")) {
    "capAtTenMinusDots" -> "Humanity can't rise above 10 minus its dots. Learning a dot is a breaking point at Humanity 4 or higher."
    "atLeastRitualDots" -> "Casting a miracle requires Humanity at least equal to its dots."
    else -> ""
}

fun CharacterSave.bookDetail(entry: BookEntry, catalog: Catalog, rating: Int = 0, qualifier: String? = null): BookDetail {
    val e = entry.raw
    val facts = mutableListOf<DetailFact>(); val warnings = mutableListOf<String>(); val blocks = mutableListOf<DetailBlock>()
    fun fact(label: String, value: String?) { if (!value.isNullOrBlank()) facts += DetailFact(label, value) }
    fun poolFacts(pool: JsonObject?, known: Boolean, disciplineDots: Int = 0, disciplineName: String = ""): List<DetailFact> = buildList {
        if (pool == null) return@buildList
        pool.poolFormula(catalog, disciplineName)?.let { add(DetailFact("Dice pool", it)) }
        pool.str("resistance")?.takeUnless { it.startsWith('-') || it.startsWith('−') }?.let { add(DetailFact("Resisted by", it)) }
        if (known) dice(pool, catalog, disciplineDots)?.let { add(DetailFact("Your dice", if (it > 0) "$it" else "Chance die")) }
    }
    fun costFacts(data: JsonObject, known: Boolean, disciplineDots: Int = 0, disciplineName: String = ""): List<DetailFact> = buildList {
        add(DetailFact("Cost", data.obj("cost")?.costText() ?: "Free"))
        data.str("action")?.takeIf { it != "none" }?.let { add(DetailFact("Action", it.replaceFirstChar { c -> c.uppercaseChar() })) }
        data.str("duration")?.let { add(DetailFact("Duration", it)) }
        data.str("targetCondition")?.let { add(DetailFact("Target must be", it)) }
        data.str("requirement")?.let { add(DetailFact("Requirement", it)) }
        addAll(poolFacts(data.obj("dicePool"), known, disciplineDots, disciplineName))
        data.str("page")?.let { add(DetailFact("Page", it)) }
    }
    when (entry.kind) {
        CatalogKind.disciplines -> {
            if (entry.id in inClanDisciplines(catalog)) fact("Clan", "In-clan for ${catalog.name(CatalogKind.clans, clan)}")
            e.obj("ritualRules")?.let { rules ->
                fact("Learned with", "${catalog.name(CatalogKind.covenants, TraitSource(catalog = rules.str("covenant").orEmpty()))} Status ${rules.int("covenantStatusMinimum", 1)}")
                val cost = rules.obj("castingCost")
                fact("Casting cost", if (cost?.costText(false) == "Varies") cost.str("note") ?: "Varies" else cost?.costText())
                facts += poolFacts(rules.obj("castingPool"), rating > 0, rating, entry.name)
                fact("Humanity", rules.humanityRule())
                fact("Rituals", "Each dot comes with one ritual; others cost 2 Experiences each. A ritual can't be rated above your dots.")
                ritualLearningWarning(entry, catalog)?.let { warnings += it }
                rituals.filter { it.discipline(catalog).catalog == entry.id }.sortedBy { it.dots(catalog) }.forEach {
                    blocks += DetailBlock(catalog.name(CatalogKind.rituals, it.source), dots = dotsText(it.dots(catalog)), learned = it.dots(catalog) <= rating)
                }
            }
            e.objects("powers").forEach { p ->
                val bounds = p.ints("dots"); val known = (bounds.firstOrNull() ?: 1) <= rating
                val dots = bounds.distinct().joinToString("–") { dotsText(it) }
                blocks += DetailBlock(p.str("name").orEmpty(), p.str("summary").orEmpty(), dots, known, costFacts(p, known, rating, entry.name))
            }
        }
        CatalogKind.merits -> {
            fact("Rating", entry.ratingsText()); entry.qualifierPrompt?.let { fact(it, qualifier ?: "Not chosen") }
            prerequisites(entry, catalog).forEach { fact("Prerequisite", "${it.description} · ${when(it.met) { true -> "Met"; false -> "Not met"; null -> "Check yourself" }}") }
            e.objects("effects").forEach { effect ->
                val type = effect.str("type"); val amount = effect.effectAmount(rating)
                val target = when (type) {
                    "attribute" -> traitName(effect.str("attribute").orEmpty())
                    "attributeRolls" -> traitName(effect.str("attribute").orEmpty()) + " rolls"
                    "size" -> "Size (and so Health)"
                    "defense", "speed", "initiative" -> type.replaceFirstChar { it.uppercaseChar() }
                    else -> null
                }
                if (target != null) fact("On your sheet", if (amount >= 0) "Adds $amount to $target" else "Subtracts ${-amount} from $target")
                if (type == "defenseSkillFromQualifier") fact("On your sheet", "Defense can use ${qualifier ?: "the chosen Skill"} instead of Athletics")
            }
            e.objects("styleManeuvers").forEach { p -> blocks += DetailBlock(p.str("name").orEmpty(), p.str("summary").orEmpty(), dotsText(p.int("dots")), p.int("dots") <= rating) }
        }
        CatalogKind.rituals -> {
            val discipline = catalog.entry(CatalogKind.disciplines, entry.discipline)
            val rank = disciplineRating(entry.discipline)
            fact("Rating", "${discipline?.name ?: entry.discipline} ${dotsText(entry.dots)}")
            fact("Target successes", e.str("targetSuccesses"))
            fact("Contested by", e.str("contestedBy")); fact("Resisted by", e.str("resistedBy")); fact("Sacrament", e.str("sacrament"))
            discipline?.raw?.obj("ritualRules")?.let { r ->
                val cost = r.obj("castingCost")
                fact("Casting cost", if (cost?.str("vitae") == "varies") "${entry.dots} Vitae" else cost?.costText())
                facts += poolFacts(r.obj("castingPool"), rank >= entry.dots, rank, discipline.name)
            }
            warnings += ritualWarnings(Ritual(entry.source()), catalog)
        }
        CatalogKind.devotions -> {
            prerequisites(entry, catalog).forEach { fact("Requires", it.description) }
            fact("Learning cost", experiencesText(entry.experienceCost))
            facts += costFacts(e, prerequisites(entry, catalog).none { it.met == false })
            prerequisites(entry, catalog).filter { it.met == false }.forEach { warnings += "Missing ${it.description}" }
        }
        CatalogKind.mysteries -> {
            fact("Mystery", entry.name); fact("Coil", e.obj("coil")?.str("summary"))
            e.objects("tiers").forEach { p -> blocks += DetailBlock(p.str("name").orEmpty(), p.str("summary").orEmpty(), dotsText(p.int("dots")), p.int("dots") <= rating,
                listOfNotNull(p.str("page")?.let { DetailFact("Page", it) })) }
        }
        CatalogKind.scales -> {
            fact("Prerequisite Coil", entry.scalePrerequisiteText(catalog))
            fact("Learning cost", experiencesText(scaleCost(entry)) + if (scaleCost(entry) == 1) " (prerequisite met)" else " (2 without the prerequisite, 1 with it)")
            facts += costFacts(e, false)
        }
        else -> Unit
    }
    return BookDetail(if (entry.kind == CatalogKind.mysteries) entry.coilName else entry.name + (qualifier?.let { " ($it)" } ?: ""), entry.summary, entry.citation, facts, warnings, blocks)
}
