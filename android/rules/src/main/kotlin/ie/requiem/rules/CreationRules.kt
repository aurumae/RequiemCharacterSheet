package ie.requiem.rules

import java.util.Locale

object CreationRules {
    val attributeDots = listOf(5, 4, 3)
    val skillDots = listOf(11, 7, 4)
    val ranks = listOf("Starting character" to 0, "Around the block" to 5, "Rising star" to 10,
        "Ancilla" to 15, "Rank elder" to 25, "Mover and shaker" to 35, "Urban Legend" to 50, "Methuselah" to 100)
}
enum class CreationPriority(val title: String) { Primary("Primary"), Secondary("Secondary"), Tertiary("Tertiary") }
internal val TraitCategory.saveKey: String get() = name.lowercase(Locale.ROOT)
data class CreationBudget(val used: Int, val allowed: Int, val priority: CreationPriority? = null) {
    val remaining: Int get() = allowed - used
}
enum class CreationProblemKind(val step: Int, val priority: Int = 2) {
    Attributes(2, 0), Skills(3, 0), Specialties(4, 0), DisciplineDots(5, 0), InClanDots(5), SorceryStatus(5, 1),
    CoilStatus(5, 1), OtherCoil(5, 1), RitualCount(5), RitualDots(5), DevotionsOrScales(5),
    MeritDots(6, 0), UnavailableMerit(6, 1), MeritPrerequisites(6, 1), BloodPotency(6), Humanity(5)
}
data class CreationProblem(val kind: CreationProblemKind, val subject: String = "", val extra: String = "") {
    val description: String get() = when (kind) {
        CreationProblemKind.Attributes -> "More $subject Attribute dots than its priority allows"
        CreationProblemKind.Skills -> "More $subject Skill dots than its priority allows"
        CreationProblemKind.Specialties -> "More than 3 Specialties"
        CreationProblemKind.DisciplineDots -> "More than 3 Discipline dots"
        CreationProblemKind.InClanDots -> "At least 2 Discipline dots must be in-clan"
        CreationProblemKind.SorceryStatus -> "$subject needs $extra Status"
        CreationProblemKind.CoilStatus -> "Coils need Ordo Dracul Status"
        CreationProblemKind.OtherCoil -> "Only your Mystery's Coil can be learned at creation"
        CreationProblemKind.RitualCount -> "More $subject rituals than $subject dots"
        CreationProblemKind.RitualDots -> "$subject is rated above its Discipline"
        CreationProblemKind.DevotionsOrScales -> "Devotions and Scales are learned with Experiences after creation"
        CreationProblemKind.MeritDots -> "More than 10 Merit dots, counting 5 per extra dot of Blood Potency"
        CreationProblemKind.UnavailableMerit -> "$subject isn't available to Kindred"
        CreationProblemKind.MeritPrerequisites -> "$subject's prerequisites aren't met"
        CreationProblemKind.BloodPotency -> "Blood Potency can start at most at 3"
        CreationProblemKind.Humanity -> "Humanity starts at 7"
    }
}
data class CreationReport(
    val attributes: Map<TraitCategory, CreationBudget>, val skills: Map<TraitCategory, CreationBudget>,
    val specialties: CreationBudget, val disciplines: CreationBudget, val merits: CreationBudget,
    val problems: Set<CreationProblem>,
) {
    val withinLimits: Boolean get() = problems.isEmpty()
    val overspend: Int get() = (attributes.values + skills.values + listOf(specialties, disciplines, merits)).sumOf { (-it.remaining).coerceAtLeast(0) }
    fun allows(other: CreationReport): Boolean = problems.containsAll(other.problems) && other.overspend <= overspend
    fun rejection(other: CreationReport): String? = if (allows(other)) null else
        (other.problems - problems).ifEmpty { other.problems }.sortedWith(compareBy<CreationProblem> { it.kind.priority }.thenBy { it.description })
            .firstOrNull()?.description ?: "No starting dots left"
}

