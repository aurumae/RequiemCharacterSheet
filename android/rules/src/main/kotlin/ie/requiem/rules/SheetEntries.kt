package ie.requiem.rules

import java.text.Normalizer
import java.util.Locale
import java.util.UUID

data class SheetEntry(val id: UUID, val source: TraitSource, val name: String, val rating: Int? = null,
    val choices: List<Int> = emptyList(), val qualifier: String? = null, val summary: String = "", val citation: String = "",
    val notes: List<String> = emptyList(), val warnings: List<String> = emptyList(), val known: Boolean = false, val visibleDots: Int = 0)

fun CharacterSave.entryRows(kind: EntryKind, catalog: Catalog): List<SheetEntry> {
    fun row(id: UUID, source: TraitSource, rating: Int? = null, qualifier: String? = null, customChoices: List<Int> = emptyList()): SheetEntry {
        val entry = catalog.entry(kind.catalogKind, source)
        val base = if (kind == EntryKind.Coil) entry?.coilName ?: catalog.name(kind.catalogKind, source) else catalog.name(kind.catalogKind, source)
        val name = base + (qualifier?.let { " ($it)" } ?: "")
        val choices = if (kind == EntryKind.Merit && entry != null) listOf(0) + entry.ratings else customChoices
        return SheetEntry(id, source, name, rating, choices, qualifier, entry?.summary.orEmpty(), entry?.citation.orEmpty(), known = entry != null, visibleDots = choices.maxOrNull() ?: 0)
    }
    return when (kind) {
        EntryKind.Discipline -> disciplines.map { d ->
            val e = catalog.entry(CatalogKind.disciplines, d.source)
            row(d.id, d.source, d.rating, customChoices = (0..5).toList()).copy(warnings = listOfNotNull(e?.let { ritualLearningWarning(it, catalog) }))
        }
        EntryKind.Merit -> merits.map { m -> row(m.id, m.source, m.rating, m.qualifier, (0..5).toList()).copy(warnings = listOfNotNull(
            catalog.entry(CatalogKind.merits, m.source)?.let { prerequisites(it, catalog).warningText().ifEmpty { null } })) }
        EntryKind.Bane -> banes.map { row(it.id, it.source) }
        EntryKind.Ritual -> rituals.map { r -> row(r.id, r.source, r.dots(catalog), customChoices = if (catalog.entry(CatalogKind.rituals, r.source) == null) (1..5).toList() else emptyList())
            .copy(warnings = ritualWarnings(r, catalog)) }
        EntryKind.Devotion -> devotions.map { d ->
            val e = catalog.entry(CatalogKind.devotions, d.source)
            row(d.id, d.source).copy(notes = listOf(experiencesText(e?.experienceCost ?: d.customExperienceCost)),
                warnings = listOfNotNull(e?.let { prerequisites(it, catalog).warningText().ifEmpty { null } }))
        }
        EntryKind.Coil -> coils.map { coil ->
            val e = catalog.entry(CatalogKind.mysteries, coil.mystery)
            row(coil.id, coil.mystery, coil.rating, customChoices = (0..5).toList()).copy(notes = buildList {
                if (isMysteryCoil(coil)) add("Your Mystery")
                val learned = e?.raw?.objects("tiers").orEmpty().filter { it.int("dots") <= coil.rating }.mapNotNull { it.str("name") }
                if (learned.isNotEmpty()) add(learned.joinToString(" · "))
            }, warnings = listOfNotNull(coilWarning(coil, catalog)))
        }
        EntryKind.Scale -> scales.map { s -> row(s.id, s.source).copy(notes = listOf(experiencesText(catalog.entry(CatalogKind.scales, s.source)?.let(::scaleCost) ?: 2))) }
    }.map { row ->
        if (creation == null || row.choices.isEmpty()) row else {
            val maximum = when (kind) {
                EntryKind.Ritual -> maxOf(row.rating ?: 1, rituals.firstOrNull { it.id == row.id }?.let { ritual ->
                    disciplines.filter { it.source == ritual.discipline(catalog) }.maxOfOrNull { it.rating }
                } ?: 0)
                else -> creationMaximum("${kind.name.lowercase(Locale.ROOT)}:${row.id.swiftKey()}", row.visibleDots, catalog)
            }
            row.copy(choices = row.choices.filter { it <= maximum })
        }
    }
}
fun experiencesText(value: Int): String = "$value ${if (value == 1) "Experience" else "Experiences"}"

