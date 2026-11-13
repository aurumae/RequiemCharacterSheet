package ie.requiem.rules

fun <T> Catalog.bookSections(rows: List<T>, entry: (T) -> BookEntry, group: (T) -> String = { "" }): List<CatalogSection<T>> =
    ie.chronicles.core.bookSections(books, rows, { entry(it).bookId }, group)

fun CharacterSave.catalogSections(kind: EntryKind, catalog: Catalog, query: String = "", choosingMystery: Boolean = false): List<CatalogSection<CatalogOption>> {
    val rows = catalogOptions(kind, catalog, query, choosingMystery)
    val inClan = if (kind == EntryKind.Discipline) rows.filter { it.entry.id in inClanDisciplines(catalog) } else emptyList()
    return (if (inClan.isEmpty()) emptyList() else listOf(CatalogSection("in-clan", null, "In-clan for ${inClanGroupName(catalog)}", inClan))) +
        catalog.bookSections(rows, { it.entry }, { if (kind in listOf(EntryKind.Discipline, EntryKind.Coil, EntryKind.Bane)) "" else it.group })
}