internal sealed interface PendingCreationTrait {
    data class Discipline(val entry: BookEntry?) : PendingCreationTrait
    data class Merit(val entry: BookEntry?, val rating: Int) : PendingCreationTrait
    data class Ritual(val discipline: TraitSource, val dots: Int) : PendingCreationTrait
}

fun CharacterSave.creationReport(catalog: Catalog): CreationReport = creationReport(catalog, traitLevels(catalog))
internal fun CharacterSave.creationReport(catalog: Catalog, levels: Map<String, Int>, pending: PendingCreationTrait? = null): CreationReport {
    fun level(key: String) = levels[key] ?: 0
    val problems = mutableSetOf<CreationProblem>()
    fun problem(kind: CreationProblemKind, subject: String = "", extra: String = "") { problems += CreationProblem(kind, subject, extra) }
    fun budgets(skills: Boolean): Map<TraitCategory, CreationBudget> {
        val definitions = if (skills) skillDefinitions else attributeDefinitions
        val priorities = if (skills) creation?.skillPriorities else creation?.attributePriorities
        val allotments = if (skills) CreationRules.skillDots else CreationRules.attributeDots
        return TraitCategory.entries.associateWith { category ->
            val used = definitions.filter { it.category == category }.sumOf {
                val free = if (skills) 0 else if (creation?.favoredAttribute == it.id) 2 else 1
                (level("${if (skills) "skill" else "attribute"}:${it.id}") - free).coerceAtLeast(0)
            }
            val priority = priorities?.get(category.saveKey)?.let { CreationPriority.entries.getOrNull(it) }
            CreationBudget(used, priority?.let { allotments[it.ordinal] } ?: 0, priority).also {
                if (it.remaining < 0) problem(if (skills) CreationProblemKind.Skills else CreationProblemKind.Attributes, category.title)
            }
        }
    }
    val attributes = budgets(false); val skills = budgets(true)
    val specialties = this.skills.filter { it.skill in coreSkillIds }.sumOf { level("specialty:${it.skill}") }
    if (specialties > 3) problem(CreationProblemKind.Specialties)
    val disciplineEntries = disciplines.map { catalog.entry(CatalogKind.disciplines, it.source) to level("discipline:${it.id.swiftKey()}") }.toMutableList()
    if (pending is PendingCreationTrait.Discipline) disciplineEntries += pending.entry to 1
    var disciplineDots = 0; var outOfClan = 0
    for ((entry, dots) in disciplineEntries) if (dots > 0) {
        disciplineDots += dots
        if (entry != null && !entry.isRitualDiscipline && entry.id in inClanDisciplines(catalog)) continue
        outOfClan += dots
        entry?.raw?.obj("ritualRules")?.let { rules ->
            val covenant = rules.str("covenant").orEmpty()
            if (covenantStatus(covenant, catalog) < rules.int("covenantStatusMinimum", 1))
                problem(CreationProblemKind.SorceryStatus, entry.name, catalog.name(CatalogKind.covenants, TraitSource(catalog = covenant)))
        }
    }
    for (coil in coils) {
        val dots = level("coil:${coil.id.swiftKey()}")
        if (dots <= 0) continue
        disciplineDots += dots; outOfClan += dots
        if (!isMysteryCoil(coil)) problem(CreationProblemKind.OtherCoil)
        if (covenantStatus("ordo-dracul", catalog) < 1) problem(CreationProblemKind.CoilStatus)
    }
    if (disciplineDots > 3) problem(CreationProblemKind.DisciplineDots)
    if (catalog.entry(CatalogKind.clans, clan) != null && outOfClan > 1) problem(CreationProblemKind.InClanDots)
    val rites = rituals.filter { level("ritual:${it.id.swiftKey()}") > 0 }.map {
        Triple(it.discipline(catalog), it.dots(catalog), catalog.name(CatalogKind.rituals, it.source))
    }.toMutableList()
    if (pending is PendingCreationTrait.Ritual) rites += Triple(pending.discipline, pending.dots, "The ritual")
    for ((discipline, group) in rites.groupBy { it.first }) {
        val dots = disciplines.filter { it.source == discipline }.maxOfOrNull { level("discipline:${it.id.swiftKey()}") } ?: 0
        if (group.size > dots) problem(CreationProblemKind.RitualCount, catalog.name(CatalogKind.disciplines, discipline))
        group.filter { it.second > dots }.forEach { problem(CreationProblemKind.RitualDots, it.third) }
    }
    if (devotions.any { level("devotion:${it.id.swiftKey()}") > 0 } || scales.any { level("scale:${it.id.swiftKey()}") > 0 }) problem(CreationProblemKind.DevotionsOrScales)
    val meritList = merits.map { Triple(catalog.entry(CatalogKind.merits, it.source), it.displayName(catalog), level("merit:${it.id.swiftKey()}")) }.toMutableList()
    if (pending is PendingCreationTrait.Merit) meritList += Triple(pending.entry, pending.entry?.name.orEmpty(), pending.rating)
    val bp = level("bloodPotency:bloodPotency")
    val meritDots = meritList.sumOf { it.third } + (bp - 1).coerceAtLeast(0) * 5
    if (meritDots > 10) problem(CreationProblemKind.MeritDots)
    for ((entry, name, _) in meritList) if (entry != null) {
        if (entry.raw.flag("unavailableToKindred")) problem(CreationProblemKind.UnavailableMerit, name)
        else if (prerequisites(entry, catalog).any { it.met == false }) problem(CreationProblemKind.MeritPrerequisites, name)
    }
    if (bp > 3) problem(CreationProblemKind.BloodPotency)
    if (level("humanity:humanity") > 7) problem(CreationProblemKind.Humanity)
    return CreationReport(attributes, skills, CreationBudget(specialties, 3), CreationBudget(disciplineDots, 3), CreationBudget(meritDots, 10), problems)
}