data class CatalogOption(val entry: BookEntry, val title: String, val group: String, val owned: Boolean, val details: List<String>, val warning: String?, val blockedReason: String? = null)
private val meritOrder = listOf("vampire", "covenant", "mental", "physical", "social", "fighting", "other", "supernatural")
private fun searchable(value: String): String = Normalizer.normalize(value.lowercase(Locale.ROOT), Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "").replace('’', '\'')
fun CharacterSave.catalogOptions(kind: EntryKind, catalog: Catalog, query: String = "", choosingMystery: Boolean = false): List<CatalogOption> {
    val owned = entryRows(kind, catalog).mapNotNull { it.source.catalog }.toSet()
    val ownDisciplines = inClanDisciplines(catalog)
    val ritualOrder = (ritualDisciplines(catalog).map { it.id } + catalog.bookEntries(CatalogKind.disciplines).filter { it.isRitualDiscipline }.map { it.id }).distinct()
    val mysteries = catalog.bookEntries(CatalogKind.mysteries).sortedBy { it.id != mystery.catalog }.map { it.id }
    val needle = searchable(query.trim())
    val entries = catalog.bookEntries(kind.catalogKind).filter { needle.isEmpty() || searchable(it.name + " " + it.summary + " " + it.coilName).contains(needle) }
    fun rank(e: BookEntry): Int = when (kind) {
        EntryKind.Discipline -> if (e.id in ownDisciplines) 0 else 1
        EntryKind.Merit -> if (needle.isNotEmpty()) 0 else meritOrder.indexOf(e.category).coerceAtLeast(0)
        EntryKind.Ritual -> ritualOrder.indexOf(e.discipline).coerceAtLeast(0)
        EntryKind.Devotion -> if (prerequisites(e, catalog).none { it.met == false }) 0 else 1
        EntryKind.Scale -> mysteries.indexOf(e.raw.str("mystery")).coerceAtLeast(0)
        else -> 0
    }
    return entries.sortedWith(compareBy<BookEntry> { rank(it) }.thenBy { if (needle.isEmpty() || searchable(it.name).contains(needle)) 0 else 1 }
        .thenBy { if (kind == EntryKind.Ritual) it.dots else 0 }.thenBy { it.name }).map { e ->
        val group = when (kind) {
            EntryKind.Discipline -> if (e.id in ownDisciplines) "In-clan for ${catalog.name(CatalogKind.clans, clan)}" else "Other Disciplines"
            EntryKind.Merit -> if (needle.isNotEmpty()) "Merits" else if (e.category == "supernatural") "Supernatural (not for Kindred)" else e.category.replaceFirstChar { it.uppercaseChar() }
            EntryKind.Ritual -> catalog.name(CatalogKind.disciplines, TraitSource(catalog = e.discipline))
            EntryKind.Devotion -> if (rank(e) == 0) "You have the Disciplines" else "Other Devotions"
            EntryKind.Scale -> catalog.name(CatalogKind.mysteries, TraitSource(catalog = e.raw.str("mystery").orEmpty()))
            else -> if (choosingMystery) "Mysteries" else kind.title + "s"
        }
        val details = when (kind) {
            EntryKind.Merit -> listOf(e.ratingsText())
            EntryKind.Ritual -> listOf("${dotsText(e.dots)} · Target successes: ${e.raw.int("targetSuccesses")}")
            EntryKind.Devotion -> listOf(experiencesText(e.experienceCost))
            EntryKind.Scale -> listOf("Prerequisite: ${e.scalePrerequisiteText(catalog)}", "Costs ${experiencesText(scaleCost(e))}")
            else -> emptyList()
        }
        val warning = when (kind) {
            EntryKind.Merit, EntryKind.Devotion -> prerequisites(e, catalog).warningText()
            EntryKind.Ritual -> ritualWarnings(Ritual(e.source()), catalog).joinToString(". ")
            EntryKind.Discipline -> ritualLearningWarning(e, catalog).orEmpty()
            else -> ""
        }.ifEmpty { null }
        CatalogOption(e, if (kind == EntryKind.Coil && !choosingMystery) e.coilName else e.name, group,
            !choosingMystery && e.id in owned && !(kind == EntryKind.Merit && e.repeatable), details, warning, if (choosingMystery) null else creationEntryRejection(SheetEdit.AddEntry(kind, e.source()), catalog))
    }
}
fun BookEntry.source(): TraitSource = TraitSource(catalog = id)
internal fun BookEntry.scalePrerequisiteText(catalog: Catalog): String = raw.objects("prerequisiteCoils").joinToString(" or ") { p ->
    val mystery = catalog.entry(CatalogKind.mysteries, p.str("mystery"))
    val tier = mystery?.raw?.objects("tiers")?.firstOrNull { it.int("dots") == p.int("dots") }?.str("name") ?: p.str("tier").orEmpty()
    "$tier (${mystery?.name ?: p.str("mystery")} ${dotsText(p.int("dots"))})"
}
