package ie.requiem.rules

fun CharacterSave.disciplineRating(id: String): Int = disciplines.filter { it.source.catalog == id }.maxOfOrNull { it.rating } ?: 0
fun CharacterSave.coilRating(id: String): Int = coils.filter { it.mystery.catalog == id }.maxOfOrNull { it.rating } ?: 0
fun CharacterSave.covenantStatus(id: String, catalog: Catalog): Int {
    val name = catalog.name(CatalogKind.covenants, TraitSource(catalog = id))
    return merits.filter { it.source.catalog == "covenant-status" && it.qualifier.equals(name, ignoreCase = true) }.maxOfOrNull { it.rating } ?: 0
}
fun CharacterSave.inClanDisciplines(catalog: Catalog): List<String> = (catalog.entry(CatalogKind.bloodlines, bloodline) ?: catalog.entry(CatalogKind.clans, clan))?.raw?.strings("disciplines").orEmpty()
fun CharacterSave.ritualDisciplines(catalog: Catalog): List<BookEntry> = disciplines.mapNotNull { catalog.entry(CatalogKind.disciplines, it.source) }.filter { it.isRitualDiscipline }.distinctBy { it.id }
fun CharacterSave.showsRituals(catalog: Catalog): Boolean = rituals.isNotEmpty() || ritualDisciplines(catalog).isNotEmpty()
val CharacterSave.showsCoils: Boolean get() = covenant.catalog == "ordo-dracul" || mystery != TraitSource(custom = "") || coils.isNotEmpty() || scales.isNotEmpty()
fun CharacterSave.isMysteryCoil(coil: Coil): Boolean = mystery != TraitSource(custom = "") && coil.mystery == mystery
fun CharacterSave.scaleCost(entry: BookEntry): Int = if (entry.raw.objects("prerequisiteCoils").any { coilRating(it.str("mystery").orEmpty()) >= it.int("dots") }) 1 else 2
fun CharacterSave.ritualLearningWarning(entry: BookEntry, catalog: Catalog): String? {
    val rules = entry.raw.obj("ritualRules") ?: return null
    val covenant = rules.str("covenant").orEmpty()
    val minimum = rules.int("covenantStatusMinimum", 1)
    return if (covenantStatus(covenant, catalog) < minimum) "Learning rituals requires ${catalog.name(CatalogKind.covenants, TraitSource(catalog = covenant))} Status $minimum" else null
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
fun CharacterSave.coilWarning(coil: Coil, catalog: Catalog): String? = if (!isMysteryCoil(coil) && coil.rating > covenantStatus("ordo-dracul", catalog))
    "Outside your Mystery, limited to Ordo Dracul Status (${covenantStatus("ordo-dracul", catalog)})" else null

data class ClanBaneInfo(val name: String, val summary: String, val threshold: Int, val extraBane: Boolean)
fun CharacterSave.clanBane(catalog: Catalog): ClanBaneInfo? = catalog.entry(CatalogKind.clans, clan)?.raw?.obj("bane")?.let {
    ClanBaneInfo(it.str("name").orEmpty(), it.str("summary").orEmpty(), it.int("humanityThreshold", 6), it.flag("grantsExtraBane"))
}