/** Preserve an imported overspend while letting the player reduce it or spend an unaffected budget. */
fun CharacterSave.creationMaximum(key: String, cap: Int, catalog: Catalog): Int {
    if (creation == null) return cap
    val levels = traitLevels(catalog); val current = levels[key] ?: 0
    val existing = creationReport(catalog, levels)
    return (cap downTo current + 1).firstOrNull { existing.allows(creationReport(catalog, levels + (key to it))) } ?: current
}
fun CharacterSave.attributeChoices(id: String, catalog: Catalog): List<Int> {
    val minimum = if (creation?.favoredAttribute == id) 2 else 1
    return (minimum..maxOf(minimum, creationMaximum("attribute:$id", staminaCap, catalog))).toList()
}
fun CharacterSave.skillChoices(id: String, catalog: Catalog): List<Int> = (0..creationMaximum("skill:$id", staminaCap, catalog)).toList()
val CharacterSave.canAddSpecialty: Boolean get() = creation == null || skills.filter { it.skill in coreSkillIds }.sumOf { it.specialties.count(String::isNotBlank) } < 3
fun CharacterSave.favoredAttributes(catalog: Catalog): List<String> = catalog.entry(CatalogKind.clans, clan)?.raw?.strings("favoredAttributes").orEmpty()
fun CharacterSave.needsFavoredAttribute(catalog: Catalog): Boolean = creation != null && creation.favoredAttribute == null && catalog.entry(CatalogKind.clans, clan) != null
fun CharacterSave.firstTouchstoneLevel(catalog: Catalog): Int = catalog.entry(CatalogKind.clans, clan)?.raw?.obj("bane")?.int("firstTouchstoneHumanity", 6) ?: 6

