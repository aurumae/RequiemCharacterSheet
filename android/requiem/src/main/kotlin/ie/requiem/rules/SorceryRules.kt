package ie.requiem.rules

fun CharacterSave.disciplineRating(id: String): Int = disciplines.filter { it.source.catalog == id }.maxOfOrNull { it.rating } ?: 0
fun CharacterSave.coilRating(id: String): Int = coils.filter { it.mystery.catalog == id }.maxOfOrNull { it.rating } ?: 0
fun CharacterSave.covenantStatus(id: String, catalog: Catalog): Int {
    fun status(covenantId: String): Int {
        val name = catalog.name(CatalogKind.covenants, TraitSource(catalog = covenantId))
        return merits.filter { it.source.catalog == "covenant-status" && it.qualifier.equals(name, ignoreCase = true) }.maxOfOrNull { it.rating } ?: 0
    }
    return maxOf(status(id), statusStandIn(id, catalog)?.let { status(it.id) } ?: 0)
}
fun CharacterSave.statusStandIn(id: String, catalog: Catalog): BookEntry? = catalog.entry(CatalogKind.covenants, covenant)
    ?.takeIf { it.id != id && it.raw.str("statusCountsAs") == id }
fun CharacterSave.belongsToCovenant(id: String, catalog: Catalog): Boolean = covenant.catalog == id || statusStandIn(id, catalog) != null
fun CharacterSave.inClanDisciplines(catalog: Catalog): List<String> = (catalog.entry(CatalogKind.bloodlines, bloodline) ?: catalog.entry(CatalogKind.clans, clan))?.raw?.strings("disciplines").orEmpty()
fun CharacterSave.ritualDisciplines(catalog: Catalog): List<BookEntry> = disciplines.mapNotNull { catalog.entry(CatalogKind.disciplines, it.source) }.filter { it.isRitualDiscipline }.distinctBy { it.id }
fun CharacterSave.showsRituals(catalog: Catalog): Boolean = rituals.isNotEmpty() || ritualDisciplines(catalog).isNotEmpty()
val CharacterSave.showsCoils: Boolean get() = covenant.catalog == "ordo-dracul" || mystery != TraitSource(custom = "") || coils.isNotEmpty() || scales.isNotEmpty()
fun CharacterSave.isMysteryCoil(coil: Coil, catalog: Catalog): Boolean = mystery != TraitSource(custom = "") &&
    (coil.mystery == mystery || (mystery.catalog != null && catalog.entry(CatalogKind.mysteries, coil.mystery)?.raw?.str("partOfMystery") == mystery.catalog))
fun CharacterSave.scaleCost(entry: BookEntry): Int = if (
    (entry.raw.str("anyCoil") != null && coils.any { it.rating >= entry.raw.int("anyCoil") }) ||
    entry.raw.objects("prerequisiteCoils").any { coilRating(it.str("mystery").orEmpty()) >= it.int("dots") }) 1 else 2
fun BookEntry.ritualCovenants(catalog: Catalog): List<String> = raw.obj("ritualRules")?.let { rules ->
    listOf(rules.str("covenant").orEmpty()) + catalog.bookEntries(CatalogKind.covenants).filter { id in it.raw.strings("teaches") }.map { it.id }
}.orEmpty()
fun BookEntry.ritualRequirementText(catalog: Catalog): String {
    val rules = raw.obj("ritualRules") ?: return ""
    val names = ritualCovenants(catalog).joinToString(" or ") { catalog.name(CatalogKind.covenants, TraitSource(catalog = it)) }
    val minimum = rules.int("covenantStatusMinimum", 1)
    return if (minimum == 0) "membership of $names" else "$names Status $minimum"
}
fun CharacterSave.hasRitualStatus(entry: BookEntry, catalog: Catalog): Boolean {
    val rules = entry.raw.obj("ritualRules") ?: return true
    val minimum = rules.int("covenantStatusMinimum", 1)
    return entry.ritualCovenants(catalog).any { if (minimum == 0) belongsToCovenant(it, catalog) else covenantStatus(it, catalog) >= minimum }
}
fun CharacterSave.ritualLearningWarning(entry: BookEntry, catalog: Catalog): String? {
    return if (hasRitualStatus(entry, catalog)) null else "Learning rituals requires ${entry.ritualRequirementText(catalog)}"
}
fun CharacterSave.ritualWarnings(ritual: Ritual, catalog: Catalog): List<String> {
    val discipline = catalog.entry(CatalogKind.disciplines, ritual.discipline(catalog)) ?: return emptyList()
    val dots = ritual.dots(catalog)
    return buildList {
        if (disciplineRating(discipline.id) < dots) add("Requires ${discipline.name} $dots")
        if (discipline.raw.obj("ritualRules")?.str("humanity") == "atLeastRitualDots" && humanity < dots) add("Casting requires Humanity $dots")
    }
}
data class HumanityCap(val limit: Int, val discipline: String, val dots: Int) {
    val description: String get() = "$discipline $dots limits Humanity to $limit"
}
fun CharacterSave.humanityCap(catalog: Catalog): HumanityCap? = disciplines.mapNotNull { d ->
    val entry = catalog.entry(CatalogKind.disciplines, d.source)
    if (d.rating > 0 && entry?.raw?.obj("ritualRules")?.str("humanity") == "capAtTenMinusDots") HumanityCap(10 - d.rating, entry.name, d.rating) else null
}.minByOrNull { it.limit }
fun CharacterSave.coilWarning(coil: Coil, catalog: Catalog): String? = if (!isMysteryCoil(coil, catalog) && coil.rating > covenantStatus("ordo-dracul", catalog))
    "Outside your Mystery, limited to Ordo Dracul Status (${covenantStatus("ordo-dracul", catalog)})" else null

data class ClanBaneInfo(val name: String, val summary: String, val threshold: Int, val extraBane: Boolean)
fun CharacterSave.clanBane(catalog: Catalog): ClanBaneInfo? = catalog.entry(CatalogKind.clans, clan)?.raw?.obj("bane")?.let {
    ClanBaneInfo(it.str("name").orEmpty(), it.str("summary").orEmpty(), it.int("humanityThreshold", 6), it.flag("grantsExtraBane"))
}

data class ElderBaneInfo(val name: String, val summary: String, val threshold: Int, val citation: String)
fun CharacterSave.elderBane(catalog: Catalog): ElderBaneInfo? = catalog.bookEntries(CatalogKind.elderBanes)
    .firstOrNull { it.raw.str("clan") == clan.catalog }?.let {
        ElderBaneInfo(it.name, it.summary, it.raw.int("humanityThreshold", 3), it.citation)
    }