internal fun CharacterSave.setPriority(action: SheetEdit.Priority): CharacterSave {
    val state = creation ?: return this
    val priorities = (if (action.skills) state.skillPriorities else state.attributePriorities).toMutableMap()
    val key = action.category.saveKey; val old = priorities[key]
    priorities.entries.firstOrNull { it.value == action.priority.ordinal && it.key != key }?.key?.let {
        if (old == null) priorities.remove(it) else priorities[it] = old
    }
    priorities[key] = action.priority.ordinal
    return copy(creation = if (action.skills) state.copy(skillPriorities = priorities) else state.copy(attributePriorities = priorities))
}
internal fun CharacterSave.chooseFavoredAttribute(id: String?, catalog: Catalog): CharacterSave {
    val state = creation ?: return this
    if (id == state.favoredAttribute || (id != null && id !in favoredAttributes(catalog))) return this
    return copy(creation = state.copy(favoredAttribute = id), attributes = attributes.map {
        when (it.attribute) {
            state.favoredAttribute -> it.copy(rating = (it.rating - 1).coerceAtLeast(1))
            id -> it.copy(rating = (it.rating + 1).coerceAtMost(5))
            else -> it
        }
    })
}

/** Used by pickers and by the edit dispatcher; previews never create log records or paid dots. */
fun CharacterSave.creationEntryRejection(action: SheetEdit.AddEntry, catalog: Catalog): String? {
    if (creation == null) return null
    if (action.kind in listOf(EntryKind.Devotion, EntryKind.Scale)) return CreationProblem(CreationProblemKind.DevotionsOrScales).description
    if (action.kind == EntryKind.Coil) return "Choose your Mystery to add its Coil during creation"
    val entry = catalog.entry(action.kind.catalogKind, action.source)
    val pending = when (action.kind) {
        EntryKind.Discipline -> PendingCreationTrait.Discipline(entry)
        EntryKind.Merit -> PendingCreationTrait.Merit(entry, entry?.ratings?.minOrNull() ?: 1)
        EntryKind.Ritual -> PendingCreationTrait.Ritual(entry?.discipline?.let { TraitSource(catalog = it) } ?: action.ritualDiscipline, entry?.dots ?: action.ritualDots)
        else -> return null
    }
    val levels = traitLevels(catalog)
    return creationReport(catalog, levels).rejection(creationReport(catalog, levels, pending))
}

enum class CreationStepStatus(val title: String) { Done("Done"), InProgress("Not done"), Problem("Breaks a rule") }
data class CreationStep(val number: Int, val title: String, val detail: String, val status: CreationStepStatus)
fun CharacterSave.creationSteps(catalog: Catalog): List<CreationStep> {
    val report = creationReport(catalog)
    fun status(step: Int, done: Boolean) = if (report.problems.any { it.kind.step == step }) CreationStepStatus.Problem else if (done) CreationStepStatus.Done else CreationStepStatus.InProgress
    fun spent(budgets: Map<TraitCategory, CreationBudget>) = budgets.values.all { it.priority != null && it.remaining == 0 }
    fun describe(budgets: Map<TraitCategory, CreationBudget>): String {
        if (budgets.values.none { it.priority != null }) return "Choose a priority for each category"
        return budgets.entries.sortedWith(compareBy<Map.Entry<TraitCategory, CreationBudget>> { it.value.priority?.ordinal ?: 3 }.thenBy { it.key.ordinal }).joinToString(" · ") { (category, b) ->
            if (b.priority == null) "${category.title}: choose a priority" else "${category.title} (${b.priority.title.lowercase(Locale.ROOT)}) ${b.used} of ${b.allowed}"
        }
    }
    val aspirations = aspirations.count { it.text.trim().isNotEmpty() }
    val missing = buildList {
        if (clan == TraitSource(custom = "")) add("clan")
        if (needsFavoredAttribute(catalog)) add("the clan's favoured Attribute")
        if (mask.isEmpty()) add("Mask")
        if (dirge.isEmpty()) add("Dirge")
        val touchstone = firstTouchstoneLevel(catalog)
        if (touchstones.firstOrNull { it.level == touchstone }?.text.isNullOrBlank()) add("Touchstone on Humanity $touchstone")
    }
    return listOf(
        CreationStep(1, "Concept", "A concept and three Aspirations ($aspirations of 3)", status(1, concept.isNotBlank() && aspirations >= 3)),
        CreationStep(2, "Attributes", describe(report.attributes), status(2, spent(report.attributes))),
        CreationStep(3, "Skills", describe(report.skills), status(3, spent(report.skills))),
        CreationStep(4, "Skill Specialties", "${report.specialties.used} of 3", status(4, report.specialties.remaining == 0)),
        CreationStep(5, "Kindred Traits", (if (missing.isEmpty()) "" else "Needs ${missing.joinToString(", ")} · ") + "Disciplines ${report.disciplines.used} of 3", status(5, missing.isEmpty() && report.disciplines.remaining == 0)),
        CreationStep(6, "Merits", "${report.merits.used} of 10, counting Blood Potency $bloodPotency", status(6, report.merits.remaining == 0)),
        CreationStep(7, "Advantages", "Worked out for you from the traits above", CreationStepStatus.Done),
    )
}

fun CharacterSave.creationAllowsEdit(action: SheetEdit, catalog: Catalog): Boolean {
    if (creation == null) return true
    fun rating(key: String, requested: Int, cap: Int = 5) = requested <= creationMaximum(key, cap, catalog)
    return when (action) {
        is SheetEdit.XpMode -> !action.enabled
        is SheetEdit.AttributeRating -> action.rating >= (if (creation.favoredAttribute == action.id) 2 else 1) && rating("attribute:${action.id}", action.rating, staminaCap)
        is SheetEdit.SkillRating -> rating("skill:${action.id}", action.rating, staminaCap)
        is SheetEdit.Stamina -> creationAllowsEdit(SheetEdit.AttributeRating("stamina", stamina + action.delta), catalog)
        is SheetEdit.StaminaRating -> creationAllowsEdit(SheetEdit.AttributeRating("stamina", action.rating), catalog)
        is SheetEdit.AddSpecialty -> canAddSpecialty || action.text.isBlank()
        is SheetEdit.ReplaceSpecialty -> action.previous.isNotBlank() || action.text.isBlank() || canAddSpecialty
        is SheetEdit.AddEntry -> creationEntryRejection(action, catalog) == null
        is SheetEdit.EntryRating -> when (action.kind) {
            EntryKind.Discipline -> rating("discipline:${action.id.swiftKey()}", action.value)
            EntryKind.Merit -> {
                val entry = merits.firstOrNull { it.id == action.id }?.let { catalog.entry(CatalogKind.merits, it.source) }
                rating("merit:${action.id.swiftKey()}", entry?.allowedRating(action.value) ?: action.value)
            }
            EntryKind.Coil -> rating("coil:${action.id.swiftKey()}", action.value)
            EntryKind.Ritual -> rituals.firstOrNull { it.id == action.id }?.let { ritual ->
                action.value <= maxOf(ritual.dots(catalog), disciplines.filter { it.source == ritual.discipline(catalog) }.maxOfOrNull { it.rating } ?: 0)
            } ?: false
            else -> true
        }
        is SheetEdit.CustomRitual -> {
            val ritual = rituals.firstOrNull { it.id == action.id }
            if (ritual?.discipline(catalog) == action.discipline && action.dots <= ritual.dots(catalog)) true
            else {
                val next = applyEdit(action, catalog)
                val rank = disciplines.filter { it.source == action.discipline }.maxOfOrNull { it.rating } ?: 0
                action.dots <= rank && creationReport(catalog).allows(next.creationReport(catalog))
            }
        }
        is SheetEdit.CustomDevotionCost -> action.value <= (devotions.firstOrNull { it.id == action.id }?.customExperienceCost ?: 0)
        is SheetEdit.Number -> when (action.field) {
            NumberField.BloodPotency -> rating("bloodPotency:bloodPotency", action.value, 10)
            NumberField.Humanity -> rating("humanity:humanity", action.value, 10)
            else -> true
        }
        is SheetEdit.Counter -> if (action.delta <= 0) true else creationAllowsEdit(SheetEdit.Number(action.field,
            (number(action.field).toLong() + action.delta).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()), catalog)
        else -> true
    }
}
